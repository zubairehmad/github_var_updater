import 'dart:convert';
import 'dart:io';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:http/http.dart' as http;
import 'package:github_var_updater/utils/keystore.dart';

/// Encapsulates required fields about github user
class GithubUser {
  final String username;
  final String accessToken;

  const GithubUser({required this.username, required this.accessToken});
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

  /// Returns user repositories
  static Future<List<GithubRepository>> getUserRepos({
    int requiredPage = 1,
    int perPage = 30
  }) async {
    if (_user == null) {
      AppNotifier.showErrorDialog(
        errorMessage: "Cannot get repositories for current user! Please provide required information on github account section!"
      );
      return [];  // Return empty list
    }

    late final http.Response response;

    try {
      final uri = Uri.parse('$_baseUrl/user/repos?per_page=$perPage&page=$requiredPage');
      response = await http.get(
        uri,
        headers: {
          'Authorization' : 'Bearer ${_user?.accessToken}',
          'Accept' : 'application/vnd.github+json'
        }
      );
    } on SocketException {
      AppNotifier.notifyUserAboutInfo(info: 'Please check your internet!');
      return [];
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured: ${e.toString()}');
      return [];
    }

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

    return [];
  }
}