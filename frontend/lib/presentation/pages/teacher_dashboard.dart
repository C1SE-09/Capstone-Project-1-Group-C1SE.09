import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final ext = filePath.split('.').last.toLowerCase();

        if (!['m4a', 'mp3', 'wav', 'webm'].contains(ext)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Định dạng file không hỗ trợ. Vui lòng chọn .m4a, .mp3, .wav hoặc .webm'),
            ),
          );
          return;
        }

        if (!context.mounted) return;
        const testClassId = 'aaaaaaaa-0000-0000-0000-000000000001';
        const testTeacherId = 'bbbbbbbb-0000-0000-0000-000000000001';
        context.push(
          '/recording?classId=$testClassId&teacherId=$testTeacherId&filePath=${Uri.encodeComponent(filePath)}',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi chọn file âm thanh: $e')),
      );
    }
  }

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
              const fileName = 'TEST.m4a';
              const assetPath = 'assets/audio/TEST.m4a';
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
                // Fallback đọc trực tiếp từ backend/TEST.m4a
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _pickAudioFile(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Tải file âm thanh từ máy'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

