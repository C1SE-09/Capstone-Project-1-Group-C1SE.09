// frontend/lib/presentation/controllers/teacher_home_controller.dart
// =========================================================

import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/entities/teacher.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:adark_frontend/presentation/controllers/view_state.dart';
import 'package:flutter/foundation.dart';

class TeacherHomeController extends ChangeNotifier {
  TeacherHomeController({DashboardRepository? repository})
      : _repo = repository ?? HttpDashboardRepository();

  final DashboardRepository _repo;

  ViewState _state = ViewState.loading;
  String? _error;
  Teacher? _teacher;
  ClassDashboardSummary? _summary;

  // ── Getters (chỉ đọc) ─────────────────────────────────────
  ViewState get state => _state;
  String? get error => _error;
  Teacher? get teacher => _teacher;
  ClassDashboardSummary? get summary => _summary;

  /// Tải toàn bộ dữ liệu cho màn Tổng quan.
  Future<void> load() async {
    _state = ViewState.loading;
    _error = null;
    notifyListeners(); // báo View: bắt đầu loading

    try {
      // 1. Lấy thông tin giáo viên
      final teacher = await _repo.getCurrentTeacher();

      // 2. Lấy tổng hợp lớp giáo viên quản lý (hôm nay)
      final summary = await _repo.getClassDashboard(
        teacher.classId ?? '',
        DateTime.now(),
      );

      _teacher = teacher;
      _summary = summary;
      _state = ViewState.success;
    } catch (e) {
      _error = e.toString();
      _state = ViewState.error;
    }
    notifyListeners(); // báo View: đã xong (success hoặc error)
  }
}
