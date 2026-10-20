import 'dart:io';

import 'package:adark_frontend/core/services/crash_logging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('crash_log_test_');
    CrashLoggingService.instance.directoryProvider = () async => tempDir;
    await CrashLoggingService.instance.clearLogs();
  });

  tearDown(() async {
    await CrashLoggingService.instance.clearLogs();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('CrashLoggingService ghi log cục bộ và đọc lại chính xác', () async {
    final service = CrashLoggingService.instance;

    await service.recordCrash(
      error: StateError('Test crash error'),
      stackTrace: StackTrace.current,
      reason: 'Unit Test Error Simulation',
    );

    final logs = await service.getRecentLogs();
    expect(logs, contains('[CRASH REPORT]'));
    expect(logs, contains('Unit Test Error Simulation'));
    expect(logs, contains('Bad state: Test crash error'));
    expect(logs, contains('Stack trace:'));
  });

  test('CrashLoggingService clearLogs xóa sạch file log', () async {
    final service = CrashLoggingService.instance;

    await service.recordCrash(
      error: Exception('Error to be deleted'),
      stackTrace: StackTrace.current,
    );

    expect((await service.getRecentLogs()).isNotEmpty, isTrue);

    await service.clearLogs();

    expect((await service.getRecentLogs()).isEmpty, isTrue);
  });
}
