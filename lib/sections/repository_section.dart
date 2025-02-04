import 'package:flutter/material.dart';
import 'package:github_var_updater/api_service/github_api.dart';
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
    // Will stop displaying circual progress indicator
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
                  onTap: () {},
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