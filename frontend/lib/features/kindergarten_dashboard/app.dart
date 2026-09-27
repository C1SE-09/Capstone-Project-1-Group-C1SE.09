// New UI entrypoint - not wired to root main.dart yet.
import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/ui_types.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/teacher_shell.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

void main() => runApp(const KinderLogApp());

class KinderLogApp extends StatelessWidget {
  const KinderLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KinderLog',
      debugShowCheckedModeBanner: false,
      theme: kinderTheme(),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  UserRole? role;
  String? selectedClassId;

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (role == null) {
      page = LoginScreen(onLogin: (value) => setState(() => role = value));
    } else if (role == UserRole.teacher && selectedClassId == null) {
      page = ClassSelectScreen(onPick: (classId) => setState(() => selectedClassId = classId));
    } else if (role == UserRole.teacher) {
      page = TeacherShell(onLogout: _logout, classId: selectedClassId!);
    } else {
      page = const ParentFlow();
    }
    return Scaffold(body: SafeArea(child: page));
  }

  void _logout() => setState(() {
        role = null;
        selectedClassId = null;
      });
}
