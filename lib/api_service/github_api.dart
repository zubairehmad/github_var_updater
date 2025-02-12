import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:http/http.dart' as http;
import 'package:github_var_updater/utils/keystore.dart';

/// Encapsulates related fields about github user
class GithubUser {
  final String username;
  final String accessToken;

  const GithubUser({required this.username, required this.accessToken});
}

class RepositorySecret {
  final String name;
  final String createdAt;
  final String updatedAt;

  const RepositorySecret({required this.name, required this.createdAt, required this.updatedAt});
}

enum RepositoryRelationType {
  userOwned,        /// Owned by the user (Highest Priority)
  collaboratorOnly, /// User is a collaborator (but not in an org)
  organizationOwned /// Organization-Owned Repositories (Lowest Priority)
}

/// Encapsulates required fields about github repository
class GithubRepository {
  final String name;
  final String fullName;
  final bool isPrivate;

  const GithubRepository({
    required this.name,
    required this.fullName,
    required this.isPrivate,
  });
}

/// This class is used to get user data from github using api requests
class GithubApi {
  static final String _baseUrl = 'https://api.github.com';
  static GithubUser? _user;

  static GithubUser? get currentUser => _user;

  /// Sets given [user] the current user and any 
  static void setCurrentUser(GithubUser user) {
    _user = user;
    Keystore.savePair(key: 'github_username', value: user.username);
    Keystore.savePair(key: 'github_access_token', value: user.accessToken);
  }

  static Future<void> loadPreviousUser() async {
    if (await Keystore.contains(key: 'github_username') && await Keystore.contains(key: 'github_access_token')) {
      _user = GithubUser(
        username: await Keystore.getValueForKey(key: 'github_username') as String,
        accessToken: await Keystore.getValueForKey(key: 'github_access_token') as String
      );
    }
  }

