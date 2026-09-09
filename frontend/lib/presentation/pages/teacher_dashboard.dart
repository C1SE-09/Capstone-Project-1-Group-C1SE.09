import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
              // --- Nguồn file âm thanh mẫu ---
              const assetPath = 'assets/audio/TEST.m4a';
              final fileName = assetPath.split('/').last;
              final tempDir = Directory.systemTemp;
              final testAudioFile = File('${tempDir.path}/$fileName');
              
              try {
                final byteData = await rootBundle.load(assetPath);
                await testAudioFile.writeAsBytes(
                  byteData.buffer.asUint8List(
                    byteData.offsetInBytes,
                    byteData.lengthInBytes,
                  ),
                );
              } catch (_) {
                // Fallback nếu chạy trực tiếp không qua Flutter assets
                final sampleSource = File('backend/$fileName');
                if (await sampleSource.exists()) {
                  await sampleSource.copy(testAudioFile.path);
                }
              }
              // ----------------------------------------------------
              
              if (!context.mounted) return;
              // Dùng UUID thật từ database seed để test backend
              const testClassId = 'aaaaaaaa-0000-0000-0000-000000000001';
              const testTeacherId = 'bbbbbbbb-0000-0000-0000-000000000001';
              context.push(
                '/recording?classId=$testClassId&teacherId=$testTeacherId&filePath=${Uri.encodeComponent(testAudioFile.path)}',
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
