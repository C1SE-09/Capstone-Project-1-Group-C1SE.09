import 'package:adark_frontend/data/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => context.go("/login"),
              )
            : null,
        title: const Text("ADARK"),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isDarkMode,
            builder: (context, darkMode, child) {
              return IconButton(
                onPressed: () {
                  isDarkMode.value = !isDarkMode.value;
                },
                icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode),
              );
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (int index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Teacher'),
          NavigationDestination(
            icon: Icon(Icons.family_restroom),
            label: 'Parent',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/profile')) return 1;
    if (location.startsWith('/teacher')) return 2;
    if (location.startsWith('/parent')) return 3;
    if (location.startsWith('/admin')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/profile');
        break;
      case 2:
        context.go('/teacher');
        break;
      case 3:
        context.go('/parent');
        break;
      case 4:
        context.go('/admin');
        break;
    }
  }
}
