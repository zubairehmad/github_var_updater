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
  bool repoBeingFetched = false;
  int currentPage=1;
  static const repoPerPage = 10;

  Future<void> _getRepositories() async {
    // Will start displaying circular progress indicator
    setState(() => repoBeingFetched = true);
    repositories = await GithubApi.getUserRepos(
      requiredPage: currentPage,
      perPage: repoPerPage,
    );
    // Will stop displaying circular progress indicator
    setState(() => repoBeingFetched = false);
  }

  void nextPage() {
    setState(() {
      currentPage++;
      // So that progress indicator can be shown
      repositories = null;
    });
    // Set state will be called in this repo
    _getRepositories();
  }

  void previousPage() {
    setState(() {
      currentPage--;
      // So that progress indicator can be shown
      repositories = null;
    });
    _getRepositories();
  }

  Future<void> showRepositorySecrets(int repoIndex) async {
    if (repositories == null || repoIndex < 0 || repoIndex >= repositories!.length) {
      return; // Return if index is invalid, or repositories are null
    }

    GithubRepository repo = repositories![repoIndex];
    List<RepositorySecret> secrets = [];
    bool isFetching = false;
    bool hasMoreSecrets = true;
    int reqPage = 1;
    const int perPage = 10;

    Future<void> fetchSecrets({required void Function(void Function()) setState}) async {
      if (isFetching || !hasMoreSecrets) return;

      setState(() => isFetching = true);

      List<RepositorySecret>? newSecrets = await GithubApi.getRepoSecrets(
        repoName: repo.name,
        requiredPage: reqPage,
        perPage: perPage,
      );

      if (newSecrets == null || newSecrets.isEmpty) {
        setState(() => hasMoreSecrets = false);
      } else {
        setState(() {
          secrets.addAll(newSecrets);
          reqPage++;
        });
      }

      setState(() => isFetching = false);
    }

    Future<void> deleteSecret({required void Function() onDelete, required String secretName}) async {
      final response = await GithubApi.deleteSecret(secretName: secretName, secretRepo: repo);
      if (response == 204) {
        onDelete();
      }
    }

    Future<void> udpateSecretValue({required String secretName}) async {
      String? accessToken = await GoogleUtils.getAccessTokenForGoogleAccount();
      if (accessToken != null) {
        await GithubApi.updateSecret(
          secretName: secretName,
          secretRepo: repo,
          newValue: accessToken
        );
      } else {
        AppNotifier.notifyUserAboutError(errorMessage: 'Unable to get access token for updating secret!');
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (secrets.isEmpty && hasMoreSecrets) {
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
                                  return hasMoreSecrets
                                      ? Center(
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
                                        )
                                      : const Center(child: Text("No More Secrets"));
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
                                        onPressed: () {
                                          udpateSecretValue(secretName: secret.name);
                                        },
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
    _getRepositories();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (repoBeingFetched == true) {
      // Show circular progress indicator while
      // repositories are being fetched
      body = const Center(
        child: CircularProgressIndicator(
          color: Colors.blue,
        ),
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
                    'No repositories could be found!',
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
              onPressed: () {
                setState(() {
                  repositories = null;
                });
                _getRepositories();
              },
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
                  'All Repositories',
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
                      "That's it! You've seen all!",
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
                if (i != repositories!.length-1) ...[
                  const Divider(thickness: 1)
                ]
              ],
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentPage != 1) ...[
                  IconButton(
                    onPressed: previousPage,
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Page $currentPage",
                    style: const TextStyle( 
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (repositories!.length == repoPerPage) ...[
                  IconButton(
                    onPressed: nextPage,
                    icon: Icon(Icons.chevron_right, size: 28),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }
    return body;
  }
}