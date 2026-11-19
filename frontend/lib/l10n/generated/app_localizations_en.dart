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
  String get navOverview => 'Overview';

  @override
  String get navClass => 'Class';

  @override
  String get navRecord => 'Record';

  @override
  String get navReports => 'Reports';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navAccount => 'Account';

  @override
  String get navTimetable => 'Timetable';

  @override
  String get navAttendance => 'Attendance';

  @override
  String get accountSettings => 'Settings';

  @override
  String get accountSupport => 'Support';

  @override
  String get accountSettingsAndSupport => 'Settings & Support';

  @override
  String get accountChangePassword => 'Change Password';

  @override
  String get accountLanguage => 'Ngôn ngữ / Language';

  @override
  String get accountBugReport => 'Bug Report & Feedback';

  @override
  String get accountAbout => 'About KinderLog';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountAssignedClass => 'Assigned Class';

  @override
  String get accountStudents => 'Students';

  @override
  String get accountChildProfile => 'Child Profile';

  @override
  String get accountChildParent => 'Child\'s Parent';

  @override
  String get accountTeacherInCharge => 'Teacher in Charge';

  @override
  String get accountPhoneNumber => 'Phone Number';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountAddress => 'Address';

  @override
  String get accountWeight => 'Weight';

  @override
  String get accountHeight => 'Height';

  @override
  String get accountBloodType => 'Blood Type';

  @override
  String get accountAllergies => 'Allergies';

  @override
  String get accountHealthNotes => 'Health Notes';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to log out?';

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
  String get teacherAccountPreferences => 'Preferences';

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

  @override
  String get parentGreetingGoodMorning => 'Good morning,';

  @override
  String get parentTodayReport => 'Today\'s Report';

  @override
  String get parentNoReportToday => 'No report for today yet.';

  @override
  String get parentNoAttendanceToday => 'No attendance update for today';

  @override
  String parentAllergyPrefix(String allergy) {
    return 'Allergy: $allergy';
  }

  @override
  String parentTeacherNoteTitle(String teacherName) {
    return 'Note from $teacherName';
  }

  @override
  String get parentTimetableShortcut => 'Timetable';

  @override
  String get parentRequestsShortcut => 'Leave · Late';

  @override
  String parentUnreadReportsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread reports',
      one: '1 unread report',
      zero: 'No unread reports',
    );
    return '$_temp0';
  }

  @override
  String get parentLoadDataError => 'Unable to load parent data.';

  @override
  String get parentOpenReportError =>
      'Unable to open this report. Please try again later.';

  @override
  String get parentNoDataForDay => 'No recorded data for this day.';

  @override
  String get parentDailyReportTitle => 'Daily Report';

  @override
  String get recordMealItem => 'Meals';

  @override
  String get recordNapItem => 'Sleep';

  @override
  String get recordActivityItem => 'Activities';

  @override
  String get commonNotUpdated => 'Not updated';

  @override
  String get commonAll => 'All';

  @override
  String get parentSectionFamily => 'Family';

  @override
  String get parentContactInfo => 'Contact Information';

  @override
  String get parentChildHealthProfile => 'Child Details · Health Profile';

  @override
  String get parentAllergyCareNotes => 'Allergies & Care Notes';

  @override
  String get parentSectionPreferences => 'Preferences';

  @override
  String get parentPushEnabled => 'Enabled on device';

  @override
  String get parentPushDisabled => 'Disabled on device';

  @override
  String parentFamilySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enrolled children',
      one: '1 enrolled child',
    );
    return 'Family has $_temp0';
  }

  @override
  String get parentSelectChild => 'Select Child';

  @override
  String get parentSelected => 'Selected';

  @override
  String get parentDateOfBirth => 'Date of Birth';

  @override
  String parentNickname(String nickname) {
    return 'Nickname: $nickname';
  }

  @override
  String get parentViewDetail => 'View ›';

  @override
  String get parentReadReport => 'Read report ›';

  @override
  String get parentCopyPhoneTooltip => 'Copy phone number';

  @override
  String get parentCopiedPhoneSnackbar => 'Phone number copied';

  @override
  String parentAccountChildPrefix(String childName) {
    return 'Parent account of $childName';
  }

  @override
  String get parentFullNameLabel => 'Full Name';

  @override
  String get parentRelationshipLabel => 'Role / Relationship';

  @override
  String get parentNoAllergyRecorded => 'No allergies recorded';

  @override
  String get parentHasAllergy => 'Has allergies';

  @override
  String get parentNoAllergy => 'No allergies';

  @override
  String get parentAllergyNotDeclared => 'Not declared';

  @override
  String parentJourneyDaysText(int days) {
    return '$days days journeying with KinderLog';
  }

  @override
  String get parentEditInfo => 'Edit Information';

  @override
  String get parentEditContactInfo => 'Edit Contact Information';

  @override
  String get parentHealthChangeConfirmTitle => 'Change allergy information?';

  @override
  String get parentHealthChangeConfirmMessage =>
      'Existing allergy information will be overwritten after saving.';

  @override
  String get parentHealthContinueEditing => 'Continue Editing';

  @override
  String get parentHealthDiscardTitle => 'Discard changes?';

  @override
  String get parentHealthDiscardMessage =>
      'Changes you just made will not be saved.';

  @override
  String get parentHealthDiscardAction => 'Discard';

  @override
  String get parentHealthUpdateSuccess => 'Health information updated';

  @override
  String get parentHealthLoadError => 'Unable to load health profile.';

  @override
  String get parentHealthAllergyStatus => 'Allergy Status';

  @override
  String get parentHealthCareNotes => 'Care Notes';

  @override
  String get teacherGreetingGoodMorning => 'Good morning,';

  @override
  String get teacherAttentionTitle => 'Needs Attention';

  @override
  String get teacherNoAttentionToday => 'No special notes today.';

  @override
  String get teacherRecordBannerTitle => 'Record the day\nfor children';

  @override
  String get teacherRecordBannerSubtitle =>
      'Meals, nap, activities and care notes.';

  @override
  String get teacherStartReport => 'Start Daily Report';

  @override
  String get teacherTodayAttendance => 'Today\'s Attendance';

  @override
  String get teacherReportIncident => 'Incident';

  @override
  String get teacherSendToParents => 'Send to Parents';

  @override
  String get teacherSearchChildHint => 'Search child name...';

  @override
  String get teacherNoChildrenFound => 'No matching children found';

  @override
  String get teacherOverviewLoadError => 'Unable to load overview · Retry';

  @override
  String get teacherNoSchoolInfo => 'School info unavailable';

  @override
  String get attendanceSaveButton => 'Save Attendance';

  @override
  String get attendanceDiscardConfirmTitle => 'Discard attendance changes?';

  @override
  String get attendanceDiscardConfirmMessage =>
      'Changes on attendance cards will not be saved.';

  @override
  String get attendanceContinue => 'Continue Attendance';

  @override
  String get attendanceDiscardAction => 'Discard';

  @override
  String get dayMonday => 'Monday';

  @override
  String get dayTuesday => 'Tuesday';

  @override
  String get dayWednesday => 'Wednesday';

  @override
  String get dayThursday => 'Thursday';

  @override
  String get dayFriday => 'Friday';

  @override
  String get daySaturday => 'Saturday';

  @override
  String get daySunday => 'Sunday';

  @override
  String get dayShortMon => 'Mon';

  @override
  String get dayShortTue => 'Tue';

  @override
  String get dayShortWed => 'Wed';

  @override
  String get dayShortThu => 'Thu';

  @override
  String get dayShortFri => 'Fri';

  @override
  String get dayShortSat => 'Sat';

  @override
  String get dayShortSun => 'Sun';

  @override
  String get timetableMorning => 'Morning';

  @override
  String get timetableAfternoon => 'Afternoon';

  @override
  String get timetableEmpty => 'No classes scheduled';

  @override
  String get parentRequestsTitle => 'Leave / Late Requests';

  @override
  String get parentRequestsNew => 'New Request';

  @override
  String get leaveRequestsCancelled => 'Cancelled';

  @override
  String get leaveTypeAbsent => 'Absent';

  @override
  String get leaveTypeLate => 'Late Arrival';

  @override
  String get parentRequestsFormTitle => 'Create Leave / Late Request';

  @override
  String get parentRequestsTypeLabel => 'Request Type';

  @override
  String get parentRequestsFromDate => 'From Date';

  @override
  String get parentRequestsToDate => 'To Date';

  @override
  String get parentRequestsLateDate => 'Late Date';

  @override
  String get parentRequestsExpectedTime => 'Expected Arrival Time';

  @override
  String get parentRequestsReasonLabel => 'Reason';

  @override
  String get parentRequestsSubmit => 'Submit Request';

  @override
  String get aboutAppTagline => 'Smart Kindergarten Communication & Reporting';

  @override
  String get aboutAppDescription =>
      'Comprehensive administrative & digital connection between School · Teachers · Parents.';

  @override
  String get voiceChatInputHint => 'Type a reply...';

  @override
  String get voiceChatRecording => 'Recording...';

  @override
  String get voiceChatSendReply => 'Send reply';
}
