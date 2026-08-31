import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.push('/teacher'),
              child: const Text('Login as Teacher'),
            ),
            ElevatedButton(
              onPressed: () => context.push('/parent'),
              child: const Text('Login as Parent'),
            ),
            ElevatedButton(
              onPressed: () => context.push('/admin'),
              child: const Text('Login as Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
