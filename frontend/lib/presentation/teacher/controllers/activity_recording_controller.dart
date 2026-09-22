// frontend/lib/presentation/teacher/controllers/activity_recording_controller.dart

import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:adark_frontend/presentation/shared/view_state.dart';
import 'package:flutter/foundation.dart';

/// Controller màn "Ghi nhận hoạt động".
///
/// Mặc định dùng [HttpClassDataRepository] (API thật từ class_data.py).
/// Truyền [ClassDataRepository] khác để test mà không cần gọi mạng.
class ActivityRecordingController extends ChangeNotifier {
  ActivityRecordingController({ClassDataRepository? repository})
      : _repository = repository ?? HttpClassDataRepository();

  final ClassDataRepository _repository;

  ViewState _state = ViewState.loading;
  String? _error;
  List<Child> _children = const [];
  ClassInfo? _classInfo;
  String _query = '';

  ViewState get state => _state;
  String? get error => _error;
  String get query => _query;
  ClassInfo? get classInfo => _classInfo;

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
      // Lấy song song thông tin lớp + danh sách trẻ.
      final results = await Future.wait([
        _repository.getClassInfo(classId),
        _repository.getClassChildren(classId),
      ]);
      _classInfo = results[0] as ClassInfo;
      _children = results[1] as List<Child>;
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