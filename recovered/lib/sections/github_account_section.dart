import 'package:flutter/material.dart';
import 'package:github_var_updater/api_service/github_api.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:github_var_updater/widgets/input_widget.dart';
import 'package:github_var_updater/widgets/styled_text_button.dart';

class GithubAccountSection extends StatefulWidget {
  const GithubAccountSection({super.key});

  @override
  State<GithubAccountSection> createState() => _GithubAccountSectionState();
}

class _GithubAccountSectionState extends State<GithubAccountSection> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController tokenController = TextEditingController();

  bool areCredentialsRequired = true;

  void _setCurrentUser() {
    if (usernameController.text.isEmpty || tokenController.text.isEmpty) {
      AppNotifier.notifyUserAboutError(errorMessage: 'Both fields are required! Please provide your username and github api token.');
      return;
    }

    GithubApi.setCurrentUser(
      GithubUser(
        username: usernameController.text,
        accessToken: tokenController.text,
      )
    );

    // This will cause a rebuild
    _toggleCredentialsRequired();
  }

  void _toggleCredentialsRequired() {
    setState(() => areCredentialsRequired = !areCredentialsRequired);
  }

  @override
  void initState() {
    super.initState();
    areCredentialsRequired = GithubApi.currentUser == null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (areCredentialsRequired) ...[
              InputWidget(
                controller: usernameController,
                prefixText: 'Username',
                labelText: 'Github Username',
                hintText: 'Enter your github username',
              ),
              const SizedBox(height: 40),
              InputWidget(
                controller: tokenController,
                prefixText: 'Api Token',
                labelText: 'Github Api Token',
                hintText: 'Paste your github api token here',
              ),
              const SizedBox(height: 40),
              StyledTextButton(
                onPressed: _setCurrentUser,
                text: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Current User Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 25
                        ),
                      ),
                      const Divider(
                        thickness: 1,
                      ),
                      const SizedBox(height: 30),
                      InputWidget(
                        initialValue: GithubApi.currentUser?.username ?? 'Unexpectedly Null',
                        prefixText: 'Username',
                        readOnly: true,
                      ),
                      const SizedBox(height: 30),
                      InputWidget(
                        initialValue: GithubApi.currentUser?.accessToken ?? 'Unexpectedly Null',
                        prefixText: 'Api Token',
                        readOnly: true,
                      ),
                      const SizedBox(height: 30),
                      StyledTextButton(
                        onPressed: _toggleCredentialsRequired,
                        text: const Text(
                          'Change User',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              

              /*Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Your Github Token',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy),
                            tooltip: 'Copy Token',
                            onPressed: () =>
                              Clipboard.setData(ClipboardData(text: GithubApi.currentUser?.accessToken ?? '')),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        "${GithubApi.currentUser?.accessToken}",
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),*/
            ]
          ],
        ),
      ),
    );

    /*return Padding(
      padding: EdgeInsets.all(8.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (token == null) ...[
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  icon: Icon(Icons.person),
                  labelText: 'Github Access Token',
                  hintText: 'Paste github access token here',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveApiToken,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Text('Continue'),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row (
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Your Github Token',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy),
                            tooltip: 'Copy Token',
                            onPressed: () =>
                              Clipboard.setData(ClipboardData(text: token ?? '')),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        '$token',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => token = null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  iconSize: 35,
                ),
                icon: Icon(Icons.change_circle),
                label: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Text(
                    'Change Token',
                    style: TextStyle(
                      backgroundColor: Colors.red,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );*/
  }
}