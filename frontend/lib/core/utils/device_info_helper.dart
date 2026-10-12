// frontend/lib/core/utils/device_info_helper.dart
// =========================================================
// Lấy thông tin thiết bị + app để gửi kèm khi user submit bug report.
// MIRROR backend/app/schemas/bug_report.py (BugReportCreate):
//   app_version, build_number, os_version, device_model, network_type
//
// Gọi từ form Bug Report:
//   final info = await DeviceInfoHelper.collect();
//   final payload = BugReportCreatePayload(
//     ...,
//     appVersion: info.appVersion,
//     osVersion: info.osVersion,
//     deviceModel: info.deviceModel,
//     networkType: info.networkType,
//   );

import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Thông tin thiết bị + app + mạng — dùng đính kèm vào bug report.
class DeviceInfo {
  const DeviceInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.osVersion,
    required this.deviceModel,
    required this.networkType,
  });

  final String appVersion; // vd: "1.2.3"
  final String buildNumber; // vd: "42"
  final String osVersion; // vd: "Android 14" hoặc "iOS 17.2"
  final String deviceModel; // vd: "Samsung SM-A546B" hoặc "iPhone 15 Pro"
  final String networkType; // 'wifi' | 'cellular' | 'offline'
}

class DeviceInfoHelper {
  DeviceInfoHelper._();

  /// Thu thập 1 lần: gọi khi user mở form Bug Report.
  /// Trả về DeviceInfo với fallback an toàn nếu plugin lỗi.
  static Future<DeviceInfo> collect() async {
    final app = await _safeApp();
    final os = await _safeOs();
    final network = await _safeNetwork();
    return DeviceInfo(
      appVersion: app.version.isEmpty ? 'unknown' : app.version,
      buildNumber: app.build.isEmpty ? '0' : app.build,
      osVersion: os.osLabel,
      deviceModel: os.modelLabel,
      networkType: network,
    );
  }

  // ─────────────────────────────────────────────────────────
  // App info (package_info_plus)
  // ─────────────────────────────────────────────────────────
  static Future<({String version, String build})> _safeApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return (version: info.version, build: info.buildNumber);
    } catch (_) {
      return (version: 'unknown', build: '0');
    }
  }

  // ─────────────────────────────────────────────────────────
  // OS + device model (device_info_plus)
  // ─────────────────────────────────────────────────────────
  static Future<({String osLabel, String modelLabel})> _safeOs() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        // osLabel: "Android 14" (version.release + sdkInt)
        return (
          osLabel: 'Android ${a.version.release} (SDK ${a.version.sdkInt})',
          modelLabel: '${a.manufacturer} ${a.model}'.trim(),
        );
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        return (
          osLabel: '${i.systemName} ${i.systemVersion}',
          modelLabel: i.utsname.machine,
        );
      }
      // Web, Windows, macOS, Linux
      return (osLabel: Platform.operatingSystem, modelLabel: 'unknown');
    } catch (_) {
      return (osLabel: 'unknown', modelLabel: 'unknown');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Network type (connectivity_plus)
  // ─────────────────────────────────────────────────────────
  static Future<String> _safeNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // results là List<ConnectivityResult> (multi-cast từ 1.0+)
      if (results.isEmpty) return 'offline';
      if (results.contains(ConnectivityResult.wifi)) return 'wifi';
      if (results.contains(ConnectivityResult.mobile)) return 'cellular';
      if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
      if (results.contains(ConnectivityResult.vpn)) return 'vpn';
      if (results.contains(ConnectivityResult.none)) return 'offline';
      return 'offline';
    } catch (_) {
      return 'offline';
    }
  }
}
