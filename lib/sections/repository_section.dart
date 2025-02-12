import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:github_var_updater/api_service/github_api.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:github_var_updater/utils/google_utils.dart';
import 'package:github_var_updater/widgets/styled_text_button.dart';

class RepositorySection extends StatefulWidget {
  const RepositorySection({super.key});

  @override
  State<RepositorySection> createState() => _RepositorySectionState();
}

class _RepositorySectionState extends State<RepositorySection> {

  List<GithubRepository>? repositories;

  // Some flags to update UI
  bool repoBeingFetched = false;
  bool moreReposAreLoading = false;
  bool moreReposAvailable = true;

  /// For loading repositories for first time
  Future<void> _loadRepositories() async {
    if (repoBeingFetched == true || !moreReposAvailable) return;

    // Will start displaying circular progress indicator
    setState(() => repoBeingFetched = true);
    repositories = await GithubApi.getUserRepos(startFromFirstPage: true);
    // Will stop displaying circular progress indicator
    setState(() => repoBeingFetched = false);
  }

  /// For loading repositories after first time i.e by load more button
  Future<void> _loadMoreRepositories() async {
    if (moreReposAreLoading == true || !moreReposAvailable) return;

    setState(() => moreReposAreLoading = true);
    List<GithubRepository>? fetchedRepositories = await GithubApi.getUserRepos();
    if (fetchedRepositories != null) {
      if (fetchedRepositories.isEmpty) {
        moreReposAvailable = false;
      } else {
        repositories!.addAll(fetchedRepositories);
      }
    }
    setState(() => moreReposAreLoading = false);
  }

  Future<void> showRepositorySecrets(int repoIndex) async {
    if (repositories == null || repoIndex < 0 || repoIndex >= repositories!.length) {
      return; // Return if index is invalid, or repositories are null
    }

    GithubRepository repo = repositories![repoIndex];
    List<RepositorySecret> secrets = [];
    bool isFetching = false;
    bool moreSecretsAvailable = true;

    Future<void> fetchSecrets({required void Function(void Function()) setState}) async {
      if (isFetching || !moreSecretsAvailable) return;

      setState(() => isFetching = true);

      List<RepositorySecret>? newSecrets = await GithubApi.getRepoSecrets(
        repoName: repo.name,
        startFromFirstPage: secrets.isEmpty,
      );

      if (mounted) {
        if (newSecrets != null) {
          if (newSecrets.isEmpty) {
            setState(() => moreSecretsAvailable = false);
          } else {
            setState(() {
              secrets.addAll(newSecrets);
            });
          }
        }

        setState(() => isFetching = false);
      }
    }

    Future<void> deleteSecret({required void Function() onDelete, required String secretName}) async {
      final response = await GithubApi.deleteSecret(secretName: secretName, secretRepo: repo);
      if (response == 204) {
        onDelete();
      }
    }

    Future<void> udpateSecretValue({required String secretName}) async {

      OAuth2Token? token = await GoogleUtils.getOuth2Token();

      if (token != null) {
        Map<String, String> jsonMap = {
          'token': token.accessToken,
          'refresh_token': token.refreshToken,
          'token_uri': 'https://oauth2.googleapis.com/token',
          'client_id': GoogleUtils.clientId,
          'client_secret': GoogleUtils.clientSecret,
          'scopes': token.scope
        };

        String newValue = jsonEncode(jsonMap);

        await GithubApi.updateSecret(
          secretName: secretName,
          secretRepo: repo,
          newValue: newValue
        );

        AppNotifier.notifyUserAboutSuccess(successMessage: 'Secret updated successfully!');
      } else {
        AppNotifier.notifyUserAboutError(errorMessage: 'Failed to update secret!');
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (secrets.isEmpty && moreSecretsAvailable) {
              fetchSecrets(setState: setState);
            }

            return Padding(
              padding: const EdgeInsets.all(15.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Secrets for ${repo.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: secrets.isEmpty
                          ? (isFetching
                              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                              : const Center(child: Text('No Secrets Found!')))
                          : ListView.separated(
                              itemCount: secrets.length + 1,
                              itemBuilder: (context, index) {
                                if (index == secrets.length) {
                                  late Widget widget;

                                  if (moreSecretsAvailable) {
                                    if (isFetching) {
                                      widget = const Center(
                                        child: SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF3B71CA),
                                            strokeWidth: 3,
                                          ),
                                        )
                                      );
                                    } else {
                                      widget = Center(
                                        child: TextButton(
                                          onPressed: () {
                                            fetchSecrets(setState: setState);
                                          },
                                          child: const Text(
                                            "Load More",
                                            style: TextStyle(
                                              color: Color(0xFF3B71CA),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    widget = const Center(child: Text("No More Secrets"));
                                  }

                                  return widget;
                                }

                                RepositorySecret secret = secrets[index];

                                return ListTile(
                                  leading: const Icon(Icons.lock, color: Colors.red),
                                  title: Text(
                                    secret.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => udpateSecretValue(secretName: secret.name),
                                        icon: const Icon(Icons.update),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          deleteSecret(onDelete: () {
                                            setState(() => secrets.removeAt(index));
                                          }, secretName: secret.name);
                                        },
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                      )
                                    ],
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const Divider(thickness: 1),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRepositories();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (repoBeingFetched == true) {
      // Show circular progress indicator while
      // repositories are being fetched
      body = const Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  "Loading Repositories...",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 35),
          CircularProgressIndicator(
            color: Colors.blue,
          ),
        ]
      ); 
    } else if (GithubApi.currentUser == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text("Please first provide github api token and username!"),
            ),
          ),
        ),
      );
    } else if (repositories == null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'No repositories could be fetched!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            StyledTextButton(
              onPressed: _loadRepositories,
              text: Text(
                'Try Again'
              ),
            ),
          ],
        )
      );
    } else {
      body = SingleChildScrollView(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Text(
                  'Your Repositories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (repositories!.isEmpty) ... [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      "It seems that there aren't any repositories!",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              for (int i = 0; i < repositories!.length; i++) ...[
                InkWell(
                  onTap: () => showRepositorySecrets(i),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: const Icon(Icons.folder_special, color: Colors.blueAccent),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      repositories![i].fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('${repositories![i].isPrivate? "Private" : "Public"} Repository'),
                  ),
                ),
                const Divider(thickness: 1),
                if (i == repositories!.length-1) ...[
                  const SizedBox(height: 15),
                  if (moreReposAreLoading) ...[
                    const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B71CA),
                          strokeWidth: 3,
                        )
                      )
                  ] else if (moreReposAvailable) ...[
                    TextButton(
                        onPressed: _loadMoreRepositories,
                        child: const Text(
                          'Load More',
                          style: TextStyle(
                            color: Color(0xFF3B71CA)
                          ),
                        ),
                      )
                  ] else ...[
                    Text('No more repositories!')
                  ]
                ]
              ],
            ]
          ],
        ),
      );
    }
    return body;
  }
}