  /// Helper method. Returns date in a pretty format
  static String _toPrettyDate(String dateStr) {
    try {
      DateTime parsedTime = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsedTime);
    } catch (e) {
      return "Invalid Date";
    }
  }

  static int _currentSecretPage = 1;
  static List<RepositorySecret> _alreadyCachedSecrets = [];

  /// Returns list of [desiredAmount] (atmost) of secrets for given [repoName].
  /// Starts fetching from first page if [startFromFirstPage] is set to true.
  /// 
  /// It handles pagination internally.
  /// 
  /// Returns null if any problem occurs, and empty list when all the secrets
  /// are returned
  static Future<List<RepositorySecret>?> getRepoSecrets({
    required String repoName,
    int desiredAmount = 10,
    bool startFromFirstPage = false,
  }) async {
    const perPage = 30;
    List<RepositorySecret> secrets = [];

    if (startFromFirstPage) {
      _currentSecretPage = 1;
      _alreadyCachedSecrets = [];
    }

    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: 'User is not authenticated! Cannot get secrets!'
      );
      return null;
    }

    if (_alreadyCachedSecrets.isNotEmpty) {
      int itemsToAdd = _alreadyCachedSecrets.length < desiredAmount
        ? _alreadyCachedSecrets.length
        : desiredAmount;

      secrets.addAll(_alreadyCachedSecrets.sublist(0, itemsToAdd));
      _alreadyCachedSecrets = _alreadyCachedSecrets.sublist(itemsToAdd);
    }

    try {
      while (secrets.length < desiredAmount) {
        final uri = Uri.parse(
          "$_baseUrl/repos/${_user!.username}/$repoName/actions/secrets?per_page=$perPage&page=$_currentSecretPage"
        );
        final response = await http.get(
          uri,
          headers: {
            'Authorization' : 'Bearer ${_user!.accessToken}',
            'Accept' : 'application/vnd.github+json',
          }
        );

        if (response.statusCode == 200) {
          _currentSecretPage++;

          List<dynamic> secretsAsJson = jsonDecode(response.body)['secrets'];

          for (int i = 0; i < secretsAsJson.length; i++) {
            Map<String, dynamic> secretAsJson = secretsAsJson[i];
            RepositorySecret repositorySecret = RepositorySecret(
              name: secretAsJson['name'],
              createdAt: _toPrettyDate(secretAsJson['created_at']),
              updatedAt: _toPrettyDate(secretAsJson['updated_at']),
            );

            if (secrets.length < desiredAmount) {
              secrets.add(repositorySecret);
            } else {
              _alreadyCachedSecrets.add(repositorySecret);
            }
          }

          if (secretsAsJson.length < perPage) break;
        } else {
          if (response.statusCode == 404) {
            AppNotifier.notifyUserAboutError(errorMessage: "You don't seem to have permission to view secrets of required repository!");
          } else {
            AppNotifier.showErrorDialog(
              errorMessage: 'Error occured while fetching secrets: ${response.statusCode} - ${response.reasonPhrase}'
            );
          }
          return null;
        }
      }
      return secrets;
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');  
    }

    return null;
  }

  /// Helper method, encrypts given secret value based on given public key.
  static Future<String> _encryptSecret({required String secretValue, required String publicKey}) async {
    final sodium = await SodiumInit.init();

    final publicKeyBytes = base64Decode(publicKey);
    final secretBytes = utf8.encode(secretValue);

    final encryptedBytes = sodium.crypto.box.seal(message: secretBytes, publicKey: publicKeyBytes);

    return base64Encode(encryptedBytes);
  }

  /// Updates a secret's value
  static Future<void> updateSecret({
    required String secretName,
    required GithubRepository secretRepo,
    required String newValue,
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(errorMessage: 'Please login first!');
      return;
    }

    String? repoPublicKey;
    String? repoPublicKeyId;

    // Get public key for repository
    try {
      Uri uri = Uri.parse('$_baseUrl/repos/${_user!.username}/${secretRepo.name}/actions/secrets/public-key');
      final res = await http.get(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user!.accessToken}',
          'Accept' : 'application/vnd.github+json'
        }
      );

      if (res.statusCode == 200) {
        final responseAsJson = jsonDecode(res.body);
        repoPublicKey = responseAsJson['key'];
        repoPublicKeyId = responseAsJson['key_id'];
      }
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }

    if (repoPublicKey == null || repoPublicKeyId == null) {
      return;
    }

    String encryptedSecretValue = await _encryptSecret(secretValue: newValue, publicKey: repoPublicKey);

    try {
      Uri url = Uri.parse('$_baseUrl/repos/${_user!.username}/${secretRepo.name}/actions/secrets/$secretName');
      final response = await http.put(
        url,
        headers: {
          'Authorization' : 'Bearer ${_user!.accessToken}',
          'Accept' : 'application/vnd.github+json'
        },
        body: jsonEncode({
          'encrypted_value' : encryptedSecretValue,
          'key_id' : repoPublicKeyId
        }),
      );

      if (response.statusCode == 201) {
        AppNotifier.notifyUserAboutSuccess(successMessage: 'Secret created successfully!');
      } else if (response.statusCode == 204) {
        AppNotifier.notifyUserAboutSuccess(successMessage: 'Secret updated successfully!');
      } else if (response.statusCode == 404) {
        AppNotifier.showErrorDialog(errorMessage: "There is no secret named '$secretName' in '${secretRepo.fullName}'");
      } else {
        AppNotifier.notifyUserAboutError(errorMessage: "You don't have enough permissions!");
      }
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }
  }

  static int _currentRepoPage = 1;
  static List<GithubRepository> _alreadyCachedRepositories = [];

  /// Returns only repositories for which the user is admin. The returned repositories
  /// are based upon [desiredAmountOfRepo]. It can return less than that if all repositories
  /// are returned, or if last page is encountered. [startFromFirstPage] can be set to true
  /// to start fetching from first page.
  /// 
  /// It handles pagination internally.
  /// 
  /// Returns null if any error occurs during fetching repositories, and empty list
  /// when all repositories are returned.
  static Future<List<GithubRepository>?> getUserRepos({int desiredAmountOfRepo = 20, bool startFromFirstPage = false}) async {
    const reposPerPage = 50;
    List<GithubRepository> filteredRepos = [];

    if (startFromFirstPage) {
      _currentRepoPage = 1;
      _alreadyCachedRepositories = [];
    }
    
    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: "Cannot get repositories for current user! Please provide required information on github account section!"
      );
      return null;
    }

    if (_alreadyCachedRepositories.isNotEmpty) {
      int itemsToAdd = _alreadyCachedRepositories.length < desiredAmountOfRepo
        ? _alreadyCachedRepositories.length
        : desiredAmountOfRepo;

      filteredRepos.addAll(_alreadyCachedRepositories.sublist(0, itemsToAdd));
      _alreadyCachedRepositories = _alreadyCachedRepositories.sublist(itemsToAdd);

      if (filteredRepos.length == desiredAmountOfRepo) return filteredRepos;
    }

    try {
      late http.Response response;

       while(filteredRepos.length != desiredAmountOfRepo) {

        final uri = Uri.parse('$_baseUrl/user/repos?per_page=$reposPerPage&page=$_currentRepoPage');
        response = await http.get(
          uri,
          headers: {
            'Authorization' : 'Bearer ${_user?.accessToken}',
            'Accept' : 'application/vnd.github+json'
          }
        );

        if (response.statusCode == 200) {
          _currentRepoPage++;

          List<dynamic> unfilteredRepos = jsonDecode(response.body);

          for (int i = 0; i < unfilteredRepos.length; i++) {
            Map<String, dynamic> repoAsJson = unfilteredRepos[i];

            if (repoAsJson['permissions']['admin'] == true) {

              GithubRepository repository = GithubRepository(
                name: repoAsJson['name'],
                fullName: repoAsJson['full_name'],
                isPrivate: repoAsJson['private']
              );

              if (filteredRepos.length < desiredAmountOfRepo) {
                filteredRepos.add(repository);
              } else {
                // Desired amount is reached, but some repos are left in current page
                // that are eligibile but couldn't be fetched. To add them in subsequenet
                // calls, they are cached.
                _alreadyCachedRepositories.add(repository);
              }
            }
          }

          if (unfilteredRepos.length < reposPerPage) break;

        } else{
          // Handle other response codes
          if (response.statusCode == 401) {
            AppNotifier.notifyUserAboutError(errorMessage: 'Please provide valid credentials! Current ones are invalid!');
          } else if (response.statusCode == 403) {
            AppNotifier.notifyUserAboutError(
              errorMessage: "Either github api rate limit exceeded or your token doesn't have required permissions"
            );
          } else {
            AppNotifier.showErrorDialog(
              errorMessage: 'Unknown error occured while trying to get repositories.\nResponse Status Code: ${response.statusCode}'
            );
          }
          return null;
        } 
      }
      
      return filteredRepos;
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }

    return null;
  }
}