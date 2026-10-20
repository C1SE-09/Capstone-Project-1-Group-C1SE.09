// frontend/lib/core/services/crash_logging_service.dart
// =========================================================
// Service bắt lỗi toàn cục, lưu crash log vào file trên thiết bị
// và tự động gửi Crash Report về Backend API (FastAPI /api/bug-reports).

import 'dart:convert';
import 'dart:io';

import 'package:adark_frontend/core/utils/device_info_helper.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_bug_report_repository.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';
import 'package:adark_frontend/domain/repositories/bug_report_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLoggingService {
  static final CrashLoggingService instance = CrashLoggingService._internal();

  CrashLoggingService._internal();

  static const String _logFileName = 'app_crash_logs.txt';
  static const String _pendingCrashesFileName = 'pending_crashes.json';
  static const int _maxLogSizeBytes = 512 * 1024; // 512 KB xoay vòng
  static const int _maxReportsPerSession = 5; // Tối đa 5 report tự động/phiên

  int _sessionReportCount = 0;
  DateTime? _lastReportTime;
  String? _lastErrorSignature;
  bool _isFlushingPending = false;

  /// Khởi tạo bắt lỗi toàn cục cho Flutter app:
  /// 1. FlutterError.onError: bắt lỗi giao diện & widget tree
  /// 2. PlatformDispatcher.instance.onError: bắt uncaught async errors
  Future<void> initialize() async {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordCrash(
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        reason: details.context?.toString() ?? 'Flutter Framework Error',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordCrash(
        error: error,
        stackTrace: stack,
        reason: 'Platform/Async Uncaught Error',
      );
      return true;
    };

    // Thử gửi các crash pending từ các phiên trước (nếu có)
    flushPendingReports();
  }

  /// Ghi log lỗi vào file cục bộ và tự động gửi lên backend
  Future<void> recordCrash({
    required Object error,
    StackTrace? stackTrace,
    String reason = 'Unhandled Exception',
  }) async {
    final now = DateTime.now().toUtc();
    final trace = stackTrace ?? StackTrace.current;
    final errorStr = error.toString();
    final errorSignature = '${error.runtimeType}_${errorStr.hashCode}';

    // 1. Ghi vào file log cục bộ trên thiết bị
    await _writeToLocalLog(
      timestamp: now,
      reason: reason,
      error: errorStr,
      stackTrace: trace.toString(),
    );

    // 2. Chống lặp / spam API (debounce 30 giây cho cùng 1 lỗi hoặc vượt quá giới hạn phiên)
    if (_sessionReportCount >= _maxReportsPerSession) {
      debugPrint('[CrashLoggingService] Đã đạt giới hạn gửi crash report trong phiên.');
      return;
    }

    if (_lastReportTime != null &&
        _lastErrorSignature == errorSignature &&
        now.difference(_lastReportTime!).inSeconds < 30) {
      debugPrint('[CrashLoggingService] Bỏ qua gửi trùng lặp lỗi trong 30s: $errorSignature');
      return;
    }

    _lastReportTime = now;
    _lastErrorSignature = errorSignature;
    _sessionReportCount++;

    // 3. Chuẩn bị payload và gửi hoặc lưu hàng đợi
    await _dispatchCrashReport(
      timestamp: now,
      reason: reason,
      error: error,
      stackTrace: trace,
    );
  }

  /// Ghi log vào file nội bộ thiết bị (có xoay vòng file)
  Future<void> _writeToLocalLog({
    required DateTime timestamp,
    required String reason,
    required String error,
    required String stackTrace,
  }) async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        final length = await file.length();
        if (length > _maxLogSizeBytes) {
          // Xoay vòng file: đổi tên sang .old hoặc cắt bớt
          final oldFile = File('${file.path}.old');
          if (await oldFile.exists()) await oldFile.delete();
          await file.rename(oldFile.path);
        }
      }

      final currentUser = AuthRepository.currentUser;
      final userInfo = currentUser != null
          ? '${currentUser.username ?? currentUser.userId} (Role: ${currentUser.role})'
          : 'Anonymous (Chưa đăng nhập)';

      final logEntry = StringBuffer()
        ..writeln('================================================================')
        ..writeln('[CRASH REPORT] ${timestamp.toIso8601String()}')
        ..writeln('Reason: $reason')
        ..writeln('User: $userInfo')
        ..writeln('Error: $error')
        ..writeln('Stack trace:')
        ..writeln(stackTrace)
        ..writeln('================================================================\n');

      await file.writeAsString(logEntry.toString(), mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[CrashLoggingService] Không thể ghi log cục bộ: $e');
    }
  }

  /// Gửi crash report lên Backend API hoặc lưu vào pending nếu chưa đủ điều kiện
  Future<void> _dispatchCrashReport({
    required DateTime timestamp,
    required String reason,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    try {
      final deviceInfo = await DeviceInfoHelper.collect();
      final errorType = error.runtimeType.toString();
      final shortError = error.toString().replaceAll('\n', ' ').trim();
      final title = '[Tự động][Crash] $errorType: ${shortError.length > 120 ? "${shortError.substring(0, 120)}..." : shortError}';

      // Nội dung mô tả chi tiết kèm theo
      final descBuilder = StringBuffer()
        ..writeln('Thời điểm lỗi: ${timestamp.toIso8601String()}')
        ..writeln('Phân loại: $reason')
        ..writeln('Thiết bị: ${deviceInfo.deviceModel} | HĐH: ${deviceInfo.osVersion}')
        ..writeln('Phiên bản App: ${deviceInfo.appVersion} (build ${deviceInfo.buildNumber})')
        ..writeln('Kết nối: ${deviceInfo.networkType}')
        ..writeln('\n--- Chi tiết lỗi ---')
        ..writeln(error.toString())
        ..writeln('\n--- Stack Trace Tóm tắt ---')
        ..writeln(stackTrace.toString().split('\n').take(25).join('\n'));

      var description = descBuilder.toString();
      if (description.length > 3800) {
        description = '${description.substring(0, 3790)}\n...[Cắt bớt do quá dài]';
      }

      // Đính kèm file log chi tiết dạng UTF-8 bytes
      final fullLogContent = StringBuffer()
        ..writeln('KinderLog Crash Log File')
        ..writeln('Thời gian: ${timestamp.toIso8601String()}')
        ..writeln('Reason: $reason')
        ..writeln('Error: $error')
        ..writeln('Device: ${deviceInfo.deviceModel} | OS: ${deviceInfo.osVersion}')
        ..writeln('App: ${deviceInfo.appVersion} (build ${deviceInfo.buildNumber})')
        ..writeln('Network: ${deviceInfo.networkType}')
        ..writeln('\nFull Stack Trace:\n$stackTrace')
        ..toString();

      final logAttachment = BugReportAttachmentDraft(
        bytes: Uint8List.fromList(utf8.encode(fullLogContent.toString())),
        fileName: 'crash_log_${timestamp.millisecondsSinceEpoch}.txt',
        mimeType: 'text/plain',
      );

      final token = AuthRepository.currentUser?.token;
      if (token != null && token.isNotEmpty) {
        // Có phiên đăng nhập -> Gửi trực tiếp lên server
        final repo = HttpBugReportRepository();
        await repo.create(
          BugReportCreatePayload(
            title: title,
            description: description,
            category: BugCategory.crash,
            severity: BugSeverity.critical,
            appVersion: deviceInfo.appVersion,
            buildNumber: deviceInfo.buildNumber,
            osVersion: deviceInfo.osVersion,
            deviceModel: deviceInfo.deviceModel,
            networkType: deviceInfo.networkType,
            attachments: [logAttachment],
          ),
        );
        debugPrint('[CrashLoggingService] Đã gửi tự động báo cáo crash lên server thành công.');
      } else {
        // Chưa đăng nhập hoặc chưa có token -> Lưu vào pending
        debugPrint('[CrashLoggingService] Chưa có phiên đăng nhập, lưu crash vào pending.');
        await _savePendingReport({
          'title': title,
          'description': description,
          'app_version': deviceInfo.appVersion,
          'build_number': deviceInfo.buildNumber,
          'os_version': deviceInfo.osVersion,
          'device_model': deviceInfo.deviceModel,
          'network_type': deviceInfo.networkType,
          'log_content': fullLogContent.toString(),
          'timestamp': timestamp.millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint('[CrashLoggingService] Gửi crash report thất bại, lưu vào pending: $e');
    }
  }

  /// Lưu báo cáo lỗi vào danh sách chờ
  Future<void> _savePendingReport(Map<String, dynamic> reportData) async {
    try {
      final file = await _getPendingFile();
      List<dynamic> list = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          list = jsonDecode(content) as List<dynamic>;
        }
      }
      list.add(reportData);
      // Giữ tối đa 10 pending reports
      if (list.length > 10) {
        list = list.sublist(list.length - 10);
      }
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (e) {
      debugPrint('[CrashLoggingService] Lỗi khi lưu pending report: $e');
    }
  }

  /// Gửi toàn bộ các báo cáo pending khi user đã đăng nhập
  Future<void> flushPendingReports() async {
    if (_isFlushingPending) return;
    final token = AuthRepository.currentUser?.token;
    if (token == null || token.isEmpty) return;

    _isFlushingPending = true;
    try {
      final file = await _getPendingFile();
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      final list = jsonDecode(content) as List<dynamic>;
      if (list.isEmpty) return;

      final repo = HttpBugReportRepository();
      final remaining = <dynamic>[];

      for (final item in list) {
        try {
          final map = item as Map<String, dynamic>;
          final logContent = map['log_content'] as String? ?? '';
          final ts = map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

          final attachment = BugReportAttachmentDraft(
            bytes: Uint8List.fromList(utf8.encode(logContent)),
            fileName: 'pending_crash_$ts.txt',
            mimeType: 'text/plain',
          );

          await repo.create(
            BugReportCreatePayload(
              title: map['title'] as String? ?? '[Auto-Crash] Pending report',
              description: map['description'] as String? ?? 'Pending crash log',
              category: BugCategory.crash,
              severity: BugSeverity.critical,
              appVersion: map['app_version'] as String?,
              buildNumber: map['build_number'] as String?,
              osVersion: map['os_version'] as String?,
              deviceModel: map['device_model'] as String?,
              networkType: map['network_type'] as String?,
              attachments: [attachment],
            ),
          );
        } catch (e) {
          debugPrint('[CrashLoggingService] Không gửi được pending item: $e');
          remaining.add(item);
        }
      }

      if (remaining.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(jsonEncode(remaining), flush: true);
      }
    } catch (e) {
      debugPrint('[CrashLoggingService] Lỗi khi flush pending reports: $e');
    } finally {
      _isFlushingPending = false;
    }
  }

  /// Đọc toàn bộ nội dung file log cục bộ gần nhất
  Future<String> getRecentLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('[CrashLoggingService] Lỗi khi đọc file log: $e');
    }
    return '';
  }

  /// Xóa file log cục bộ
  Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Provider thư mục tài liệu lưu trữ (có thể override trong test)
  @visibleForTesting
  Future<Directory> Function()? directoryProvider;

  Future<File> _getLogFile() async {
    final dir = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_logFileName');
  }

  Future<File> _getPendingFile() async {
    final dir = directoryProvider != null
        ? await directoryProvider!()
        : await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_pendingCrashesFileName');
  }
}
