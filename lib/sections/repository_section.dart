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

  Future<ConfigType?> _showConfigSelectionDialog() async {
    const MaterialColor themeColor = Colors.blue;
    ConfigType? selectedType;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: themeColor.shade50,
          actionsAlignment: MainAxisAlignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: themeColor,
              width: 2.0,
            ),
          ),
          title: const Column(
            children: [
              Text(
                'Select Option',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: themeColor,
                ),
              ),
              SizedBox(height: 8),
              Divider(
                color: themeColor,
                thickness: 1.5,
              )
            ],
          ),
          content: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Select what do you want to see.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                selectedType = ConfigType.secret;
              },
              style: TextButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Secrets')
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                selectedType = ConfigType.variable;
              },
              style: TextButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Variables')
              ),
            )
          ],
        );
      }
    );
    return selectedType;
  }

  Future<void> showRepositoryConfigs(int repoIndex) async {
    if (repositories == null || repoIndex < 0 || repoIndex >= repositories!.length) {
      return; // Return if index is invalid, or repositories are null
    }

    final confType = await _showConfigSelectionDialog();

    if (confType == null) return;

    GithubRepository repo = repositories![repoIndex];
    List<RepositoryConfig> configs = [];
    bool isFetching = false;
    bool moreConfigsAvailable = true;

    Future<void> fetchConfigs({required void Function(void Function()) setState}) async {
      if (isFetching || !moreConfigsAvailable) return;

      setState(() => isFetching = true);

      List<RepositoryConfig>? newConfigs = await GithubApi.getRepoConfigs(
        configType: confType,
        repoName: repo.name,
        startFromFirstPage: configs.isEmpty,
      );

      if (!mounted) return;

      if (newConfigs != null) {
        if (newConfigs.isEmpty) {
          setState(() => moreConfigsAvailable = false);
        } else {
          setState(() {
            configs.addAll(newConfigs);
          });
        }
      }
      
      setState(() => isFetching = false);
    }

    Future<void> udpateConfigValue({required String confName}) async {
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

        String newValue = base64.encode(utf8.encode(jsonEncode(jsonMap)));

        await GithubApi.updateRepositoryConfig(
          confName: confName,
          repo: repo,
          newValue: newValue,
          confType: confType
        );
      } else {
        AppNotifier.notifyUserAboutError(errorMessage: "Failed to update '$confName'");
      }
    }

    if (!mounted) return;

    String confTypeName = (confType == ConfigType.secret)
      ? 'Secrets'
      : 'Variables';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (configs.isEmpty && moreConfigsAvailable) {
              fetchConfigs(setState: setState);
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
                          '$confTypeName for ${repo.name}',
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
                      child: configs.isEmpty
                          ? (isFetching
                              ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                              : Center(child: Text('No $confTypeName Found!')))
                          : ListView.separated(
                              itemCount: configs.length + 1,
                              itemBuilder: (context, index) {
                                if (index == configs.length) {
                                  late Widget widget;

                                  if (moreConfigsAvailable) {
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
                                            fetchConfigs(setState: setState);
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
                                    widget = Center(child: Text("No More $confTypeName"));
                                  }

                                  return widget;
                                }

                                RepositoryConfig config = configs[index];

                                return ListTile(
                                  leading: const Icon(Icons.lock, color: Colors.red),
                                  title: Text(
                                    config.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => udpateConfigValue(confName: config.name),
                                    icon: const Icon(Icons.update),
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
                  onTap: () => showRepositoryConfigs(i),
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