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
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonError => 'An error occurred. Please try again later.';

  @override
  String get language => 'Language';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSelectTitle => 'Select Display Language';

  @override
  String get loginWelcomeBack => 'Welcome back!';

  @override
  String get loginTagline =>
      'Preserving every precious moment of your child\'s growth together.';

  @override
  String get loginUsernameLabel => 'USERNAME';

  @override
  String get loginUsernameHint => 'Enter username or Gmail';

  @override
  String get loginPasswordLabel => 'PASSWORD';

  @override
  String get loginPasswordHint => 'Enter password';

  @override
  String get loginRememberPassword => 'Remember password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Sign In';

  @override
  String get loginFooter => 'Connecting classrooms · Peace of mind every day';

  @override
  String get loginErrorEmpty =>
      'Please enter both username/Gmail and password.';

  @override
  String get loginErrorFailed =>
      'Login failed. Please check your internet connection or try again later.';

  @override
  String get loginErrorAdminWebOnly =>
      'Admin accounts are only supported on the Web version. Please visit the admin portal on a desktop browser.';

  @override
  String get loginRememberError =>
      'Unable to read saved credentials. You can still sign in.';

  @override
  String get loginRememberClearError =>
      'Failed to clear saved credentials. Please try again.';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get changePasswordOldLabel => 'Current password';

  @override
  String get changePasswordOldHint => 'Enter current password';

  @override
  String get changePasswordNewLabel => 'New password';

  @override
  String get changePasswordNewHint => 'At least 6 characters';

  @override
  String get changePasswordConfirmLabel => 'Confirm new password';

  @override
  String get changePasswordConfirmHint => 'Re-enter new password';

  @override
  String get changePasswordButton => 'Save Changes';

  @override
  String get changePasswordSuccess => 'Password changed successfully!';

  @override
  String get changePasswordMismatch => 'Passwords do not match.';

  @override
  String get changePasswordEmpty => 'Please fill in all password fields.';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordInstruction =>
      'Enter your registered email address to receive an OTP code to reset your password.';

  @override
  String get forgotPasswordEmailLabel => 'Account Email';

  @override
  String get forgotPasswordEmailHint => 'example@gmail.com';

  @override
  String get forgotPasswordSendOtp => 'Send Verification Code';

  @override
  String get forgotPasswordEnterOtp => 'Enter OTP Code';

  @override
  String get forgotPasswordVerify => 'Verify OTP';

  @override
  String get teacherNavAttendance => 'Attendance';

  @override
  String get teacherNavTimetable => 'Timetable';

  @override
  String get teacherNavRecord => 'Daily Log';

  @override
  String get teacherNavNotifications => 'Notifications';

  @override
  String get teacherNavAccount => 'Account';

  @override
  String teacherGreeting(String name) {
    return 'Hello, Teacher $name!';
  }

  @override
  String teacherClassTitle(String className) {
    return 'Class $className';
  }

  @override
  String teacherStudentCount(int count) {
    return '$count students';
  }

  @override
  String get teacherAccountTitle => 'Account';

  @override
  String get teacherAccountSectionClass => 'Assigned Class';

  @override
  String get teacherAccountSectionSettings => 'Settings & Support';

  @override
  String get teacherAccountAbout => 'About KinderLog';

  @override
  String get teacherAccountQuickBug => 'Bug Report & Feedback';

  @override
  String get teacherLogoutConfirmTitle => 'Do you want to log out?';

  @override
  String get teacherLogoutConfirmButton => 'Log out';

  @override
  String get attendanceTitle => 'Daily Attendance';

  @override
  String get attendanceSummaryPresent => 'Present';

  @override
  String get attendanceSummaryAbsent => 'Absent';

  @override
  String get attendanceSummaryLeave => 'On Leave';

  @override
  String get attendanceCheckIn => 'Morning Check-in';

  @override
  String get attendanceCheckOut => 'Afternoon Check-out';

  @override
  String get attendanceSaveSuccess => 'Attendance saved successfully!';

  @override
  String get leaveRequestsTitle => 'Leave Requests';

  @override
  String get leaveRequestsPending => 'Pending';

  @override
  String get leaveRequestsApproved => 'Approved';

  @override
  String get leaveRequestsRejected => 'Rejected';

  @override
  String get leaveRequestApprove => 'Approve';

  @override
  String get leaveRequestReject => 'Reject';

  @override
  String leaveRequestReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get recordTitle => 'Class Daily Log';

  @override
  String get recordMeal => 'Meals';

  @override
  String get recordNap => 'Nap';

  @override
  String get recordHygiene => 'Hygiene';

  @override
  String get recordActivity => 'Activities';

  @override
  String get recordHealth => 'Health';

  @override
  String get recordVoiceButton => 'Record Voice Note';

  @override
  String get recordVoiceListening => 'Listening...';

  @override
  String get recordVoiceStop => 'Stop Recording';

  @override
  String get recordVoiceProcessing => 'Processing voice note...';

  @override
  String get parentNavDaily => 'Today';

  @override
  String get parentNavActivities => 'Activities';

  @override
  String get parentNavRequests => 'Requests';

  @override
  String get parentNavAccount => 'Account';

  @override
  String get parentChildProfile => 'Child Profile';

  @override
  String get parentLeaveRequestButton => 'Submit Leave Request';

  @override
  String get parentHealthNote => 'Health Notes';

  @override
  String get parentDailyReport => 'Child\'s Daily Report';

  @override
  String get parentPushNotification => 'Push Notifications';

  @override
  String get parentPushSubtitle =>
      'Get notified when new daily reports are posted';

  @override
  String parentAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get parentLogoutConfirmTitle => 'Do you want to log out?';

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

  @override
  String get voiceChatRecordTooltip => 'Send voice message';

  @override
  String get voiceChatCancelTooltip => 'Cancel recording';

  @override
  String get voiceChatSendTooltip => 'Send voice message now';

  @override
  String get voiceChatPermissionError =>
      'App needs microphone permission to record voice messages.';

  @override
  String get voiceChatStartError => 'Cannot start recording. Please try again.';

  @override
  String get voiceChatSendError =>
      'Error sending voice recording. Please try again.';

  @override
  String get voiceChatLoadError => 'Failed to load audio';

  @override
  String get voiceChatDefaultContent => 'Voice message';
}
