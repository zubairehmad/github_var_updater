import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github_var_updater/utils/keystore.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Github Var Updater',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String? token;
  final TextEditingController controller = TextEditingController();

  Future<void> _saveApiToken() async {
    if (controller.text.isEmpty) return;
    try {
      await Keystore.savePair(key: 'github_api_token', value: controller.text);
      setState(() => token = controller.text);
    } catch (e) {
      print('An error occured: ${e.toString()}');
    }
  }

  Future<void> _fetchApiToken() async {
  try {
      String? githubToken = await Keystore.getValueForKey(key: 'github_api_token');
      if (githubToken != null) {
        setState(() => token = githubToken);
      }
    } catch (e) {
      print('An error occured: ${e.toString()}');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchApiToken();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        title: Text(
          'Github Var Updater',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(8.0),
          ),
        ),
      ),
      backgroundColor: colorScheme.primaryContainer,
      body: Padding(
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
                  style: ElevatedButton.styleFrom(
                    foregroundColor: colorScheme.onPrimary,
                    backgroundColor: colorScheme.primary,
                  ),
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
      ),
    );
  }
}