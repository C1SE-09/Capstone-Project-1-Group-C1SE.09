// frontend/lib/core/notifications/emergency_siren_service.dart
// =========================================================
// Quản lý phát âm thanh còi hú báo động khẩn cấp (Task #294).
// - Sử dụng just_audio phát loop file âm thanh siren.wav ở âm lượng tối đa.
// - Hoạt động cả khi app ở chế độ âm lượng thường hoặc rung (fail-soft).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class EmergencySirenService {
  EmergencySirenService._();

  static final EmergencySirenService instance = EmergencySirenService._();

  AudioPlayer? _player;
  bool _isPlaying = false;

  /// Cờ bật/tắt để mock an toàn trong môi trường unit/widget test
  bool enabled = true;

  bool get isPlaying => _isPlaying;

  /// Bắt đầu phát còi hú khẩn cấp lặp lại liên tục cho đến khi được tắt.
  Future<void> playSiren() async {
    if (!enabled || _isPlaying) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.setAsset('assets/audio/siren.wav');
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);
      _isPlaying = true;
      await player.play();
    } on MissingPluginException {
      _isPlaying = false;
    } on Exception catch (e) {
      debugPrint('[EmergencySirenService] Không thể phát âm thanh còi hú: $e');
      _isPlaying = false;
    }
  }

  /// Tắt chuông báo động khi phụ huynh xác nhận hoặc bấm gọi cho cô giáo.
  Future<void> stopSiren() async {
    _isPlaying = false;
    if (_player == null) return;
    try {
      await _player?.stop();
    } on MissingPluginException {
      // Ignored in tests
    } catch (e) {
      debugPrint('[EmergencySirenService] Lỗi dừng còi hú: $e');
    }
  }

  /// Giải phóng tài nguyên khi không còn sử dụng.
  Future<void> dispose() async {
    try {
      await stopSiren();
      await _player?.dispose();
      _player = null;
    } on Exception catch (_) {}
  }
}
