import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(25.0),
              child: Image.asset('lib/assets/images/background.jpg'),
            ),
            FilledButton(
              onPressed: () {
                context.go("/home");
              },
              child: Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
