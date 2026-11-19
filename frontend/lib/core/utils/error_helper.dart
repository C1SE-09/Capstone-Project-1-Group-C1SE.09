import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';

/// Chuyển đổi mọi loại lỗi (DioException, Exception, SocketException, v.v.)
/// thành thông điệp thân thiện, dễ hiểu cho người dùng (hỗ trợ cả Tiếng Việt và English).
/// Tuyệt đối không hiển thị mã lỗi kỹ thuật thô (HTTP 400, 500, DioException, validateStatus).
String getFriendlyErrorMessage(
  dynamic error, {
  String? fallback,
}) {
  final isEn = LocaleController.instance.isEnglish;
  final effectiveFallback = fallback ??
      (isEn
          ? 'An error occurred. Please try again later.'
          : 'Đã có lỗi xảy ra. Vui lòng thử lại sau.');

  if (error == null) return effectiveFallback;

  // 1. Ngoại lệ có sẵn trường userMessage (như UserFacingException)
  try {
    final dynamic dyn = error;
    final String? userMsg = dyn.userMessage?.toString().trim();
    if (userMsg != null && userMsg.isNotEmpty && !_isTechnicalErrorString(userMsg)) {
      return formatFriendlyDetail(userMsg);
    }
  } catch (_) {}

  // 2. Xử lý các Exception nghiệp vụ tự định nghĩa (ClassDataException, TeacherRepositoryException, ScheduleException, AuthException)
  final errType = error.runtimeType.toString();
  if (errType == 'ClassDataException' ||
      errType == 'TeacherRepositoryException' ||
      errType == 'ScheduleException' ||
      errType == 'AuthException' ||
      errType == 'UserFacingException' ||
      errType == 'OfflineException' ||
      errType == 'SessionExpiredException') {
    try {
      final dynamic dynamicError = error;
      final String? msg = dynamicError.message?.toString().trim();
      final int? statusCode = dynamicError.statusCode as int?;
      if (statusCode != null) {
        if (statusCode == 409) {
          return isEn ? 'Phone number is already in use' : 'Số điện thoại đã được sử dụng';
        }
        if (msg == null || msg.isEmpty || msg.toLowerCase() == 'lỗi' || msg.toLowerCase() == 'error' || _isTechnicalErrorString(msg)) {
          return _statusCodeToFriendlyMessage(statusCode);
        }
      }
      if (msg != null && msg.isNotEmpty && msg.toLowerCase() != 'lỗi' && !_isTechnicalErrorString(msg)) {
        return formatFriendlyDetail(msg);
      }
      if (statusCode != null) {
        return _statusCodeToFriendlyMessage(statusCode);
      }
    } catch (_) {}
  }

  // 3. Xử lý DioException từ các cuộc gọi API HTTP
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return isEn
          ? 'Server connection timed out. Please check your network connection.'
          : 'Kết nối máy chủ bị quá thời gian. Vui lòng kiểm tra lại đường truyền mạng.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return isEn
          ? 'Cannot connect to server. Please check your Wifi/4G connection or try again later.'
          : 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng (Wifi/4G) hoặc thử lại sau.';
    }

    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail != null) {
          if (detail is String && detail.trim().isNotEmpty) {
            return formatFriendlyDetail(detail.trim());
          } else if (detail is List && detail.isNotEmpty) {
            // FastAPI Pydantic validation error: [{'loc': ['body', 'field'], 'msg': '...'}]
            final first = detail.first;
            if (first is Map) {
              final locList = first['loc'] as List?;
              final field = locList != null && locList.isNotEmpty ? locList.last.toString() : null;
              final fieldName = translateField(field);
              final msg = first['msg']?.toString();
              if (msg != null && msg.isNotEmpty && !_isTechnicalErrorString(msg)) {
                return formatFriendlyDetail(msg);
              }
              return isEn
                  ? 'Information for $fieldName is invalid or improperly formatted.'
                  : 'Thông tin $fieldName chưa đúng định dạng hoặc không hợp lệ.';
            }
          }
        }

        final message = data['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return formatFriendlyDetail(message.toString().trim());
        }
      }

      final statusCode = response.statusCode;
      if (statusCode != null) {
        return _statusCodeToFriendlyMessage(statusCode);
      }
    }

    return isEn
        ? 'Cannot connect to server. Please check your network connection.'
        : 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
  }

  final str = error.toString().trim();
  final lower = str.toLowerCase();

  // 4. Lỗi xử lý âm thanh & file upload
  if (lower.contains('quá lớn') ||
      lower.contains('413') ||
      lower.contains('too large') ||
      lower.contains('payload')) {
    return isEn
        ? 'Audio file is too large (exceeds 25MB limit). Please select a smaller file.'
        : 'File ghi âm quá lớn (vượt quá 25MB). Vui lòng chọn file dung lượng nhỏ hơn.';
  }

  if (lower.contains('unsupported audio format') ||
      lower.contains('định dạng file không được hỗ trợ') ||
      lower.contains('định dạng âm thanh không hợp lệ')) {
    return isEn
        ? 'Unsupported file format. Please upload an audio file (.mp3, .wav, .m4a, .webm).'
        : 'Định dạng file không được hỗ trợ. Vui lòng tải lên file âm thanh định dạng .mp3, .wav, .m4a, .webm.';
  }

  if (lower.contains('on web') ||
      lower.contains('unimplementederror') ||
      lower.contains('bytes property') ||
      lower.contains('flutter_file_picker')) {
    return isEn
        ? 'Cannot read file in browser. Please select an audio file (.mp3, .wav, .m4a).'
        : 'Không thể đọc file trên trình duyệt. Vui lòng chọn lại file âm thanh (.mp3, .wav, .m4a).';
  }

  if (lower.contains('nội dung file âm thanh rỗng') ||
      lower.contains('không nhận diện được nội dung') ||
      lower.contains('không thể nhận dạng tiếng nói') ||
      lower.contains('không nhận dạng được') ||
      lower.contains('không có âm thanh')) {
    return isEn
        ? 'No speech recognized from audio file. Please speak louder, clearly, or try again.'
        : 'Không nhận diện được giọng nói từ file ghi âm. Vui lòng nói to, rõ ràng hơn hoặc thử lại.';
  }

  if (lower.contains('nhận dạng giọng nói thất bại') ||
      lower.contains('speech-to-text') ||
      lower.contains('phowhisper')) {
    return isEn
        ? 'Failed to recognize speech from audio file. Please try again or choose another file.'
        : 'Không thể nhận diện giọng nói từ file ghi âm. Vui lòng thử lại hoặc chọn file khác.';
  }

  // 5. Lọc bỏ chuỗi kỹ thuật thô
  if (_isTechnicalErrorString(str)) {
    if (str.contains('409')) {
      return isEn
          ? 'Data already exists or conflicts on the system.'
          : 'Dữ liệu đã tồn tại hoặc xảy ra xung đột trên hệ thống.';
    }
    if (str.contains('403')) {
      return isEn
          ? 'You do not have permission to perform this action.'
          : 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (str.contains('404')) {
      return isEn
          ? 'Requested data was not found on the system.'
          : 'Không tìm thấy dữ liệu yêu cầu trên hệ thống.';
    }
    if (str.contains('422') || str.contains('400')) {
      return isEn
          ? 'Input data format is invalid. Please check your information.'
          : 'Dữ liệu nhập vào chưa đúng định dạng. Vui lòng kiểm tra lại thông tin.';
    }
    return effectiveFallback;
  }

  if (str.contains('SocketException') ||
      str.contains('Failed host lookup') ||
      str.contains('Network is unreachable') ||
      str.contains('Connection refused')) {
    return isEn
        ? 'Cannot connect to server. Please check your Wifi/4G connection.'
        : 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng Wifi/4G.';
  }

  if (str.startsWith('Exception: ')) {
    final clean = str.substring('Exception: '.length).trim();
    if (clean.isNotEmpty && !_isTechnicalErrorString(clean)) {
      return formatFriendlyDetail(clean);
    }
  }

  return str.isNotEmpty && !_isTechnicalErrorString(str) ? str : effectiveFallback;
}

