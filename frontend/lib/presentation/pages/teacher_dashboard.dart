import 'dart:io';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Teacher Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () async {
              // --- ĐOẠN CODE TEST: TẠO FILE GIẢ ĐỂ TEST UPLOAD ---
              final tempDir = Directory.systemTemp;
              final dummyFile = File('${tempDir.path}/test_audio.m4a');
              if (!await dummyFile.exists()) {
                await dummyFile.writeAsString('Day la file am thanh gia de test');
              }
              // ----------------------------------------------------
              
              if (!context.mounted) return;
              // Dùng UUID thật từ database seed để test backend
              const testClassId = 'aaaaaaaa-0000-0000-0000-000000000001';
              const testTeacherId = 'bbbbbbbb-0000-0000-0000-000000000001';
              context.push(
                '/recording?classId=$testClassId&teacherId=$testTeacherId&filePath=${Uri.encodeComponent(dummyFile.path)}',
              );
            },
            icon: const Icon(Icons.mic),
            label: const Text('Ghi âm bài giảng'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
