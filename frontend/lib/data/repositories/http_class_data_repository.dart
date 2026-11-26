import 'package:adark_frontend/core/errors/app_exception.dart';
import 'package:adark_frontend/core/network/api_client.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:dio/dio.dart';

abstract class ClassDataRepository {
  Future<ClassInfo> getClassInfo(String classId);
  Future<List<Child>> getClassChildren(String classId);
}

class ClassDataException implements AppException {
  const ClassDataException(this.message, {this.statusCode});
  @override
  final String message;
  @override
  final int? statusCode;
  @override
  String? get userMessage => null;
  @override
  String toString() => 'ClassDataException($statusCode): $message';
}

class HttpClassDataRepository implements ClassDataRepository {
  HttpClassDataRepository({Dio? dio, String? baseUrl})
      : _dio = ApiClient.resolveDio(dio: dio, baseUrl: baseUrl);

  final Dio _dio;

  @override
  Future<ClassInfo> getClassInfo(String classId) async {
    try {
      final response = await _dio.get('/api/class/$classId');
      final data = _asMap(response.data);
      return ClassInfo(
        classId: data['class_id'] as String,
        schoolId: data['school_id'] as String? ?? '',
        name: data['name'] as String,
        gradeLabel: data['grade_label'] as String?,
        roomNumber: data['room_number'] as String?,
        capacity: data['capacity'] as int?,
        isActive: data['is_active'] as bool? ?? true,
      );
    } on DioException catch (error) {
      throw ClassDataException(
        'Không thể tải thông tin lớp. Vui lòng kiểm tra kết nối mạng và thử lại.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  @override
  Future<List<Child>> getClassChildren(String classId) async {
    try {
      final response = await _dio.get('/api/class/$classId/children');
      final data = _asMap(response.data);
      final rawChildren = data['children'];
      if (rawChildren is! List) return const [];
      return rawChildren
          .whereType<Map>()
          .map((item) => Child.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ClassDataException(
        'Không thể tải danh sách trẻ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ClassDataException('Dữ liệu lớp học nhận được không hợp lệ. Vui lòng thử lại sau.');
  }
}
