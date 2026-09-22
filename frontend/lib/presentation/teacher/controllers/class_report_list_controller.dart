// frontend/lib/presentation/teacher/controllers/class_report_list_controller.dart
// =====================================================================
// Controller cho danh sách lớp trong tab "Báo cáo lớp".

import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:flutter/foundation.dart';

class ClassReportListController extends ChangeNotifier {
  ClassReportListController({DashboardRepository? repository})
      : _repository = repository ?? HttpDashboardRepository();

  final DashboardRepository _repository;

  ViewState _state = ViewState.loading;
  String? _error;
  List<ClassReportOverview> _classes = const [];

  ViewState get state => _state;
  String? get error => _error;
  List<ClassReportOverview> get classes => _classes;

  Future<void> load() async {
    _state = ViewState.loading;
    _error = null;
    notifyListeners();

    try {
      _classes = await _repository.getTeacherClasses();
      _state = ViewState.success;
    } catch (error) {
      _error = error.toString();
      _state = ViewState.error;
    }

    notifyListeners();
  }
}
