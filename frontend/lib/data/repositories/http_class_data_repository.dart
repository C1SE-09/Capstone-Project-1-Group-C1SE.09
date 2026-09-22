import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart';
import 'package:dio/dio.dart';

abstract class ClassDataRepository {
  Future<ClassInfo> getClassInfo(String classId);
  Future<List<Child>> getClassChildren(String classId);
}

class ClassDataException implements Exception {
  const ClassDataException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ClassDataException($statusCode): $message';
}

class HttpClassDataRepository implements ClassDataRepository {
  HttpClassDataRepository({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? kApiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

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
        error.message ?? 'Không thể tải thông tin lớp.',
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
        error.message ?? 'Không thể tải danh sách trẻ.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ClassDataException('API trả về dữ liệu không hợp lệ.');
  }
}