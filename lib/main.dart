import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:github_var_updater/api_service/github_api.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:github_var_updater/screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await GithubApi.loadPreviousUser();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Github Var Updater',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,  // Follow system settings
      home: MainScreen(key: AppNotifier.homePageKey),
    );
  }
}