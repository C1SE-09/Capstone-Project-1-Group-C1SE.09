// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KinderLog';

  @override
  String get bugReportTitle => 'Report a Bug';

  @override
  String get bugReportNewButton => 'Report a bug';

  @override
  String get bugReportAdminListButton => 'Manage bug reports';

  @override
  String get bugReportFormTitleLabel => 'Title';

  @override
  String get bugReportFormTitleHint =>
      'Briefly describe the issue (max 200 chars)';

  @override
  String get bugReportFormDescriptionLabel => 'Description';

  @override
  String get bugReportFormDescriptionHint =>
      'Steps to reproduce, what you expected, what happened (max 4000 chars)';

  @override
  String get bugReportFormCategoryLabel => 'Category';

  @override
  String get bugReportFormSeverityLabel => 'Severity';

  @override
  String get bugReportFormAttachmentsLabel => 'Screenshots';

  @override
  String get bugReportFormAddAttachment => 'Add image';

  @override
  String get bugReportFormRemoveAttachment => 'Remove';

  @override
  String get bugReportFormSubmit => 'Submit';

  @override
  String get bugReportFormSubmitting => 'Submitting...';

  @override
  String get bugReportFormSuccess =>
      'Bug report submitted. Admin will review soon.';

  @override
  String get bugReportFormOfflineQueued =>
      'Saved locally. Will be sent when you are back online.';

  @override
  String get bugReportFormValidationEmpty =>
      'Please fill in title and description.';

  @override
  String get bugReportFormValidationTitleTooLong =>
      'Title must be at most 200 characters.';

  @override
  String get bugReportFormValidationDescriptionTooLong =>
      'Description must be at most 4000 characters.';

  @override
  String get bugReportDetailTitle => 'Bug Report Detail';

  @override
  String get bugReportDetailSectionMetadata => 'Environment';

  @override
  String get bugReportDetailSectionAttachments => 'Attachments';

  @override
  String get bugReportDetailSectionHistory => 'Status History';

  @override
  String get bugReportDetailTapToZoom => 'Tap to zoom';

  @override
  String get bugReportAdminTitle => 'Bug Reports (Admin)';

  @override
  String get bugReportAdminFilter => 'Filters';

  @override
  String get bugReportAdminSearchHint => 'Search by title...';

  @override
  String get bugReportAdminEmpty => 'No reports match the current filter.';

  @override
  String get bugReportAdminUpdateStatus => 'Update status';

  @override
  String get bugReportAdminNewStatus => 'New status';

  @override
  String get bugReportAdminAssignee => 'Assign to teacher';

  @override
  String get bugReportAdminComment => 'Internal comment';

  @override
  String get bugReportAdminCommentHint => 'Visible to admin only (optional)';

  @override
  String get bugReportAdminSave => 'Save';

  @override
  String get bugReportAdminSaving => 'Saving...';

  @override
  String get bugReportAdminSaved => 'Report updated.';

  @override
  String get bugReportStatusOpen => 'Open';

  @override
  String get bugReportStatusInProgress => 'In progress';

  @override
  String get bugReportStatusResolved => 'Resolved';

  @override
  String get bugReportStatusClosed => 'Closed';

  @override
  String get bugReportStatusWontFix => 'Won\'t fix';

  @override
  String get bugReportSeverityLow => 'Low';

  @override
  String get bugReportSeverityMedium => 'Medium';

  @override
  String get bugReportSeverityHigh => 'High';

  @override
  String get bugReportSeverityCritical => 'Critical';

  @override
  String get bugReportCategoryUi => 'UI';

  @override
  String get bugReportCategoryPerformance => 'Performance';

  @override
  String get bugReportCategoryCrash => 'Crash';

  @override
  String get bugReportCategoryData => 'Data';

  @override
  String get bugReportCategoryNotification => 'Notification';

  @override
  String get bugReportCategoryNetwork => 'Network';

  @override
  String get bugReportCategoryAuth => 'Authentication';

  @override
  String get bugReportCategoryOther => 'Other';

  @override
  String bugReportCommonAttachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
      zero: 'No attachments',
    );
    return '$_temp0';
  }

  @override
  String get bugReportCommonRetry => 'Retry';

  @override
  String get bugReportCommonCancel => 'Cancel';

  @override
  String get bugReportCommonClose => 'Close';
}