bool _isTechnicalErrorString(String text) {
  final lower = text.toLowerCase();
  return lower.contains('dioexception') ||
      lower.contains('bad response') ||
      lower.contains('validatestatus') ||
      lower.contains('client error') ||
      lower.contains('status code') ||
      lower.contains('stack trace') ||
      lower.contains('stacktrace') ||
      lower.contains('http exception') ||
      lower.contains('handshakeexception') ||
      lower.contains('certificate');
}

String _statusCodeToFriendlyMessage(int statusCode) {
  final isEn = LocaleController.instance.isEnglish;
  switch (statusCode) {
    case 400:
      return isEn
          ? 'Submitted information is invalid or already exists on the system.'
          : 'Thông tin gửi lên chưa hợp lệ hoặc đã tồn tại trên hệ thống.';
    case 401:
      return isEn
          ? 'Session expired. Please log in again.'
          : 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
    case 403:
      return isEn
          ? 'You do not have permission to perform this action.'
          : 'Bạn không có quyền thực hiện thao tác này.';
    case 404:
      return isEn
          ? 'Requested data was not found on the system.'
          : 'Không tìm thấy dữ liệu yêu cầu trên hệ thống.';
    case 409:
      return isEn
          ? 'Phone number is already in use'
          : 'Số điện thoại đã được sử dụng';
    case 413:
      return isEn
          ? 'Uploaded file is too large (exceeds allowed limit).'
          : 'File tải lên quá lớn (vượt quá dung lượng cho phép).';
    case 422:
      return isEn
          ? 'Input data format is invalid. Please check your data.'
          : 'Dữ liệu nhập vào chưa đúng định dạng. Vui lòng kiểm tra lại.';
    case 500:
    case 502:
    case 503:
      return isEn
          ? 'Server error. Please try again in a few minutes.'
          : 'Hệ thống máy chủ đang gặp sự cố. Vui lòng thử lại sau ít phút.';
    default:
      return isEn
          ? 'An error occurred. Please try again later.'
          : 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
  }
}

