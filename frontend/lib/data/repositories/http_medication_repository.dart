// API thuốc và sự cố; không tự phát lại thao tác chưa rõ kết quả.
import 'dart:typed_data';

import 'package:adark_frontend/core/services/session_management_service.dart';
import 'package:adark_frontend/core/utils/api_config.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:adark_frontend/domain/entities/health/medication_schedule.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

class MedicationRequestException implements Exception {
  const MedicationRequestException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => message;
}

class MedicationAlreadyConfirmedException extends MedicationRequestException {
  MedicationAlreadyConfirmedException(super.message) : super(statusCode: 409);
}

class HttpMedicationRepository {
  HttpMedicationRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: AuthRepository.currentUser?.token == null
                    ? null
                    : {
                        'Authorization':
                            'Bearer ${AuthRepository.currentUser!.token}'
                      })) {
    _dio.interceptors
        .add(SessionManagementService.instance.createDioInterceptor(_dio));
  }
  final Dio _dio;

  Future<Response<dynamic>> _request(String method, String path,
      {Object? data,
      Map<String, dynamic>? query,
      ResponseType? responseType}) async {
    final sessions = SessionManagementService.instance;
    final sessionId = sessions.currentSession?.sessionId;
    try {
      final response = await _dio.request(path,
          data: data,
          queryParameters: query,
          options: Options(
              method: method,
              responseType: responseType,
              followRedirects: false,
              validateStatus: (_) => true));
      if (sessions.currentSession?.sessionId != sessionId) {
        throw const MedicationRequestException(
            'Phiên đã thay đổi. Vui lòng mở lại dữ liệu của bé.',
            code: 'session_changed');
      }
      if (response.statusCode == 401 &&
          sessionId != null &&
          sessions.currentSession?.sessionId == sessionId) {
        try {
          await sessions.refreshAccessToken(_dio);
        } on UserFacingException catch (error) {
          throw MedicationRequestException(error.userMessage,
              statusCode: error.statusCode);
        }
        throw const MedicationRequestException(
            'Phiên đã làm mới. Nội dung được giữ lại; hãy kiểm tra trạng thái rồi thử lại.',
            statusCode: 401,
            code: 'session_refreshed');
      }
      if ((response.statusCode ?? 500) >= 300) {
        throw _failure(response.data, response.statusCode);
      }
      return response;
    } on DioException {
      throw const MedicationRequestException(
          'Mất kết nối. Chưa xác nhận thao tác thành công; hãy tải lại trạng thái trước khi thử lại.',
          code: 'network_error');
    }
  }

  MedicationRequestException _failure(Object? body, int? status) {
    final detail = body is Map ? body['detail'] : null;
    final message = detail is String
        ? detail
        : detail is Map
            ? detail['message']?.toString()
            : detail is List
                ? detail
                    .whereType<Map>()
                    .map((e) => e['msg'])
                    .whereType<String>()
                    .join('\n')
                : null;
    return MedicationRequestException(
        message?.isNotEmpty == true
            ? message!
            : 'Không thể thực hiện. Vui lòng tải lại trạng thái.',
        statusCode: status,
        code: detail is Map ? detail['code']?.toString() : null);
  }

  Map<String, dynamic> _map(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const MedicationRequestException(
          'Dữ liệu máy chủ không hợp lệ; chưa thể xác nhận kết quả.',
          code: 'invalid_response');
    }
    return body;
  }

  MedicationDose _dose(Object? data) {
    try {
      return MedicationDose.fromJson(_map(data));
    } on FormatException {
      throw const MedicationRequestException(
          'Dữ liệu cữ thuốc không hợp lệ. Vui lòng tải lại.',
          code: 'invalid_response');
    }
  }

  Future<List<MedicationDose>> getMedicationRequests(
      {required String childId, String? batchId}) async {
    final items = <MedicationDose>[];
    final ids = <String>{};
    while (true) {
      final response =
          await _request('GET', '/api/medication-requests', query: {
        'child_id': childId,
        if (batchId != null) 'batch_id': batchId,
        'offset': items.length,
        'limit': 100
      });
      if (response.data is! List) {
        throw const MedicationRequestException(
            'Máy chủ chưa trả đúng danh sách cữ thuốc.');
      }
      final page = (response.data as List).map(_dose).toList();
      for (final dose in page) {
        if (dose.childId != childId ||
            (batchId != null && (dose.batchId ?? dose.id) != batchId) ||
            !ids.add(dose.id)) {
          throw const MedicationRequestException(
              'Không thể xác minh danh sách theo bé/đợt thuốc. Cần cập nhật hoặc tải lại máy chủ.',
              code: 'invalid_response');
        }
      }
      items.addAll(page);
      if (page.length < 100) return items;
    }
  }

  Future<MedicationBatchCreateResult> createMedicationRequests(
      {required String childId,
      required DateTime fromDate,
      required DateTime toDate,
      required List<String> timeSlots,
      required String medicineCategory,
      String? medicineName,
      required String dosage,
      required String prescriptionImageUrl,
      String? notes}) async {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final path = _imagePath(prescriptionImageUrl);
    if (!path.startsWith('/api/medication-requests/attachments/$childId/')) {
      throw const MedicationRequestException('Ảnh không thuộc bé này.');
    }
    final response = await _request('POST', '/api/medication-requests', data: {
      'child_id': childId,
      'from_date': day(fromDate),
      'to_date': day(toDate),
      'time_slots': timeSlots,
      'medicine_category': medicineCategory,
      'medicine_name': medicineName?.trim(),
      'dosage': dosage.trim(),
      'notes': notes?.trim(),
      'prescription_image_url': path
    });
    final body = _map(response.data);
    final batchId = body['batch_id'];
    final raw = body['items'];
    if (batchId is! String || batchId.isEmpty || raw is! List || raw.isEmpty) {
      throw const MedicationRequestException(
          'Chưa thể xác minh đợt thuốc đã tạo. Hãy tải lại danh sách.');
    }
    final items = raw.map(_dose).toList();
    if (items.any((d) => d.childId != childId || d.batchId != batchId) ||
        body['total_slots'] != items.length) {
      throw const MedicationRequestException(
          'Kết quả tạo đợt thuốc không khớp. Hãy tải lại danh sách, không gửi lại tự động.');
    }
    return MedicationBatchCreateResult(batchId, items);
  }

  Future<MedicationDose> cancelMedicationRequest(String id) async {
    final response = await _request(
        'POST', '/api/medication-requests/${Uri.encodeComponent(id)}/cancel',
        data: {});
    final dose = _dose(response.data);
    if (dose.id != id || dose.status != 'cancelled') {
      throw const MedicationRequestException(
          'Chưa xác nhận hủy cữ thuốc. Hãy tải lại trạng thái.');
    }
    return dose;
  }

  Future<int> cancelMedicationBatch(String batchId) async {
    final response = await _request('POST',
        '/api/medication-requests/batch/${Uri.encodeComponent(batchId)}/cancel',
        data: {});
    final body = _map(response.data);
    final count = body['cancelled_count'];
    if (body['batch_id'] != batchId || count is! int || count < 0) {
      throw const MedicationRequestException(
          'Chưa thể xác minh kết quả hủy đợt thuốc.');
    }
    return count;
  }

  Future<String> uploadPrescription(
      {required String childId, required Uint8List bytes}) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const MedicationRequestException('Ảnh phải từ 1 byte đến 5 MiB.');
    }
    bool starts(List<int> signature, [int at = 0]) =>
        bytes.length >= at + signature.length &&
        signature.asMap().entries.every((e) => bytes[at + e.key] == e.value);
    final String type;
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) {
      type = 'png';
    } else if (starts([255, 216, 255])) {
      type = 'jpeg';
    } else if (starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8)) {
      type = 'webp';
    } else {
      throw const MedicationRequestException(
          'Vui lòng chọn ảnh JPEG, PNG hoặc WebP hợp lệ.');
    }
    final response =
        await _request('POST', '/api/medication-requests/attachments',
            query: {'child_id': childId},
            data: FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes,
                  filename: 'prescription.$type',
                  contentType: MediaType('image', type))
            }));
    final path = _map(response.data)['prescription_image_url'];
    if (path is! String) {
      throw const MedicationRequestException(
          'Máy chủ chưa xác nhận ảnh đã tải lên.');
    }
    final checked = _imagePath(path);
    if (!checked.startsWith('/api/medication-requests/attachments/$childId/')) {
      throw const MedicationRequestException(
          'Ảnh máy chủ trả về không khớp bé.');
    }
    return checked;
  }

  String _imagePath(String value) {
    Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      throw const MedicationRequestException('Đường dẫn ảnh không hợp lệ.');
    }
    final base = Uri.parse(_dio.options.baseUrl);
    if (((uri.hasScheme || uri.hasAuthority) &&
            (uri.scheme != base.scheme ||
                uri.host != base.host ||
                uri.port != base.port)) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^/api/medication-requests/attachments/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$')
            .hasMatch(uri.path)) {
      throw const MedicationRequestException(
          'Ảnh cũ hoặc đường dẫn ngoài kho riêng tư không thể mở trong ứng dụng.');
    }
    return uri.path;
  }

  Future<Uint8List> getPrescriptionBytes(String path) async {
    final checked = _imagePath(path);
    final response =
        await _request('GET', checked, responseType: ResponseType.bytes);
    final bytes = response.data;
    if (bytes is! List<int> ||
        bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024) {
      throw const MedicationRequestException('Ảnh tải về không hợp lệ.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<MedicationsTodayData> getTodayMedications({String? date}) async {
    final response = await _request('GET', '/api/teacher/medications/today',
        query: date == null ? null : {'date': date});
    final body = _map(response.data);
    if (body['date'] is! String ||
        DateTime.tryParse(body['date'] as String) == null ||
        body['class_id'] is! String ||
        (body['class_id'] as String).isEmpty ||
        ['morning', 'noon', 'afternoon'].any((key) => body[key] is! List)) {
      throw const MedicationRequestException(
          'Dữ liệu lịch thuốc không hợp lệ. Vui lòng tải lại.',
          code: 'invalid_response');
    }
    try {
      final data = MedicationsTodayData.fromJson(body);
      if (data.totalRequests != data.allItems.length ||
          data.completedCount + data.pendingCount != data.totalRequests ||
          data.completedCount < 0 ||
          data.pendingCount < 0 ||
          data.morning.any((d) => d.session != 'morning') ||
          data.noon.any((d) => d.session != 'noon') ||
          data.afternoon.any((d) => d.session != 'afternoon')) {
        throw const MedicationRequestException(
            'Danh sách và số cữ chưa khớp. Vui lòng tải lại.',
            code: 'invalid_response');
      }
      return data;
    } on TypeError {
      throw const MedicationRequestException('Dữ liệu cữ thuốc không hợp lệ.',
          code: 'invalid_response');
    }
  }

  Future<Map<String, dynamic>> confirmMedication(
      {required String requestId,
      required String session,
      String? date,
      String? notes}) async {
    try {
      final response = await _request('PUT',
          '/api/teacher/medications/${Uri.encodeComponent(requestId)}/confirm',
          query: date == null ? null : {'date': date},
          data: {
            'session': session,
            if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim()
          });
      return _map(response.data);
    } on MedicationRequestException catch (error) {
      if (error.statusCode == 409) {
        throw MedicationAlreadyConfirmedException(error.message);
      }
      rethrow;
    }
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
    return _map(response.data);
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts(
      String childId) async {
    final response = await _request('GET',
        '/api/teacher/health-incidents/emergency-contacts/${Uri.encodeComponent(childId)}');
    final rows = _map(response.data)['emergency_contacts'];
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw const MedicationRequestException(
          'Danh bạ máy chủ trả về không hợp lệ.');
    }
    return rows.cast<Map<String, dynamic>>();
  }
}
