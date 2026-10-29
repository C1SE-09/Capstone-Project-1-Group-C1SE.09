// frontend/lib/data/repositories/http_medication_repository.dart
// ===============================================================
// Repository gọi API Dặn thuốc & Báo sự cố khẩn cấp của Giáo viên.

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:dio/dio.dart';

class MedicationAlreadyConfirmedException implements Exception {
  MedicationAlreadyConfirmedException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HttpMedicationRepository {
  HttpMedicationRepository({
    Dio? dio,
    String? baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: AuthRepository.currentUser?.token != null
                    ? {'Authorization': 'Bearer ${AuthRepository.currentUser!.token}'}
                    : null,
              ),
            ) {
    _dio.interceptors.add(
      SessionManagementService.instance.createDioInterceptor(_dio),
    );
  }

  final Dio _dio;

  /// Lấy danh sách học sinh cần uống thuốc trong ngày (Sáng, Trưa, Chiều).
  Future<MedicationsTodayData> getTodayMedications({String? date}) async {
    final response = await _dio.get(
      '/api/teacher/medications/today',
      queryParameters: date != null ? {'date': date} : null,
    );
    return MedicationsTodayData.fromJson(response.data as Map<String, dynamic>);
  }

  /// 1-chạm xác nhận đã cho bé uống thuốc buổi cụ thể.
  /// Bắt lỗi 409 Conflict khi cô khác cùng lớp đã bấm trước.
  Future<Map<String, dynamic>> confirmMedication({
    required String requestId,
    required String session,
    String? notes,
  }) async {
    try {
      final response = await _dio.put(
        '/api/teacher/medications/$requestId/confirm',
        data: {
          'session': session,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final detail = e.response?.data is Map
            ? (e.response?.data['detail']?.toString() ?? 'Thuốc đã được cho uống trước đó.')
            : 'Thuốc đã được cho uống trước đó.';
        throw MedicationAlreadyConfirmedException(detail);
      }
      rethrow;
    }
  }

  /// 1-chạm phát cảnh báo khẩn cấp (Sốt cao, tai nạn, dị ứng).
  /// Trả về danh sách số điện thoại Bố/Mẹ để gọi ngay.
  Future<Map<String, dynamic>> createHealthIncident({
    required String childId,
    required String incidentType,
    String? description,
    double? temperature,
    String? actionTaken,
  }) async {
    final response = await _dio.post(
      '/api/teacher/health-incidents',
      data: {
        'child_id': childId,
        'incident_type': incidentType,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (temperature != null) 'temperature': temperature,
        if (actionTaken != null && actionTaken.trim().isNotEmpty) 'action_taken': actionTaken.trim(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Lấy danh bạ khẩn cấp của bé để gọi điện SIM trực tiếp.
  Future<List<Map<String, dynamic>>> getEmergencyContacts(String childId) async {
    final response = await _dio.get(
      '/api/teacher/health-incidents/emergency-contacts/$childId',
    );
    final data = response.data;
    if (data is Map && data['contacts'] is List) {
      return (data['contacts'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
