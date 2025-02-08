import 'package:flutter/material.dart';
import 'package:github_var_updater/sections/github_account_section.dart';
import 'package:github_var_updater/sections/repository_section.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {

  late PageController _pageController;
  int _selectedIndex = 0;

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index, 
      duration: Duration(milliseconds: 500),
      curve: Curves.ease
    );  
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Github Var Updater',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(8.0),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          const GithubAccountSection(),
          const RepositorySection(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(color: Theme.of(context).primaryColorDark, spreadRadius: 0, blurRadius: 10),
          ]
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.person, size: 24),
                label: 'Github Account',
                activeIcon: Icon(Icons.person, size: 28)
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.list_alt, size: 24),
                label: 'Repositories',
                activeIcon: Icon(Icons.list_alt, size: 28)
              )
            ],
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}