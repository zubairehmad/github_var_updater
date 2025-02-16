import 'dart:async';
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

/// Represents total type of configurations for a repository
enum ConfigType {
  secret, /// Configuration is secret, i.e it is repository secret
  variable /// Configuration is not secret (visible), i.e it is repository variable
}

/// It represents a configuration for repo (can be a secret or variable)
class RepositoryConfig {
  final String name;
  final String createdAt;
  final String updatedAt;
  final ConfigType configType;

  const RepositoryConfig({
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.configType
  });
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

  static int _currentConfigPage = 1;
  static List<RepositoryConfig> _alreadyCachedConfigs = [];

  /// Returns list of [desiredAmount] of configurations of required [configType] for given
  /// [repoName]. Starts fetching from first page if [startFromFirstPage] is set to true. For
  /// last page, the amount of configs can be lower than [desiredAmount] of configurations.
  /// 
  /// It handles pagination internally.
  /// 
  /// Returns null if any problem occurs, and empty list when all the configurations are returned
  /// 
  /// It must be noted that during calling this method, it must be noted that it doesn't separately
  /// store pages when called for different configs. So it must be ensured by caller that whenever config
  /// type potentially changes, this method should be called with startFromFirstPage=true once.
  static Future<List<RepositoryConfig>?> getRepoConfigs({
    required String repoName,
    required ConfigType configType,
    int desiredAmount = 10,
    bool startFromFirstPage = false,
  }) async {
    const perPage = 30;
    List<RepositoryConfig> configs = [];

    if (startFromFirstPage) {
      _currentConfigPage = 1;
      _alreadyCachedConfigs = [];
    }

    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: 'User is not authenticated! Cannot get secrets!'
      );
      return null;
    }

    if (_alreadyCachedConfigs.isNotEmpty) {
      int itemsToAdd = _alreadyCachedConfigs.length < desiredAmount
        ? _alreadyCachedConfigs.length
        : desiredAmount;

      configs.addAll(_alreadyCachedConfigs.sublist(0, itemsToAdd));
      _alreadyCachedConfigs = _alreadyCachedConfigs.sublist(itemsToAdd);
    }

    try {
      while (configs.length < desiredAmount) {

        String apiEndpoint = "$_baseUrl/repos/${_user!.username}/$repoName/actions/";
        apiEndpoint += configType == ConfigType.secret ? 'secrets' : 'variables';
        apiEndpoint += "?per_page=$perPage&page=$_currentConfigPage";

        final uri = Uri.parse(
          // "$_baseUrl/repos/${_user!.username}/$repoName/actions/secrets?per_page=$perPage&page=$_currentConfigPage"
          apiEndpoint
        );
        final response = await http.get(
          uri,
          headers: {
            'Authorization' : 'Bearer ${_user!.accessToken}',
            'Accept' : 'application/vnd.github+json',
          }
        );

        if (response.statusCode == 200) {
          _currentConfigPage++;

          List<dynamic> configsAsJson = (configType == ConfigType.secret)
            ? jsonDecode(response.body)['secrets']
            : jsonDecode(response.body)['variables'];

          for (int i = 0; i < configsAsJson.length; i++) {
            Map<String, dynamic> configAsJson = configsAsJson[i];
            RepositoryConfig repositoryConfig = RepositoryConfig(
              name: configAsJson['name'],
              createdAt: _toPrettyDate(configAsJson['created_at']),
              updatedAt: _toPrettyDate(configAsJson['updated_at']),
              configType: configType,
            );

            if (configs.length < desiredAmount) {
              configs.add(repositoryConfig);
            } else {
              _alreadyCachedConfigs.add(repositoryConfig);
            }
          }

          if (configsAsJson.length < perPage) break;
        } else {
          if (response.statusCode == 404) {
            AppNotifier.notifyUserAboutError(
              errorMessage: "You don't seem to have permission to view configurations (variables/secrets) of required repository!"
            );
          } else {
            AppNotifier.showErrorDialog(
              errorMessage: 'Error occured while fetching secrets: ${response.statusCode} - ${response.reasonPhrase}'
            );
          }
          return null;
        }
      }
      return configs;
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection!');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');  
    }

    return null;
  }

  /// A helper method that encrypts given [secretValue] of given repository [repoName]
  /// 
  /// Returns a map with fields encryptedSecret representing secret and id
  /// of public key used. Returns null if any error occurs
  static Future<Map<String, String>?> _encryptSecretValue({
    required String secretValue,
    required String repoName
  }) async {
    String? publicKey;
    String? publicKeyId;

    // Get public key for repository
    try {
      Uri uri = Uri.parse('$_baseUrl/repos/${_user!.username}/$repoName/actions/secrets/public-key');
      final res = await http.get(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user!.accessToken}',
          'Accept' : 'application/vnd.github+json'
        }
      );

      if (res.statusCode == 200) {
        final responseAsJson = jsonDecode(res.body);
        publicKey = responseAsJson['key'];
        publicKeyId = responseAsJson['key_id'];
      }
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection');
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
    }

    if (publicKeyId == null || publicKey == null) {
      return null;
    }

    // Encrypt using public key
    final sodium = await SodiumInit.init();

    final publicKeyBytes = base64Decode(publicKey);
    final secretBytes = utf8.encode(secretValue);

    final encryptedBytes = sodium.crypto.box.seal(message: secretBytes, publicKey: publicKeyBytes);

    // return encrypted value along with public key
    return {
      'encryptedSecret' : base64Encode(encryptedBytes),
      'publicKeyId' : publicKeyId
    };
  }

  /// Updates value of a repository configuration (secret or variable)
  static Future<void> updateRepositoryConfig({
    required String confName,
    required GithubRepository repo,
    required String newValue,
    required ConfigType confType,
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(errorMessage: 'Please login first!');
      return;
    }

    late String jsonBody;
    String apiEndpoint = "$_baseUrl/repos/${_user!.username}/${repo.name}/actions/";

    switch (confType) {
      case ConfigType.secret:
        final encryptedVal = await _encryptSecretValue(secretValue: newValue, repoName: repo.name);

        if (encryptedVal == null) {
          return;
        }
        
        jsonBody = jsonEncode({
          'encrypted_value' : encryptedVal['encryptedSecret'],
          'key_id' : encryptedVal['publicKeyId'],
        });

        apiEndpoint += "secrets/$confName";
        break;
      case ConfigType.variable:
        jsonBody = jsonEncode({
          'value' : newValue
        });

        apiEndpoint += "variables/$confName";
        break;
    }

    try {
      Uri url = Uri.parse(apiEndpoint);
      Map<String, String> headers = {
        'Authorization' : 'Bearer ${_user!.accessToken}',
        'Accept' : 'application/vnd.github+json',
      };

      final response = (confType == ConfigType.secret)
        ? await http.put(url, headers: headers, body: jsonBody)
        : await http.patch(url, headers: headers, body: jsonBody);

      if (response.statusCode == 201) {
        AppNotifier.notifyUserAboutSuccess(successMessage: "'$confName' created successfully!");
      } else if (response.statusCode == 204) {
        AppNotifier.notifyUserAboutSuccess(successMessage: "'$confName' updated successfully!");
      } else if (response.statusCode == 404) {
        AppNotifier.showErrorDialog(errorMessage: "'$confName' does not exist in'${repo.fullName}'");
      } else {
        AppNotifier.notifyUserAboutError(errorMessage: "You don't have enough permissions!");
      }
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet connection!');
    } on TimeoutException {
      AppNotifier.notifyUserAboutInfo(info: 'Request timed out, your internet connect is slow');
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