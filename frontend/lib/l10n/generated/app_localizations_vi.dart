// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'KinderLog';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonEdit => 'Chỉnh sửa';

  @override
  String get commonLoading => 'Đang tải...';

  @override
  String get commonSuccess => 'Thành công';

  @override
  String get commonError => 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSelectTitle => 'Chọn ngôn ngữ hiển thị';

  @override
  String get loginWelcomeBack => 'Chào mừng trở lại!';

  @override
  String get loginTagline =>
      'Cùng gia đình lưu giữ từng khoảnh khắc khôn lớn của bé.';

  @override
  String get loginUsernameLabel => 'TÊN ĐĂNG NHẬP';

  @override
  String get loginUsernameHint => 'Nhập tên đăng nhập hoặc Gmail';

  @override
  String get loginPasswordLabel => 'MẬT KHẨU';

  @override
  String get loginPasswordHint => 'Nhập mật khẩu';

  @override
  String get loginRememberPassword => 'Lưu mật khẩu';

  @override
  String get loginForgotPassword => 'Quên mật khẩu?';

  @override
  String get loginButton => 'Đăng nhập';

  @override
  String get loginFooter => 'Kết nối lớp học · An tâm mỗi ngày';

  @override
  String get loginErrorEmpty =>
      'Vui lòng nhập đầy đủ tên đăng nhập/Gmail và mật khẩu.';

  @override
  String get loginErrorFailed =>
      'Đăng nhập không thành công. Quý phụ huynh và thầy cô vui lòng kiểm tra lại kết nối mạng hoặc thử lại sau.';

  @override
  String get loginErrorAdminWebOnly =>
      'Tài khoản Quản trị viên chỉ hỗ trợ trên phiên bản Web máy tính. Vui lòng truy cập cổng quản trị trên trình duyệt web.';

  @override
  String get loginRememberError =>
      'Không thể đọc thông tin đã nhớ. Bạn vẫn có thể đăng nhập.';

  @override
  String get loginRememberClearError =>
      'Chưa xóa được thông tin đã nhớ. Vui lòng thử lại.';

  @override
  String get loginShowPassword => 'Hiện mật khẩu';

  @override
  String get loginHidePassword => 'Ẩn mật khẩu';

  @override
  String get changePasswordTitle => 'Đổi mật khẩu';

  @override
  String get changePasswordOldLabel => 'Mật khẩu hiện tại';

  @override
  String get changePasswordOldHint => 'Nhập mật khẩu đang dùng';

  @override
  String get changePasswordNewLabel => 'Mật khẩu mới';

  @override
  String get changePasswordNewHint => 'Tối thiểu 6 ký tự';

  @override
  String get changePasswordConfirmLabel => 'Xác nhận mật khẩu mới';

  @override
  String get changePasswordConfirmHint => 'Nhập lại mật khẩu mới';

  @override
  String get changePasswordButton => 'Lưu thay đổi';

  @override
  String get changePasswordSuccess => 'Đổi mật khẩu thành công!';

  @override
  String get changePasswordMismatch => 'Mật khẩu xác nhận không khớp.';

  @override
  String get changePasswordEmpty =>
      'Vui lòng điền đầy đủ các thông tin mật khẩu.';

  @override
  String get forgotPasswordTitle => 'Quên mật khẩu';

  @override
  String get forgotPasswordInstruction =>
      'Nhập email tài khoản đã đăng ký để nhận mã OTP đặt lại mật khẩu.';

  @override
  String get forgotPasswordEmailLabel => 'Email tài khoản';

  @override
  String get forgotPasswordEmailHint => 'example@gmail.com';

  @override
  String get forgotPasswordSendOtp => 'Gửi mã xác thực';

  @override
  String get forgotPasswordEnterOtp => 'Nhập mã OTP';

  @override
  String get forgotPasswordVerify => 'Xác thực OTP';

  @override
  String get teacherNavAttendance => 'Điểm danh';

  @override
  String get teacherNavTimetable => 'Thời khóa biểu';

  @override
  String get teacherNavRecord => 'Nhật ký';

  @override
  String get teacherNavNotifications => 'Thông báo';

  @override
  String get teacherNavAccount => 'Tài khoản';

  @override
  String teacherGreeting(String name) {
    return 'Xin chào, Cô $name!';
  }

  @override
  String teacherClassTitle(String className) {
    return 'Lớp $className';
  }

  @override
  String teacherStudentCount(int count) {
    return '$count học sinh';
  }

  @override
  String get teacherAccountTitle => 'Tài khoản';

  @override
  String get teacherAccountSectionClass => 'Lớp phụ trách';

  @override
  String get teacherAccountSectionSettings => 'Cài đặt & hỗ trợ';

  @override
  String get teacherAccountAbout => 'Về KinderLog';

  @override
  String get teacherAccountQuickBug => 'Báo lỗi & góp ý';

  @override
  String get teacherLogoutConfirmTitle => 'Bạn có muốn đăng xuất không ?';

  @override
  String get teacherLogoutConfirmButton => 'Đăng xuất';

  @override
  String get attendanceTitle => 'Điểm danh hàng ngày';

  @override
  String get attendanceSummaryPresent => 'Có mặt';

  @override
  String get attendanceSummaryAbsent => 'Vắng mặt';

  @override
  String get attendanceSummaryLeave => 'Nghỉ phép';

  @override
  String get attendanceCheckIn => 'Điểm danh đến';

  @override
  String get attendanceCheckOut => 'Điểm danh về';

  @override
  String get attendanceSaveSuccess => 'Đã lưu kết quả điểm danh!';

  @override
  String get leaveRequestsTitle => 'Đơn xin nghỉ phép';

  @override
  String get leaveRequestsPending => 'Chờ duyệt';

  @override
  String get leaveRequestsApproved => 'Đã duyệt';

  @override
  String get leaveRequestsRejected => 'Từ chối';

  @override
  String get leaveRequestApprove => 'Duyệt đơn';

  @override
  String get leaveRequestReject => 'Từ chối';

  @override
  String leaveRequestReason(String reason) {
    return 'Lý do: $reason';
  }

  @override
  String get recordTitle => 'Nhật ký lớp học';

  @override
  String get recordMeal => 'Bữa ăn';

  @override
  String get recordNap => 'Giấc ngủ';

  @override
  String get recordHygiene => 'Vệ sinh';

  @override
  String get recordActivity => 'Hoạt động';

  @override
  String get recordHealth => 'Sức khỏe';

  @override
  String get recordVoiceButton => 'Ghi âm nhận xét';

  @override
  String get recordVoiceListening => 'Đang lắng nghe...';

  @override
  String get recordVoiceStop => 'Dừng ghi';

  @override
  String get recordVoiceProcessing => 'Đang chuyển đổi giọng nói...';

  @override
  String get parentNavDaily => 'Hôm nay';

  @override
  String get parentNavActivities => 'Hoạt động';

  @override
  String get parentNavRequests => 'Đơn từ';

  @override
  String get parentNavAccount => 'Tài khoản';

  @override
  String get parentChildProfile => 'Hồ sơ của bé';

  @override
  String get parentLeaveRequestButton => 'Gửi đơn xin nghỉ';

  @override
  String get parentHealthNote => 'Ghi chú sức khỏe';

  @override
  String get parentDailyReport => 'Báo cáo ngày của bé';

  @override
  String get parentPushNotification => 'Thông báo đẩy';

  @override
  String get parentPushSubtitle => 'Nhận thông báo khi có báo cáo mới';

  @override
  String parentAppVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get parentLogoutConfirmTitle => 'Bạn có muốn đăng xuất không ?';

  @override
  String get bugReportTitle => 'Góp ý & Cải thiện ứng dụng';

  @override
  String get bugReportNewButton => 'Góp ý cải thiện';

  @override
  String get bugReportAdminListButton => 'Quản lý ý kiến đóng góp';

  @override
  String get bugReportFormTitleLabel => 'Tiêu đề';

  @override
  String get bugReportFormTitleHint =>
      'Mô tả ngắn gọn góp ý hoặc vấn đề (tối đa 200 ký tự)';

  @override
  String get bugReportFormDescriptionLabel => 'Mô tả chi tiết';

  @override
  String get bugReportFormDescriptionHint =>
      'Chi tiết ý kiến đóng góp hoặc sự cố gặp phải (tối đa 4000 ký tự)';

  @override
  String get bugReportFormCategoryLabel => 'Danh mục';

  @override
  String get bugReportFormSeverityLabel => 'Mức độ';

  @override
  String get bugReportFormAttachmentsLabel => 'Ảnh đính kèm';

  @override
  String get bugReportFormAddAttachment => 'Thêm ảnh';

  @override
  String get bugReportFormRemoveAttachment => 'Xóa';

  @override
  String get bugReportFormSubmit => 'Gửi góp ý';

  @override
  String get bugReportFormSubmitting => 'Đang gửi...';

  @override
  String get bugReportFormSuccess =>
      'Đã gửi góp ý thành công. Cảm ơn đóng góp của bạn!';

  @override
  String get bugReportFormOfflineQueued =>
      'Đã lưu cục bộ. Sẽ tự gửi khi có mạng.';

  @override
  String get bugReportFormValidationEmpty => 'Vui lòng nhập tiêu đề và mô tả.';

  @override
  String get bugReportFormValidationTitleTooLong => 'Tiêu đề tối đa 200 ký tự.';

  @override
  String get bugReportFormValidationDescriptionTooLong =>
      'Mô tả tối đa 4000 ký tự.';

  @override
  String get bugReportDetailTitle => 'Chi tiết báo cáo lỗi';

  @override
  String get bugReportDetailSectionMetadata => 'Môi trường';

  @override
  String get bugReportDetailSectionAttachments => 'Ảnh đính kèm';

  @override
  String get bugReportDetailSectionHistory => 'Lịch sử trạng thái';

  @override
  String get bugReportDetailTapToZoom => 'Bấm để phóng to';

  @override
  String get bugReportAdminTitle => 'Quản lý báo cáo lỗi (Admin)';

  @override
  String get bugReportAdminFilter => 'Bộ lọc';

  @override
  String get bugReportAdminSearchHint => 'Tìm theo tiêu đề...';

  @override
  String get bugReportAdminEmpty =>
      'Không có báo cáo nào khớp bộ lọc hiện tại.';

  @override
  String get bugReportAdminUpdateStatus => 'Cập nhật trạng thái';

  @override
  String get bugReportAdminNewStatus => 'Trạng thái mới';

  @override
  String get bugReportAdminAssignee => 'Gán cho giáo viên';

  @override
  String get bugReportAdminComment => 'Ghi chú nội bộ';

  @override
  String get bugReportAdminCommentHint => 'Chỉ admin thấy (không bắt buộc)';

  @override
  String get bugReportAdminSave => 'Lưu';

  @override
  String get bugReportAdminSaving => 'Đang lưu...';

  @override
  String get bugReportAdminSaved => 'Đã cập nhật báo cáo.';

  @override
  String get bugReportStatusOpen => 'Mới';

  @override
  String get bugReportStatusInProgress => 'Đang xử lý';

  @override
  String get bugReportStatusResolved => 'Đã sửa';

  @override
  String get bugReportStatusClosed => 'Đã đóng';

  @override
  String get bugReportStatusWontFix => 'Không sửa';

  @override
  String get bugReportSeverityLow => 'Thấp';

  @override
  String get bugReportSeverityMedium => 'Trung bình';

  @override
  String get bugReportSeverityHigh => 'Cao';

  @override
  String get bugReportSeverityCritical => 'Nghiêm trọng';

  @override
  String get bugReportCategoryUi => 'Giao diện';

  @override
  String get bugReportCategoryPerformance => 'Hiệu năng';

  @override
  String get bugReportCategoryCrash => 'Crash';

  @override
  String get bugReportCategoryData => 'Dữ liệu';

  @override
  String get bugReportCategoryNotification => 'Thông báo';

  @override
  String get bugReportCategoryNetwork => 'Mạng';

  @override
  String get bugReportCategoryAuth => 'Xác thực';

  @override
  String get bugReportCategoryOther => 'Khác';

  @override
  String bugReportCommonAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ảnh',
      one: '1 ảnh',
      zero: 'Không có ảnh',
    );
    return '$_temp0';
  }

  @override
  String get bugReportCommonRetry => 'Thử lại';

  @override
  String get bugReportCommonCancel => 'Hủy';

  @override
  String get bugReportCommonClose => 'Đóng';
}
