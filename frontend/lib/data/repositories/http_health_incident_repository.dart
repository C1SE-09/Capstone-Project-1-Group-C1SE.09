import 'package:dio/dio.dart';
import 'package:adark_frontend/core/errors/app_exception.dart';
import 'package:adark_frontend/core/network/api_client.dart';
import 'package:adark_frontend/core/services/session_management_service.dart';

class HealthIncidentException implements AppException {
  const HealthIncidentException(this.message, {this.statusCode, this.code});
  @override
  final String message;
  @override
  final int? statusCode;
  final String? code;
  @override
  String? get userMessage => null;
  @override
  String toString() => message;
}

class HttpHealthIncidentRepository {
  HttpHealthIncidentRepository({Dio? dio, String? baseUrl})
      : _dio = ApiClient.resolveDio(dio: dio, baseUrl: baseUrl);

  final Dio _dio;

  Future<Response<dynamic>> _request(String method, String path,
      {Object? data, Map<String, dynamic>? query}) async {
    final sessions = SessionManagementService.instance;
    final sessionId = sessions.currentSession?.sessionId;
    try {
      final response = await _dio.request(path,
          data: data,
          queryParameters: query,
          options: Options(
              method: method,
              followRedirects: false,
              validateStatus: (_) => true));
      if (sessions.currentSession?.sessionId != sessionId) {
        throw const HealthIncidentException(
            'Phiên đã thay đổi. Vui lòng thử lại.',
            code: 'session_changed');
      }
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return response;
      }
      throw _failure(response.data, response.statusCode);
    } on DioException catch (error) {
      throw HealthIncidentException(error.message ?? 'Lỗi kết nối mạng.');
    }
  }

  HealthIncidentException _failure(Object? body, int? status) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return HealthIncidentException(detail.trim(), statusCode: status);
      }
      final message = body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return HealthIncidentException(message.trim(), statusCode: status);
      }
    }
    return HealthIncidentException('Yêu cầu không thành công (HTTP $status)',
        statusCode: status);
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const HealthIncidentException('Dữ liệu không đúng định dạng JSON.');
  }

  Future<List<Map<String, dynamic>>> getHealthIncidents(
      {required String classId}) async {
    final response = await _request('GET', '/api/teacher/health-incidents',
        query: {'class_id': classId, 'offset': 0, 'limit': 50});
    if (response.data is! List) {
      throw const HealthIncidentException(
          'Máy chủ chưa trả đúng danh sách sự cố.');
    }
    final items = (response.data as List).map((raw) {
      if (raw is! Map<String, dynamic> ||
          raw['incident_id'] is! String ||
          raw['child_name'] is! String ||
          raw['incident_type_label'] is! String ||
          raw['description'] is! String ||
          DateTime.tryParse(raw['reported_at']?.toString() ?? '') == null) {
        throw const HealthIncidentException(
            'Dữ liệu sự cố không hợp lệ. Vui lòng tải lại.',
            code: 'invalid_response');
      }
      if (raw['class_id'] != classId) {
        throw const HealthIncidentException(
            'Không thể xác minh sự cố của lớp.',
            code: 'invalid_response');
      }
      return raw;
    }).toList();
    return items;
  }

  Future<Map<String, dynamic>> createHealthIncident(
      {required String childId,
      required String incidentType,
      String? description,
      double? temperature,
      String? actionTaken}) async {
    final response =
        await _request('POST', '/api/teacher/health-incidents', data: {
      'child_id': childId,
      'incident_type': incidentType,
      if (description?.trim().isNotEmpty == true)
        'description': description!.trim(),
      if (temperature != null) 'temperature': temperature,
      if (actionTaken?.trim().isNotEmpty == true)
        'action_taken': actionTaken!.trim()
    });
    final body = _map(response.data);
    if (body['incident_id'] is! String ||
        (body['incident_id'] as String).isEmpty ||
        body['child_id'] != childId ||
        body['child_name'] is! String ||
        body['incident_type'] != incidentType ||
        DateTime.tryParse(body['reported_at']?.toString() ?? '') == null) {
      throw const HealthIncidentException(
          'Chưa xác minh được biên bản đã lưu. Vui lòng kiểm tra trạng thái, không gửi lại tự động.',
          code: 'invalid_response');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(
      String childId) async {
    final response = await _request('GET',
        '/api/teacher/health-incidents/emergency-contacts/${Uri.encodeComponent(childId)}');
    final body = _map(response.data);
    if (body['child_id'] != childId) {
      throw const HealthIncidentException('Danh bạ không khớp bé đang xem.');
    }
    final rows = body['emergency_contacts'];
    if (rows is! List ||
        rows.any(
            (row) => row is! Map<String, dynamic> || row['phone'] is! String)) {
      throw const HealthIncidentException(
          'Danh bạ máy chủ trả về không hợp lệ.');
    }
    return rows.cast<Map<String, dynamic>>();
  }
}
