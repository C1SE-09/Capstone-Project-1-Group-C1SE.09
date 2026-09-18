// frontend/lib/presentation/controllers/parent_home_controller.dart
// =========================================================
// Controller cho màn "Tổng quan" của phụ huynh.

import 'package:adark_frontend/data/repositories/mock_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child_overview.dart';
import 'package:adark_frontend/domain/entities/daily_report.dart';
import 'package:adark_frontend/domain/entities/parent.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:adark_frontend/presentation/controllers/view_state.dart';
import 'package:flutter/foundation.dart';

class ParentHomeController extends ChangeNotifier {
  ParentHomeController({DashboardRepository? repository})
      : _repo = repository ?? MockDashboardRepository();

  final DashboardRepository _repo;

  ViewState _state = ViewState.loading;
  String? _error;
  Parent? _parent;
  ChildOverview? _childOverview;
  DailyReport? _todayReport;
  List<DailyReport> _recentReports = [];

  // ── Getters ───────────────────────────────────────────────
  ViewState get state => _state;
  String? get error => _error;
  Parent? get parent => _parent;
  ChildOverview? get childOverview => _childOverview;
  DailyReport? get todayReport => _todayReport;
  List<DailyReport> get recentReports => _recentReports;

  Future<void> load() async {
    _state = ViewState.loading;
    _error = null;
    notifyListeners();

    try {
      // 1. Phụ huynh
      final parent = await _repo.getCurrentParent();
      // 2. Con + lớp + giáo viên (1 lần gọi)
      final childOverview = await _repo.getPrimaryChildOverview(parent.parentId);
      // 3. Báo cáo hôm nay + gần đây
      final today = await _repo.getTodayReport(
        childOverview.child.childId,
        DateTime.now(),
      );
      final recent = await _repo.getRecentReports(childOverview.child.childId);

      _parent = parent;
      _childOverview = childOverview;
      _todayReport = today;
      _recentReports = recent;
      _state = ViewState.success;
    } catch (e) {
      _error = e.toString();
      _state = ViewState.error;
    }
    notifyListeners();
  }
}