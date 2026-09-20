// frontend/lib/presentation/controllers/activity_recording_controller.dart

import 'package:adark_frontend/data/repositories/mock_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/child.dart';
import 'package:adark_frontend/domain/repositories/dashboard_repository.dart';
import 'package:adark_frontend/presentation/controllers/view_state.dart';
import 'package:flutter/foundation.dart';

class ActivityRecordingController extends ChangeNotifier {
  ActivityRecordingController({DashboardRepository? repository})
      : _repository = repository ?? MockDashboardRepository();

  final DashboardRepository _repository;

  ViewState _state = ViewState.loading;
  String? _error;
  List<Child> _children = const [];
  String _query = '';

  ViewState get state => _state;
  String? get error => _error;
  String get query => _query;

  List<Child> get filteredChildren {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return _children;
    return _children
        .where((child) =>
            child.fullName.toLowerCase().contains(normalized) ||
            child.displayName.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<void> load(String classId) async {
    _state = ViewState.loading;
    _error = null;
    notifyListeners();
    try {
      _children = await _repository.getClassChildren(classId);
      _state = ViewState.success;
    } catch (error) {
      _error = error.toString();
      _state = ViewState.error;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }
}
