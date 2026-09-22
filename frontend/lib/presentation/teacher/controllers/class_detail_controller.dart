// frontend/lib/presentation/teacher/controllers/class_detail_controller.dart
// =========================================================
// Controller cho màn "Chi tiết lớp" (MÀN 2).

import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/activity/activity_item.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:flutter/foundation.dart';

class ClassDetailController extends ChangeNotifier {
  ClassDetailController({DashboardRepository? repository})
      : _repo = repository ?? HttpDashboardRepository();

  final DashboardRepository _repo;

  ViewState _state = ViewState.loading;
  String? _error;
  ClassDashboardSummary? _summary;
  List<ActivityItem> _activities = [];

  // ── Getters ───────────────────────────────────────────────
  ViewState get state => _state;
  String? get error => _error;
  ClassDashboardSummary? get summary => _summary;
  List<ActivityItem> get activities => _activities;

  Future<void> load(String classId) async {
    _state = ViewState.loading;
    _error = null;
    notifyListeners();

    try {
      // Lấy song song (không cần đợi lần lượt) tổng hợp + hoạt động
      final results = await Future.wait([
        _repo.getClassDashboard(classId, DateTime.now()),
        _repo.getRecentActivities(classId),
      ]);

      _summary = results[0] as ClassDashboardSummary;
      _activities = results[1] as List<ActivityItem>;
      _state = ViewState.success;
    } catch (e) {
      _error = e.toString();
      _state = ViewState.error;
    }
    notifyListeners();
  }
}