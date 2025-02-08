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
  final RepositoryRelationType relationType;

  const GithubRepository({
    required this.name,
    required this.fullName,
    required this.isPrivate,
    required this.relationType,
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

  /// Returns list of all the secrets of given repository of current user.
  /// 
  /// Returns [null] if any problem occurs
  static Future<List<RepositorySecret>?> getRepoSecrets({
    required String repoName,
    int requiredPage = 1,
    int perPage = 10
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: 'User is not authenticated! Cannot get secrets!'
      );
      return null;
    }

    try {
      final uri = Uri.parse(
        "$_baseUrl/repos/${_user!.username}/$repoName/actions/secrets?per_page=$perPage&page=$requiredPage"
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user!.accessToken}',
          'Accept' : 'application/vnd.github+json',
        }
      );

      if (response.statusCode == 200) {
        List<dynamic> secrets = jsonDecode(response.body)['secrets'];
        List<RepositorySecret> repoSecrets = secrets.map((secretAsJson) {
          return RepositorySecret(
            name: secretAsJson['name'],
            createdAt: _toPrettyDate(secretAsJson['created_at']),
            updatedAt: _toPrettyDate(secretAsJson['updated_at']),
          );
        }).toList();

        return repoSecrets;
      } else if (response.statusCode == 404) {
        AppNotifier.notifyUserAboutError(errorMessage: "You don't seem to have permission to view secrets of required repository!");
      }
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

  /// Deletes the given secret of given repository
  /// 
  /// Returns status code of the request:
  /// 204: Successful
  static Future<int> deleteSecret({
    required String secretName,
    required GithubRepository secretRepo,
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(errorMessage: 'Please login first!');
      return 0;
    }

    late final http.Response response;

    try {
      Uri uri = Uri.parse('$_baseUrl/repos/${_user!.username}/${secretRepo.name}/actions/secrets/$secretName');
      response = await http.delete(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user!.accessToken}',
          'Accept' : 'application/vnd.github+json'
        }
      );

      if (response.statusCode == 204) {
        AppNotifier.notifyUserAboutSuccess(successMessage: 'Secret deleted successfully!');
      }

    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }

    return response.statusCode;
  }

  /// Returns all repositories of current user.
  /// 
  /// Returns [null] if any error occurs.
  static Future<List<GithubRepository>?> getUserRepos({
    int requiredPage = 1,
    int perPage = 30
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: "Cannot get repositories for current user! Please provide required information on github account section!"
      );
      return null;
    }

    try {
      final uri = Uri.parse('$_baseUrl/user/repos?per_page=$perPage&page=$requiredPage');
      final response = await http.get(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user?.accessToken}',
          'Accept' : 'application/vnd.github+json'
        }
      );

      if (response.statusCode == 200) {
        List<dynamic> repos = jsonDecode(response.body);

        List<GithubRepository> repositories = repos.map((repoAsJson) {
          RepositoryRelationType relationType;
          String ownerLogin = repoAsJson['owner']['login'];
          String ownerType = repoAsJson['owner']['type'];

          if (ownerLogin == _user!.username) {
            relationType = RepositoryRelationType.userOwned;
          } else if (ownerType == 'Organization') {
            relationType = RepositoryRelationType.organizationOwned;
          } else {
            relationType = RepositoryRelationType.collaboratorOnly;
          }

          return GithubRepository(
            name: repoAsJson['name'],
            fullName: repoAsJson['full_name'],
            isPrivate: repoAsJson['private'],
            relationType: relationType,
          );
        }).toList();

        repositories.sort((a, b) {
          return a.relationType.index.compareTo(b.relationType.index);
        });
    
        return repositories;
      } else if (response.statusCode == 401) {
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
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }
    
    return null;
  }
}