/// Chuẩn hóa câu thông báo lỗi chi tiết sang ngôn ngữ tự nhiên
String formatFriendlyDetail(String detail) {
  final isEn = LocaleController.instance.isEnglish;
  final lower = detail.toLowerCase();

  // Tên đăng nhập & email & SĐT
  if (lower.contains('tên đăng nhập') && (lower.contains('tồn tại') || lower.contains('đã có'))) {
    return isEn
        ? 'This username is already taken. Please choose another username.'
        : 'Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên đăng nhập khác.';
  }

  if (lower.contains('email') && (lower.contains('tồn tại') || lower.contains('sử dụng') || lower.contains('đã có'))) {
    return isEn
        ? 'This email is already registered. Please use another email address.'
        : 'Email này đã được đăng ký trên hệ thống. Vui lòng sử dụng địa chỉ email khác.';
  }

  if ((lower.contains('số điện thoại') || lower.contains('phone')) &&
      (lower.contains('tồn tại') || lower.contains('sử dụng') || lower.contains('đăng ký'))) {
    return isEn ? 'Phone number is already in use' : 'Số điện thoại đã được sử dụng';
  }

  if (lower.contains('mật khẩu') && lower.contains('không đúng')) {
    return isEn
        ? 'Current password is incorrect. Please check again.'
        : 'Mật khẩu hiện tại không chính xác. Vui lòng kiểm tra lại.';
  }

  // Anh - Việt hóa các lỗi hệ thống phổ biến
  if (lower == 'child not found' || lower.contains('child not found')) {
    return isEn ? 'Child information not found.' : 'Không tìm thấy thông tin của trẻ trên hệ thống.';
  }
  if (lower == 'parent not found' || lower.contains('parent not found')) {
    return isEn ? 'Parent information not found.' : 'Không tìm thấy thông tin phụ huynh trên hệ thống.';
  }
  if (lower == 'teacher not found' || lower.contains('teacher not found')) {
    return isEn ? 'Teacher information not found.' : 'Không tìm thấy thông tin giáo viên trên hệ thống.';
  }
  if (lower == 'report not found' || lower.contains('report not found')) {
    return isEn ? 'Report not found.' : 'Không tìm thấy báo cáo yêu cầu.';
  }
  if (lower == 'voicerecord not found' || lower == 'voice record not found') {
    return isEn ? 'Voice record not found.' : 'Không tìm thấy bản ghi âm yêu cầu.';
  }
  if (lower.contains('not authenticated') || lower.contains('token expired') || lower.contains('invalid token')) {
    return isEn
        ? 'Session expired or invalid. Please log in again.'
        : 'Phiên làm việc đã kết thúc hoặc không hợp lệ. Vui lòng đăng nhập lại.';
  }
  if (lower == 'forbidden' || lower.contains('permission denied')) {
    return isEn
        ? 'You do not have permission to perform this action.'
        : 'Bạn không có quyền thực hiện thao tác này.';
  }

  return detail;
}

/// Chuyển tên trường kỹ thuật sang nhãn thân thiện
String translateField(String? field) {
  final isEn = LocaleController.instance.isEnglish;
  switch (field?.toLowerCase()) {
    case 'username':
      return isEn ? 'username' : 'tài khoản đăng nhập';
    case 'email':
      return isEn ? 'email address' : 'địa chỉ email';
    case 'phone':
      return isEn ? 'phone number' : 'số điện thoại';
    case 'password':
      return isEn ? 'password' : 'mật khẩu';
    case 'full_name':
      return isEn ? 'full name' : 'họ và tên';
    case 'nickname':
      return isEn ? 'nickname' : 'tên biệt danh';
    case 'date_of_birth':
      return isEn ? 'date of birth' : 'ngày sinh';
    case 'gender':
      return isEn ? 'gender' : 'giới tính';
    case 'medical_allergies':
      return isEn ? 'allergies & health' : 'dị ứng & sức khỏe';
    case 'class_id':
      return isEn ? 'classroom' : 'lớp học';
    case 'room_number':
    case 'room_name':
      return isEn ? 'room' : 'phòng học';
    case 'teacher_id':
      return isEn ? 'teacher' : 'giáo viên';
    case 'slot_id':
      return isEn ? 'time slot' : 'tiết học';
    case 'subject_id':
      return isEn ? 'subject' : 'môn học';
    case 'activity_name':
      return isEn ? 'activity name' : 'tên hoạt động';
    default:
      return field ?? (isEn ? 'data' : 'dữ liệu');
  }
}

/// Hiển thị SnackBar lỗi chuẩn hóa trên bất kỳ màn hình nào
void showFriendlyErrorSnackBar(
  BuildContext context,
  dynamic error, {
  String? fallback,
}) {
  final message = getFriendlyErrorMessage(error, fallback: fallback);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
    ),
  );
}
