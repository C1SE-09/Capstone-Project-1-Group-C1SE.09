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
  String get bugReportTitle => 'Báo cáo lỗi';

  @override
  String get bugReportNewButton => 'Báo cáo lỗi';

  @override
  String get bugReportAdminListButton => 'Quản lý báo cáo lỗi';

  @override
  String get bugReportFormTitleLabel => 'Tiêu đề';

  @override
  String get bugReportFormTitleHint =>
      'Mô tả ngắn gọn vấn đề (tối đa 200 ký tự)';

  @override
  String get bugReportFormDescriptionLabel => 'Mô tả chi tiết';

  @override
  String get bugReportFormDescriptionHint =>
      'Các bước tái hiện, bạn kỳ vọng gì, thực tế xảy ra gì (tối đa 4000 ký tự)';

  @override
  String get bugReportFormCategoryLabel => 'Loại lỗi';

  @override
  String get bugReportFormSeverityLabel => 'Mức độ';

  @override
  String get bugReportFormAttachmentsLabel => 'Ảnh đính kèm';

  @override
  String get bugReportFormAddAttachment => 'Thêm ảnh';

  @override
  String get bugReportFormRemoveAttachment => 'Xóa';

  @override
  String get bugReportFormSubmit => 'Gửi báo cáo';

  @override
  String get bugReportFormSubmitting => 'Đang gửi...';

  @override
  String get bugReportFormSuccess => 'Đã gửi báo cáo. Admin sẽ xem xét sớm.';

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
