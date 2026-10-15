import 'package:dio/dio.dart';

/// Chuyển đổi mọi loại lỗi (DioException, Exception, SocketException, v.v.)
/// thành thông điệp thân thiện, dễ hiểu bằng tiếng Việt cho người dùng.
/// Tuyệt đối không hiển thị mã lỗi kỹ thuật thô (HTTP 400, 500, DioException, validateStatus).
String getFriendlyErrorMessage(
  dynamic error, {
  String fallback = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.',
}) {
  if (error == null) return fallback;

  if (error is DioException) {
    // 1. Lỗi kết nối / timeout mạng
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Kết nối máy chủ bị quá thời gian. Vui lòng kiểm tra lại đường truyền mạng.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng (Wifi/4G) hoặc thử lại sau.';
    }

    // 2. Phản hồi từ Backend
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail != null) {
          if (detail is String && detail.trim().isNotEmpty) {
            return formatFriendlyDetail(detail.trim());
          } else if (detail is List && detail.isNotEmpty) {
            // FastAPI Pydantic validation error: [{'loc': ['body', 'email'], 'msg': '...'}]
            final first = detail.first;
            if (first is Map) {
              final locList = first['loc'] as List?;
              final field = locList != null && locList.isNotEmpty ? locList.last.toString() : null;
              final fieldName = translateField(field);
              return 'Thông tin $fieldName chưa đúng định dạng hoặc không hợp lệ.';
            }
          }
        }

        final message = data['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return formatFriendlyDetail(message.toString().trim());
        }
      }

      final statusCode = response.statusCode;
      switch (statusCode) {
        case 400:
          return 'Thông tin gửi lên chưa hợp lệ hoặc đã tồn tại trên hệ thống.';
        case 401:
          return 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
        case 403:
          return 'Bạn không có quyền thực hiện thao tác này.';
        case 404:
          return 'Không tìm thấy dữ liệu yêu cầu trên hệ thống.';
        case 409:
          return 'Dữ liệu đã tồn tại hoặc xảy ra xung đột với bản ghi khác.';
        case 422:
          return 'Dữ liệu nhập vào chưa đúng định dạng. Vui lòng kiểm tra lại.';
        case 500:
        case 502:
        case 503:
          return 'Hệ thống máy chủ đang gặp sự cố. Vui lòng thử lại sau ít phút.';
      }
    }

    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
  }

  final str = error.toString().trim();

  // Kiểm tra chuỗi chứa dấu hiệu kỹ thuật thô
  if (str.contains('DioException') ||
      str.contains('bad response') ||
      str.contains('validateStatus') ||
      str.contains('Client error') ||
      str.contains('status code of 400')) {
    return 'Dữ liệu gửi lên không hợp lệ hoặc đã tồn tại. Vui lòng kiểm tra lại thông tin.';
  }

  if (str.contains('SocketException') ||
      str.contains('Failed host lookup') ||
      str.contains('Network is unreachable') ||
      str.contains('Connection refused')) {
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng Wifi/4G.';
  }

  if (str.startsWith('Exception: ')) {
    final clean = str.substring('Exception: '.length).trim();
    if (clean.isNotEmpty) return formatFriendlyDetail(clean);
  }

  return str.isNotEmpty ? str : fallback;
}

/// Chuẩn hóa câu thông báo lỗi chi tiết
String formatFriendlyDetail(String detail) {
  final lower = detail.toLowerCase();

  if (lower.contains('tên đăng nhập') && (lower.contains('tồn tại') || lower.contains('đã có'))) {
    return 'Tên đăng nhập này đã tồn tại trên hệ thống. Vui lòng chọn tên đăng nhập khác.';
  }

  if (lower.contains('email') && (lower.contains('tồn tại') || lower.contains('sử dụng') || lower.contains('đã có'))) {
    return 'Email này đã được đăng ký trên hệ thống. Vui lòng sử dụng địa chỉ email khác.';
  }

  if ((lower.contains('số điện thoại') || lower.contains('phone')) &&
      (lower.contains('tồn tại') || lower.contains('sử dụng') || lower.contains('đăng ký'))) {
    return 'Số điện thoại này đã được đăng ký trong hệ thống. Vui lòng kiểm tra lại.';
  }

  if (lower.contains('mật khẩu') && lower.contains('không đúng')) {
    return 'Mật khẩu hiện tại không chính xác. Vui lòng kiểm tra lại.';
  }

  return detail;
}

/// Chuyển tên trường kỹ thuật sang tiếng Việt
String translateField(String? field) {
  switch (field?.toLowerCase()) {
    case 'username':
      return 'tài khoản đăng nhập';
    case 'email':
      return 'địa chỉ email';
    case 'phone':
      return 'số điện thoại';
    case 'password':
      return 'mật khẩu';
    case 'full_name':
      return 'họ và tên';
    case 'class_id':
      return 'lớp học';
    default:
      return field ?? 'dữ liệu';
  }
}
