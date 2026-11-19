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
  String get changePasswordMismatch => 'Password confirmation does not match.';

  @override
  String get changePasswordEmpty => 'Please fill in all password fields.';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordInstruction =>
      'Enter your registered email address to receive an OTP code to reset your password.';

  @override
  String get forgotPasswordEmailLabel => 'Login email';

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

  @override
  String get authRememberSnackBar =>
      'Logged in, but could not save your remember choice. Please try again on this device; web requires HTTPS or localhost.';

  @override
  String get forgotPasswordSubtitle => 'Reset password via email';

  @override
  String get forgotPasswordStep1 => 'Step 1/3 · Enter email';

  @override
  String get forgotPasswordStep1Desc =>
      'Enter your registered email. KinderLog will send a confirmation code for you to reset your password.';

  @override
  String get forgotPasswordStep2 => 'Verify OTP Code';

  @override
  String get forgotPasswordStep3 => 'Set New Password';

  @override
  String get forgotPasswordEmailInvalid =>
      'Please enter a valid email address.';

  @override
  String get forgotPasswordSendCode => 'Send confirmation code';

  @override
  String get forgotPasswordSendingCode => 'Sending code...';

  @override
  String get forgotPasswordResendCode => 'Resend code';

  @override
  String forgotPasswordResendAfter(Object seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get forgotPasswordOtpLengthError =>
      'Please enter all 6 digits of the verification code.';

  @override
  String get forgotPasswordOtpSuccess =>
      'Verification code accepted! Please create a new password.';

  @override
  String get forgotPasswordOtpInvalid =>
      'Invalid or expired verification code. Please check again.';

  @override
  String get forgotPasswordPasswordMinLength =>
      'New password must have at least 6 characters.';

  @override
  String get forgotPasswordPasswordMismatch =>
      'Password confirmation does not match.';

  @override
  String get forgotPasswordSuccessTitle => 'Success';

  @override
  String get forgotPasswordSuccessDesc =>
      'Your password has been changed successfully. Please log in with your new password.';

  @override
  String get forgotPasswordLoginNow => 'LOG IN NOW';

  @override
  String get forgotPasswordBackToLogin => 'Back to login';

  @override
  String get forgotPasswordNewPasswordLabel => 'New password';

  @override
  String get forgotPasswordNewPasswordHint => 'Enter new password';

  @override
  String get forgotPasswordConfirmPasswordLabel => 'Confirm new password';

  @override
  String get forgotPasswordConfirmPasswordHint => 'Re-enter new password';

  @override
  String get forgotPasswordUpdateButton => 'UPDATE PASSWORD';

  @override
  String forgotPasswordCheckEmail(Object email) {
    return 'Check email $email';
  }

  @override
  String get forgotPasswordOtpHelp =>
      '6-digit verification code (Valid for 5 minutes)';

  @override
  String get forgotPasswordChangeEmail => 'Use another email';

  @override
  String get forgotPasswordConfirmOtp => 'CONFIRM OTP';

  @override
  String get forgotPasswordErrorSendFailed =>
      'Failed to send reset password request. Please check your internet connection or try again later.';

  @override
  String get forgotPasswordErrorResendFailed =>
      'Cannot resend verification code right now. Please try again in a few minutes.';

  @override
  String get forgotPasswordErrorResetFailed =>
      'Password reset was unsuccessful. Please try again in a few minutes.';

  @override
  String get forgotPasswordSpamHelp =>
      'Didn\'t receive the code? Check your spam folder, or wait 60 seconds to resend.';

  @override
  String get changePasswordSubtitle => 'Protect your KinderLog account';

  @override
  String get changePasswordCurrentLabel => 'Current password';

  @override
  String get changePasswordCurrentEmpty =>
      'Please enter your current password.';

  @override
  String get changePasswordNewEmpty => 'Please enter your new password.';

  @override
  String get changePasswordNewMinLength =>
      'New password must have at least 6 characters.';

  @override
  String get changePasswordConfirmEmpty => 'Please confirm your new password.';

  @override
  String get changePasswordSameAsCurrent =>
      'New password cannot be the same as current password.';

  @override
  String get changePasswordFailed =>
      'Cannot change password right now. Please try again in a few minutes.';

  @override
  String get changePasswordRequirements => 'New password requirements';

  @override
  String get changePasswordReqMinLength => '· Minimum 6 characters';

  @override
  String get changePasswordLogoutOtherDevices => 'Log out of other devices';

  @override
  String get changePasswordLogoutOtherDevicesDesc =>
      'Other devices will need to log in again.';

  @override
  String get changePasswordSaveButton => 'Save changes';

  @override
  String get noAssignmentClassIcon => 'Class group icon';

  @override
  String get relationFather => 'Father';

  @override
  String get relationMother => 'Mother';

  @override
  String get relationGrandpa => 'Grandfather';

  @override
  String get relationGrandma => 'Grandmother';

  @override
  String get relationGuardian => 'Guardian';

  @override
  String get relationTitle => 'Relationship with child';

  @override
  String get relationSelectTitle => 'Select relationship';

  @override
  String get genderBoy => 'Boy (Male)';

  @override
  String get genderGirl => 'Girl (Female)';

  @override
  String get genderOther => 'Other';

  @override
  String get genderLabel => 'Gender';

  @override
  String get childInfoTitle => 'Child Information';

  @override
  String get childEditInfo => 'Edit child info';

  @override
  String get childNotUpdated => 'Not updated';

  @override
  String get childSelectDob => 'Select child\'s date of birth';

  @override
  String get healthAllergyYes => 'Has allergies';

  @override
  String get healthAllergyNone => 'No recorded allergies';

  @override
  String get healthAllergyUndeclared => 'Allergies not declared';

  @override
  String get healthUndeclared => 'Not declared';

  @override
  String get healthProfileSaveFailed => 'Could not save changes';

  @override
  String get healthProfileSaveFailedDesc =>
      'Please check your network and try again. Your input has been preserved.';

  @override
  String get requestExpectedArrival => 'Expected arrival time';

  @override
  String get requestFromDate => 'From date';

  @override
  String get requestToDate => 'To date';

  @override
  String get requestLateDate => 'Late arrival date';

  @override
  String get requestSelectDate => 'Select date';

  @override
  String get requestType => 'Request type';

  @override
  String get requestDiscardTitle => 'Discard changes?';

  @override
  String get requestDiscardDesc =>
      'Unsubmitted request content will not be saved.';

  @override
  String get requestKeepEditing => 'Keep editing';

  @override
  String get requestDiscardConfirm => 'Discard changes';

  @override
  String get requestNoClassWarning =>
      'No class information assigned yet. Please contact the school.';

  @override
  String get requestDateRangeHelp =>
      'Select future dates and times; max 366 days per request.';

  @override
  String get requestMealWarningTitle => 'Submitting after 7:30 AM';

  @override
  String get requestMealWarningConfirm => 'Agree & Submit';

  @override
  String get requestSaveFailed =>
      'Failed to submit request. Content is kept for you to retry.';

  @override
  String get requestFetchFailed => 'Unable to load requests. Please try again.';

  @override
  String get requestLoadingList => 'Loading requests...';

  @override
  String get requestEmptyList => 'No requests yet';

  @override
  String get requestLoadMore => 'Load more';

  @override
  String get requestCreateNew => 'CREATE NEW REQUEST';

  @override
  String get requestSubmittedSuccess => 'Request submitted successfully';

  @override
  String get requestStatus => 'Status';

  @override
  String get requestPendingNote =>
      'Request submitted, pending review. You will be notified when teacher approves.';

  @override
  String get requestHistoryNote =>
      'Request submitted. View history to track latest review status.';

  @override
  String get requestViewMyRequests => 'VIEW MY REQUESTS';

  @override
  String get requestBackHome => 'Back to Home';

  @override
  String get requestTeacherApproved => 'Teacher approved';

  @override
  String get requestTeacherRejected => 'Teacher rejected';

  @override
  String get requestParentCancelled => 'Parent cancelled request';

  @override
  String get requestTimeLabel => 'Time';

  @override
  String get contactEditTitle => 'Edit Contact Information';

  @override
  String get contactEditDesc =>
      'Update contact info for school communication when needed.';

  @override
  String get contactPhoneLabel => 'Phone number *';

  @override
  String get contactPhoneHint => '10 digits, starting with 0';

  @override
  String get contactEmailInvalid =>
      'Invalid email address. Please check again.';

  @override
  String get contactSaveSuccess => 'Parent info saved successfully';

  @override
  String get contactSaveFailed =>
      'Failed to save information, please try again.';

  @override
  String get notificationsAll => 'All';

  @override
  String get notificationsEmpty => 'No notifications.';

  @override
  String get notificationsReport => 'Reports';

  @override
  String get notificationsReportEmpty => 'No new reports.';

  @override
  String get notificationsHealthEmpty => 'No health notifications.';

  @override
  String get notificationsLeaveEmpty => 'No new leave requests.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsNew => 'New';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String get commonAllChildren => 'All children';

  @override
  String get commonClassroom => 'CLASSROOM';

  @override
  String get commonClass => 'CLASS';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonSend => 'Send';

  @override
  String get commonSending => 'Sending…';

  @override
  String get commonSent => 'Sent';

  @override
  String get commonRead => 'Read';

  @override
  String get commonDraft => 'Draft';

  @override
  String get commonNew => 'New';

  @override
  String get commonEarlier => 'Earlier';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonMorning => 'Morning';

  @override
  String get commonAfternoon => 'Afternoon';

  @override
  String get commonOther => 'Other';

  @override
  String get commonNone => 'None';

  @override
  String get commonEmpty => 'None';

  @override
  String get entityParent => 'Parent';

  @override
  String get entityTeacher => 'Teacher';

  @override
  String get entityHeadTeacher => 'Head teacher';

  @override
  String get entityStudent => 'Student';

  @override
  String get entityChildren => 'Children';

  @override
  String get entityChild => 'Child';

  @override
  String get entityClass => 'Class';

  @override
  String get entityClassroom => 'Classroom';

  @override
  String get entitySchool => 'School';

  @override
  String get entityPhoneNumber => 'Phone number';

  @override
  String get entityEmail => 'Email';

  @override
  String get entityDateOfBirth => 'Date of birth';

  @override
  String get entityGender => 'Gender';

  @override
  String get entityAddress => 'Address';

  @override
  String get attendanceListTitle => 'Attendance List';

  @override
  String get attendanceStatusArrived => 'Arrived';

  @override
  String get attendanceStatusAbsent => 'Absent';

  @override
  String get attendanceStatusExcused => 'Excused';

  @override
  String get attendanceStatusLate => 'Late';

  @override
  String get attendanceStatusOnTime => 'On time';

  @override
  String get attendanceSendAbsentAlert => 'Send absent notification';

  @override
  String get attendanceSendAbsentAlertTitle => 'Send absent notification?';

  @override
  String get attendanceSendAlert => 'Send notification';

  @override
  String get attendanceClearSearch => 'Clear search';

  @override
  String get attendanceNoMatchingStudent => 'No matching students found.';

  @override
  String get attendanceSaveFailed =>
      'Failed to save attendance. Please try again later.';

  @override
  String get attendanceNoDataForDay => 'No attendance data for this day.';

  @override
  String get attendanceLoadFailed =>
      'Failed to load attendance for the selected date.';

  @override
  String get attendanceViewClassRequests => 'View class leave requests';

  @override
  String get attendanceUpdated => 'Updated';

  @override
  String get attendancePrevDay => 'Previous day';

  @override
  String get attendanceNextDay => 'Next day';

  @override
  String get timetableTitle => 'Timetable';

  @override
  String get timetableInProgress => 'In progress';

  @override
  String get timetableUpcoming => 'Next';

  @override
  String get timetableDayView => 'Day';

  @override
  String get timetableWeekView => 'Week';

  @override
  String get timetableNoActivities => 'No activities yet';

  @override
  String get timetableTimeConflict => 'Time slot conflict';

  @override
  String get timetableAddActivity => 'Add activity';

  @override
  String get timetableEditActivity => 'Edit activity';

  @override
  String get timetableActivityAdded => 'Activity added';

  @override
  String get timetableActivityUpdated => 'Activity updated';

  @override
  String get timetableActivityDeleted => 'Activity deleted';

  @override
  String get timetableSaveFailed =>
      'Failed to save activity. Please try again.';

  @override
  String get timetableDeleteFailed =>
      'Failed to delete activity. Please try again.';

  @override
  String get timetableNameRequired => 'Please enter activity name.';

  @override
  String get timetableSubjectRequired => 'Please select a subject / activity.';

  @override
  String get timetableSlotRequired => 'Please select a time slot.';

  @override
  String get timetableTimeSlot => 'Time slot';

  @override
  String get timetableSubjectOrActivity => 'Subject / Activity';

  @override
  String get timetableRoomOptional => 'Room (optional)';

  @override
  String get timetableMeals => 'Meals';

  @override
  String get timetableCreativeActivities => 'Creative activities';

  @override
  String get timetableOutdoorActivities => 'Outdoor activities';

  @override
  String get timetableSleep => 'Sleep';

  @override
  String get timetableHealth => 'Health';

  @override
  String get subjectMath => 'Math';

  @override
  String get subjectLiterature => 'Literature';

  @override
  String get subjectForeignLanguage => 'Foreign Language';

  @override
  String get subjectMusic => 'Music';

  @override
  String get subjectArt => 'Art';

  @override
  String get subjectPE => 'Physical Education';

  @override
  String get incidentReport => 'Report incident';

  @override
  String get incidentNotifyParentsSchool => 'Notify parents and school';

  @override
  String get incidentType => 'Incident type';

  @override
  String get incidentDescription => 'Incident description';

  @override
  String get incidentSendEmergencyAlert => 'Send emergency alert';

  @override
  String get incidentCallParent => 'Call parent';

  @override
  String get incidentCallParentNow => 'Call parent now';

  @override
  String get incidentHighFever => 'High fever';

  @override
  String get incidentFallAccident => 'Accident / Fall';

  @override
  String get incidentAcuteAllergy => 'Acute allergy';

  @override
  String get incidentStudentRequired => 'Please select a student.';

  @override
  String get incidentTempInvalid =>
      'Temperature must be between 34°C and 44°C.';

  @override
  String get incidentNoValidPhone =>
      'No valid phone number in emergency contacts.';

  @override
  String get incidentSelectParentToCall => 'Select parent to call';

  @override
  String get incidentTempOptional => 'Temperature (optional)';

  @override
  String get incidentRecipients => 'Alert recipients';

  @override
  String get incidentReloadContacts => 'Reload contacts';

  @override
  String get incidentRecordSaved => 'Incident record saved';

  @override
  String get incidentSelectStudent => 'Select student';

  @override
  String get incidentSelectStudentEllipsis => 'Select student...';

  @override
  String get incidentSearchStudentHint => 'Search by child name or nickname...';

  @override
  String get incidentChangeChild => 'Change child';

  @override
  String get sttTranscribing => 'Transcribing speech to text…';

  @override
  String get sttFailed => 'Speech recognition failed';

  @override
  String get sttNoText => 'No text content yet';

  @override
  String get sttDeleteRecording => 'Delete this recording';

  @override
  String get sttCollapse => 'Collapse';

  @override
  String get sttExpand => 'Expand spoken content';

  @override
  String get sttSpokenContent => 'Spoken content';

  @override
  String get sttSegmentContent => 'Segment content';

  @override
  String get sttAnalyzedText => 'Analyzed text';

  @override
  String get sttEditAndReanalyze => 'Edit & Reanalyze';

  @override
  String get sttOriginalAudio => 'Original recording';

  @override
  String get sttAudioProgress => 'Recording playback progress';

  @override
  String get sttSubmittedSuccess => 'Sent successfully.';

  @override
  String get sttNoNeedToReenter =>
      'Nothing more to enter. Reports have been sent to parents.';

  @override
  String get sttListenAgain => 'Listen to recording again';

  @override
  String get sttBackToClassOverview => 'Back to class overview';

  @override
  String get sttEditReport => 'Edit report';

  @override
  String get sttDurationMinutes => 'Duration (minutes)';

  @override
  String get sttParentReportsLabel => 'communication books for parents';

  @override
  String get sttHealthRecordsLabel => 'entries in health record';

  @override
  String get sttRecordForChild => 'Record for child';

  @override
  String get sttComposeReport => 'Compose report';

  @override
  String get sttDailyObservation => 'Daily observation';

  @override
  String get sttNotRecorded => 'Not recorded';

  @override
  String get sttRecorded => 'Recorded';

  @override
  String get leaveReviewRejectTitle => 'Reject request';

  @override
  String get leaveReviewRejectReasonLabel => 'Rejection reason *';

  @override
  String get leaveReviewRejectReasonHint =>
      'Enter specific reason so parents understand';

  @override
  String get leaveReviewRejectReasonHelp =>
      'Reason required (2–500 chars). Parents will see this in request details.';

  @override
  String get leaveReviewRejectSubmit => 'Submit rejection';

  @override
  String get leaveReviewApproveTitle => 'Approve request';

  @override
  String get leaveReviewApproveBtn => 'Approve';

  @override
  String get leaveReviewRejectBtn => 'Reject';

  @override
  String get leaveReviewRejectedSuccess =>
      'Request rejected. Parents can view the reason in app.';

  @override
  String get leaveReviewApproveFailed =>
      'Failed to approve request. Please try again later.';

  @override
  String get leaveReviewRejectFailed =>
      'Failed to reject request. Please check again.';

  @override
  String get errorGeneralFallback =>
      'An error occurred. Please try again later.';

  @override
  String get errorNoConnection =>
      'Cannot connect to server. Please check your network connection.';

  @override
  String get errorCannotConnectServer =>
      'Cannot connect to server. Please check your Wifi/4G connection or try again later.';

  @override
  String get errorTimeout =>
      'Connection timed out. Please check your internet connection.';

  @override
  String get errorSessionExpired => 'Session expired. Please log in again.';

  @override
  String get errorForbidden =>
      'You do not have permission to perform this action.';

  @override
  String get errorNotFound => 'Requested data was not found on the system.';

  @override
  String get errorBadRequest =>
      'Invalid data submitted. Please check your information.';

  @override
  String get errorServerInternal =>
      'Server error. Technical team is working on it, please try again later.';

  @override
  String get errorServiceUnavailable =>
      'System is temporarily under maintenance or overloaded. Please try again shortly.';

  @override
  String get errorLoadFailed =>
      'Failed to load data. Please check your network or try again later.';

  @override
  String get errorSaveFailed =>
      'Failed to save data. Please check your network or try again later.';

  @override
  String get errorSendFailed =>
      'Failed to send data. Please check your network or try again later.';

  @override
  String get errorUnexpectedGeneric =>
      'An unexpected error occurred. Please try again in a few minutes.';

  @override
  String get errorUnexpectedTeacher =>
      'An unexpected error occurred. Please try again in a few minutes.';

  @override
  String get errorPhoneAlreadyUsed => 'Phone number is already in use';

  @override
  String get errorCannotOpenDialer => 'Cannot open dialer app.';

  @override
  String get readReportAction => 'Read report ›';

  @override
  String get phoneCopied => 'Phone number copied';

  @override
  String get childFullName => 'Full name';

  @override
  String get childNicknameLabel => 'Nickname';

  @override
  String get childNotSet => 'Not set';

  @override
  String get parentDobLabel => 'Date of birth';

  @override
  String get parentAllergyTitle => 'Allergies';

  @override
  String get parentHealthProfileTitle => 'Health profile';

  @override
  String get switchChildLabel => 'Switch to another child';

  @override
  String get callHeadTeacher => 'Call head teacher';

  @override
  String get healthGood => 'Good health';

  @override
  String get parentHealthTitle => 'Health Profile';

  @override
  String get parentHealthLegacyInfo => 'Information from existing records';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String parentHealthLastUpdated(String who, String time) {
    return 'Last profile update: $who · $time';
  }

  @override
  String get parentHealthConflictTitle => 'Profile was updated elsewhere';

  @override
  String get parentHealthConflictBody => 'Please reload before saving.';

  @override
  String get parentHealthInvalidTitle => 'Invalid Information';

  @override
  String get parentHealthInvalidBody =>
      'Please review allergy information and care notes.';

  @override
  String get parentHealthTooLongTitle => 'Content Too Long';

  @override
  String get parentHealthTooLongBody =>
      'Allergy description and care notes must not exceed 1000 characters.';

  @override
  String get parentHealthAllergyRequired =>
      'Please enter child\'s allergy description.';

  @override
  String get parentHealthUndeclaredSubtitle =>
      'Family has not provided allergy information.';

  @override
  String get parentHealthNoKnownAllergy => 'No known allergies';

  @override
  String get parentHealthNoKnownAllergySubtitle =>
      'Family has not recorded any allergies.';

  @override
  String get parentHealthHasAllergySubtitle =>
      'Specify what the child is allergic to.';

  @override
  String get parentHealthAllergyLabel => 'Allergy description';

  @override
  String get parentHealthAllergyHint => 'e.g. Peanuts';

  @override
  String get parentHealthCareNotesHelper =>
      'Not for daily messages or medication requests.';

  @override
  String get commonReload => 'Reload';

  @override
  String get commonConfirmChange => 'Confirm Changes';

  @override
  String get commonStay => 'Stay';

  @override
  String get parentHealthAllergyNotesTitle => 'Allergies & Health Notes';

  @override
  String get parentHealthAllergySchoolNotice =>
      'Allergy details the school needs to note';

  @override
  String get childEditSubtitle =>
      'Update information so the school can care for your child better.';

  @override
  String get childEditFullNameLabel => 'Child\'s full name *';

  @override
  String get childEditFullNameHint => 'e.g. Nguyen Minh An';

  @override
  String get childEditFullNameRequired => 'Child\'s full name cannot be empty.';

  @override
  String get childEditNicknameLabel => 'Home nickname';

  @override
  String get childEditNicknameHint => 'e.g. Bo, Soc, Bon…';

  @override
  String get childEditDobLabel => 'Child\'s date of birth';

  @override
  String get childEditDobHint => 'Select date of birth';

  @override
  String get childEditDobFutureError =>
      'Child\'s date of birth cannot be in the future.';

  @override
  String get commonSelect => 'Select';

  @override
  String get childEditSaving => 'Saving information…';

  @override
  String get childEditSuccess => 'Child information updated successfully';

  @override
  String get childEditSaveError =>
      'Could not save child information. Please try again later.';

  @override
  String childNicknamePrefix(String nickname) {
    return 'Nickname: $nickname';
  }

  @override
  String appVersionNumber(String version) {
    return 'Version $version';
  }

  @override
  String parentHeroDays(int days) {
    return '$days days journey with child on KinderLog';
  }

  @override
  String parentJourneyDaysCount(int days) {
    return '$days days journey with KinderLog';
  }

  @override
  String get requestDetailTitle => 'Request Details';

  @override
  String get leaveRequestCreateTitle => 'Create Leave Request';

  @override
  String get requestCancelAction => 'Cancel Request';

  @override
  String get requestCancelThisAction => 'Cancel this request';

  @override
  String get leaveRequestCancelConfirmTitle => 'Cancel leave request?';

  @override
  String get requestKeepAction => 'Keep Request';

  @override
  String get requestSubmitButton => 'SUBMIT REQUEST';

  @override
  String get requestSubmitNoticeButton => 'SEND NOTICE';

  @override
  String get requestSubmitting => 'Submitting request';

  @override
  String get requestSubmittedTitle => 'Request Submitted';

  @override
  String get requestCancelledTitle => 'Request Cancelled';

  @override
  String get requestProcessStatus => 'Processing Status';

  @override
  String get requestReviewResult => 'Review Result';

  @override
  String get requestRejectReason => 'Rejection Reason';

  @override
  String get leaveRequestReasonLabel => 'Reason for leave';

  @override
  String get lateArrivalReasonLabel => 'Reason for late arrival';

  @override
  String get leaveRequestReasonHint => 'Enter reason for child\'s leave';

  @override
  String get lateArrivalReasonHint => 'Enter reason for child\'s late arrival';

  @override
  String get requestReasonMinLength =>
      'Reason must be at least 3 characters – validated on submit.';

  @override
  String get requestReasonMaxLength =>
      'Reason must not exceed 1000 characters.';

  @override
  String get requestReasonTrimmedError =>
      'Reason requires at least 3 characters after trimming spaces.';

  @override
  String get lateArrivalDesc => 'Arrive late today';

  @override
  String get leaveMultipleDaysDesc => '1 day or multiple days';

  @override
  String get lateArrivalBannerNote =>
      'New request type — notify in advance so teacher knows child\'s arrival schedule';

  @override
  String get lateArrivalTeacherNote =>
      'Teacher will see late note during morning attendance.';

  @override
  String get lateArrivalDisclaimer =>
      'Expected arrival is tentative; request approval does not replace actual attendance.';

  @override
  String get lateApprovalDisclaimer =>
      'Approved request does not confirm child presence or replace actual attendance.';

  @override
  String get syncAttendanceUnconfirmed =>
      'No attendance sync confirmation from system yet.';

  @override
  String get requestSentToTeacherNote =>
      'Request will be sent to head teacher for review.';

  @override
  String get requestWaitingTeacher => 'Waiting for teacher review';

  @override
  String get requestStatusCancelledUpper => 'CANCELLED';

  @override
  String get requestStatusRejectedShort => 'Rejected';

  @override
  String get requestStatusApprovedBanner => '✓ REQUEST APPROVED';

  @override
  String get requestBackToList => 'Back to requests';

  @override
  String get requestViewHistory => 'View request history';

  @override
  String get requestAttachmentLabel => 'Attachment';

  @override
  String get requestAddPrescriptionImage =>
      '+ Add medical note / prescription photo';

  @override
  String get requestPrescriptionImageTitle =>
      'Medical note / prescription photo';

  @override
  String get requestMedicalImageLabel => 'Medical photo';

  @override
  String get requestMedicalPhotoHint =>
      'Private medical photo · JPEG, PNG, WebP · Up to 5 MiB';

  @override
  String get requestMedicalPhotoAccessNote =>
      'Private medical photo, only authorized viewers can access.';

  @override
  String get requestImageTooLargeError =>
      'Image exceeds 5 MiB. Please select a smaller image.';

  @override
  String get requestCannotDisplayImage => 'Cannot display attached photo.';

  @override
  String get requestCannotLoadImage =>
      'Cannot load attached photo. Please try again.';

  @override
  String get requestCannotPickImage =>
      'Cannot open image. Please check gallery permissions and try again.';

  @override
  String get requestRemoveAttachment => 'Remove attachment';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonSelectTime => 'Select time';

  @override
  String get leaveDateLabel => 'Leave Date';

  @override
  String get requestDetailLoadError =>
      'Cannot load request details. Please try again.';

  @override
  String get requestDetailLoading => 'Loading request details';

  @override
  String get requestOpeningImage => 'Opening image…';

  @override
  String get requestLoadingMedicalImage => 'Loading medical image';

  @override
  String get commonTodayPrefix => 'Today — ';

  @override
  String get requestTypeTitle => 'Request Type';

  @override
  String get lateDateLabel => 'Late Arrival Date';

  @override
  String get leaveFromDate => 'From Date';

  @override
  String get leaveToDate => 'To Date';

  @override
  String get leaveTotalDaysPrefix => 'Total leave duration:';

  @override
  String get lateArrivalExpectedTime => 'Estimated arrival time';

  @override
  String get commonSelectDate => 'Select date';

  @override
  String get leaveRequestsNoRequests => 'No requests yet';

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get commonDays => 'days';

  @override
  String get categoryMeal => 'Meals';

  @override
  String get categorySleep => 'Sleep';

  @override
  String get categoryActivity => 'Activities';

  @override
  String get categoryMood => 'Mood';

  @override
  String get categoryHealth => 'Health';

  @override
  String get reportReadConfirmed => 'Report marked as read ✓';

  @override
  String get noChildRegistered => 'No child registered';

  @override
  String get noChildLinkedMessage =>
      'Your parent account is currently not linked to any child profile.\nPlease contact the school to update your child\'s information.';

  @override
  String get parentNavNotifications => 'Notifications';

  @override
  String get notificationsEmptyAll => 'No notifications.';

  @override
  String get notificationsEmptyReports => 'No new reports.';

  @override
  String get notificationsEmptyHealth => 'No health notifications.';

  @override
  String get notificationsEmptyLeave => 'No new leave requests.';

  @override
  String get notificationsFilterAllChildren => 'All children';

  @override
  String get notificationsSectionNew => 'New';

  @override
  String get notificationsSectionEarlier => 'Earlier';

  @override
  String get commonUnread => 'Unread';

  @override
  String get parentReportOpenError =>
      'Cannot open this report. Please try again later.';

  @override
  String get parentReportNoDetails => 'No recorded details for this day.';

  @override
  String get parentReportDatePrefix => 'Daily Report';

  @override
  String get parentChildClass => 'Child\'s Class';

  @override
  String get classroomTitle => 'Classroom';

  @override
  String get reportDraftSavedSnackBar => 'Report draft saved';

  @override
  String get noClassTitle => 'Not Assigned to Any Class';

  @override
  String get noClassMessage =>
      'Your account has not been assigned to any class yet. Please contact school administration for assistance, or try logging in again later.';

  @override
  String get loadClassListErrorRetry => 'Failed to load class list · Retry';

  @override
  String get loadClassInfoErrorRetry => 'Failed to load class info · Retry';

  @override
  String get noSchoolInfo => 'No school info available';

  @override
  String get loadClassListError =>
      'Failed to load class list. Please try again.';

  @override
  String get searchChildNameHint => 'Search child\'s name…';

  @override
  String get noChildMatched => 'No matching child found.';

  @override
  String get allergyPrefix => 'Allergy: ';

  @override
  String allergyTag(Object allergy) {
    return 'Allergy $allergy';
  }

  @override
  String get noCareNotes => 'No care notes yet.';

  @override
  String get dailyRecordTitle => 'Daily records';

  @override
  String get recordForChildAction => 'Record voice for child';

  @override
  String get viewParentDiscussionAction => 'View parent discussion';

  @override
  String healthStatusLabel(Object status) {
    return 'Health: $status';
  }

  @override
  String get unrecordedStatus => 'Unrecorded';

  @override
  String get recordedStatus => 'Recorded';

  @override
  String get filterAll => 'All';

  @override
  String get needsAttentionFilter => 'Needs attention';

  @override
  String get loadHistoryErrorRetry => 'Failed to load history · Retry';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get searchByChildNameHint => 'Search by child name…';

  @override
  String get noReportsMatchFilter => 'No reports match this filter.';

  @override
  String dailyReportDateRow(Object time) {
    return 'Daily report · $time';
  }

  @override
  String get todayText => 'Today';

  @override
  String get yesterdayText => 'Yesterday';

  @override
  String get logoutConfirmDialogTitle => 'Do you want to log out?';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get notUpdated => 'Not updated';

  @override
  String get assignedClassLabel => 'Assigned class';

  @override
  String classChildrenCount(Object className, Object count) {
    return '$className · $count children';
  }

  @override
  String get teacherTitle => 'Teacher';

  @override
  String get teacherPrefix => 'Teacher ';

  @override
  String get loadAccountErrorRetry => 'Failed to load account · Retry';

  @override
  String get accountTitle => 'Account';

  @override
  String get headTeacherRole => 'Head teacher';

  @override
  String get viewProfile => 'View profile';

  @override
  String get personalSection => 'Personal';

  @override
  String get contactInfoLabel => 'Contact information';

  @override
  String get preferencesSection => 'Preferences';

  @override
  String get notificationsNavLabel => 'Notifications';

  @override
  String get changePasswordLabel => 'Change password';

  @override
  String get languageSettingLabel => 'Language / Ngôn ngữ';

  @override
  String get vietnameseLanguage => 'Tiếng Việt 🇻🇳';

  @override
  String get englishLanguage => 'English 🇬🇧';

  @override
  String get supportSection => 'Support';

  @override
  String get helpAndBugReport => 'Help & Bug Report';

  @override
  String get aboutKinderlog => 'About KinderLog';

  @override
  String get cannotVerifyClassNotifications =>
      'Cannot verify class notifications.';

  @override
  String get cannotLoadNotificationsRetry =>
      'Failed to load notifications. Please try again.';

  @override
  String get filterLeaveRequests => 'Leave requests';

  @override
  String get filterIncidents => 'Incidents';

  @override
  String get badgeLateArrival => 'LATE ARRIVAL';

  @override
  String get badgeLeaveRequest => 'LEAVE REQUEST';

  @override
  String get newBadgeSuffix => 'new';

  @override
  String lateArrivalNotificationDesc(Object date, Object time) {
    return 'Late arrival $date · Expected $time';
  }

  @override
  String leaveNotificationDesc(Object date, Object days, Object time) {
    return 'Leave $date ($days days) · Sent $time';
  }

  @override
  String healthIncidentNotificationTitle(Object name) {
    return 'Health incident — $name';
  }

  @override
  String attendanceUpdatedTitle(Object name) {
    return 'Attendance updated — $name';
  }

  @override
  String arrivedLateDesc(Object time) {
    return 'Arrived late$time';
  }

  @override
  String excusedAbsentDesc(Object note) {
    return 'Excused absence$note';
  }

  @override
  String unexcusedAbsentDesc(Object note) {
    return 'Absent$note';
  }

  @override
  String dailyReportSentCount(Object sent, Object total) {
    return 'Daily reports sent $sent/$total';
  }

  @override
  String dailyReportPendingRemaining(Object names) {
    return '$names remaining without reports';
  }

  @override
  String dailyReportDraftCountRemaining(Object count) {
    return '$count drafts remaining unsent';
  }

  @override
  String get dailyReportAllCompleted => 'Completed all reports for the class';

  @override
  String get earlierSection => 'Earlier';

  @override
  String get noIncidentNotifications => 'No incident notifications yet.';

  @override
  String get noNotifications => 'No notifications.';

  @override
  String get loadMore => 'Load more';

  @override
  String get badgeMedication => 'MEDICATION';

  @override
  String get badgeIncident => 'INCIDENT';

  @override
  String get badgeAttendance => 'ATTENDANCE';

  @override
  String get badgeReport => 'REPORT';

  @override
  String get unreadStatus => 'Unread';

  @override
  String get readStatus => 'Read';

  @override
  String get attendanceSavedSuccess => 'Attendance saved successfully';

  @override
  String get cannotSaveAttendanceRetry =>
      'Failed to save attendance. Please try again later.';

  @override
  String get discardAttendanceChangesTitle => 'Discard attendance changes?';

  @override
  String get discardAttendanceChangesMessage =>
      'Changes made to the attendance list will not be saved.';

  @override
  String get continueAttendance => 'Continue attendance';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String attendanceNotifiedParentsCount(Object count) {
    return 'Sent attendance notice to parents ($count devices received)';
  }

  @override
  String get cannotSendAttendanceNotification =>
      'Cannot send notifications at this time. Please check your connection.';

  @override
  String get noAttendanceDataForDate => 'No attendance data for this date.';

  @override
  String get cannotLoadAttendanceForDate =>
      'Failed to load attendance for the selected date.';

  @override
  String get sendAbsentNotification => 'Send absent notification';

  @override
  String attendanceSummaryText(Object absent, Object arrived,
      Object excusedAbsent, Object late, Object onTime, Object total) {
    return '$arrived/$total children arrived. $onTime on time, $late late, $absent absent, $excusedAbsent excused.';
  }

  @override
  String studentsArrivedCount(Object arrived, Object total) {
    return '$arrived/$total children arrived';
  }

  @override
  String onTimeCount(Object count) {
    return '$count on time';
  }

  @override
  String lateCountText(Object count) {
    return '$count late';
  }

  @override
  String absentCountText(Object count) {
    return '$count absent';
  }

  @override
  String excusedAbsentCountText(Object count) {
    return '$count excused';
  }

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String pendingLeaveRequestsCount(Object count) {
    return '$count leave requests pending review';
  }

  @override
  String get savingStatus => 'Saving…';

  @override
  String get saveAction => 'Save';

  @override
  String get updatedStatus => 'Updated';

  @override
  String arrivedAtTime(Object time) {
    return 'Arrived at $time';
  }

  @override
  String expectedAtTime(Object time) {
    return 'Expected at $time';
  }

  @override
  String get sendAbsentNoticeConfirmTitle => 'Send absent notification?';

  @override
  String sendAbsentNoticeConfirmMessage(Object count, Object date) {
    return 'Send push notification to parents of $count absent children on $date.';
  }

  @override
  String get unsavedAttendanceNoticeWarning =>
      'Unsaved attendance · You should save attendance before sending notifications.';

  @override
  String get sendNotificationAction => 'Send notification';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get statusAbsent => 'Absent';

  @override
  String get statusExcusedAbsent => 'Excused';

  @override
  String get statusLate => 'Late';

  @override
  String get cannotVerifyClassRequests => 'Cannot verify class requests.';

  @override
  String get cannotLoadMoreRequests =>
      'Failed to load more requests. Please try again.';

  @override
  String get cannotLoadRequestsList =>
      'Failed to load requests list. Please check your network connection.';

  @override
  String get approveRequestFailed =>
      'Failed to approve request. Please try again later.';

  @override
  String get student => 'Student';

  @override
  String get requestRejectedSuccess =>
      'Request rejected. Parents can view the reason in the app.';

  @override
  String get rejectRequestFailed =>
      'Failed to reject request. Please check again.';

  @override
  String get closeImage => 'Close image';

  @override
  String get cannotDisplayImage => 'Cannot display this image.';

  @override
  String get cannotLoadAttachment =>
      'Failed to load attachment. Please try again.';

  @override
  String get reviewLeaveRequestTitle => 'Review leave requests';

  @override
  String totalDaysCount(Object days) {
    return '$days days';
  }

  @override
  String get reasonLabel => 'Reason';

  @override
  String get senderLabel => 'Sender';

  @override
  String get parentRole => 'Parent';

  @override
  String get sentAtLabel => 'Sent at';

  @override
  String get attachmentLabel => 'Attachment';

  @override
  String get viewAttachment => 'View attachment';

  @override
  String get rejectReasonLabel => 'Rejection reason';

  @override
  String get etaDisclaimer =>
      'Expected arrival time is not the actual check-in time.';

  @override
  String get leaveApprovalDisclaimer =>
      'When approved, attendance will be synced to \'Excused absent\'; actual check-in time is retained.';

  @override
  String get rejectAction => 'Reject';

  @override
  String get approveAction => 'Approve request';

  @override
  String get cannotOpenPhoneApp => 'Cannot open phone call application.';

  @override
  String pendingReviewWithCount(Object count) {
    return 'Pending review ($count)';
  }

  @override
  String get processedTab => 'Processed';

  @override
  String get noPendingRequests => 'No requests pending review';

  @override
  String get noProcessedRequestsHistory => 'No processed request history yet';

  @override
  String get recentlyProcessed => 'Recently processed';

  @override
  String get retryLoadMore => 'Retry loading more';

  @override
  String get viewRequestDetail => 'View request detail';

  @override
  String get rejectReasonPrompt => 'Rejection reason *';

  @override
  String get rejectReasonHint =>
      'Enter specific reason so parents stay informed';

  @override
  String get rejectReasonValidation =>
      'Reason is required (2–500 characters). Parents will see this reason in child\'s request details.';

  @override
  String get sendRejectionAction => 'Submit rejection';

  @override
  String get cannotLoadTimetable => 'Failed to load timetable.';

  @override
  String get classTimetableTitle => 'Class timetable';

  @override
  String get searchTimetableHint =>
      'Search period, subject, time slot (e.g. 08:00, 8h)...';

  @override
  String get noMatchingActivitiesFound => 'No matching activities found';

  @override
  String get searchTimetableSuggestion =>
      'Try searching with a different time slot or subject/room name.';

  @override
  String get addActivityAction => 'Add activity';

  @override
  String conflictsCount(Object count) {
    return '$count conflicts';
  }

  @override
  String get noConflicts => 'No conflicts';

  @override
  String get noActivitiesYet => 'No activities yet';

  @override
  String thisWeekWithLabel(Object label) {
    return 'This week · $label';
  }

  @override
  String roomLabel(Object room) {
    return 'Room: $room';
  }

  @override
  String get deleteAction => 'Delete';

  @override
  String get deleteActivityConfirmTitle => 'Delete this activity?';

  @override
  String get deleteActivityConfirmMessage =>
      'Weekly recurring activity — will be removed from class timetable.';

  @override
  String get activityDeletedSuccess => 'Activity deleted';

  @override
  String get cannotDeleteActivity =>
      'Failed to delete activity. Please try again.';

  @override
  String get noActivitiesThisWeek => 'No activities this week.';

  @override
  String get classHasNoActivitiesThisWeek =>
      'Class has no activities for this week.';

  @override
  String get addActivityToSchedulePrompt =>
      'Add activities to schedule for the class.';

  @override
  String get ongoingStatus => 'Ongoing';

  @override
  String get upNextStatus => 'Up next';

  @override
  String get timeSlotConflict => 'Time slot conflict';

  @override
  String get dayTab => 'Day';

  @override
  String get weekTab => 'Week';

  @override
  String get enterActivityNamePrompt => 'Please enter activity name.';

  @override
  String get selectSubjectPrompt => 'Please select subject / activity.';

  @override
  String get selectTimeSlotPrompt => 'Please select time slot.';

  @override
  String get activityAddedSuccess => 'Activity added';

  @override
  String get activityUpdatedSuccess => 'Activity updated';

  @override
  String get cannotSaveActivity => 'Failed to save activity. Please try again.';

  @override
  String get editActivityTitle => 'Edit activity';

  @override
  String get selectClassPrompt => 'Select classroom';

  @override
  String get activityNameLabel => 'Activity';

  @override
  String get activityNameExampleHint => 'E.g. Creative Drawing';

  @override
  String get subjectActivityLabel => 'Subject / Activity';

  @override
  String get timeSlotLabel => 'Time slot';

  @override
  String get dayOfWeekLabel => 'Day of week';

  @override
  String get roomOptionalLabel => 'Room (optional)';

  @override
  String get roomExampleHint => 'E.g. Art Room';

  @override
  String timeSlotClashWarning(Object activity, Object day) {
    return 'This slot already has \"$activity\" on $day.';
  }

  @override
  String get saveActivityAction => 'Save activity';

  @override
  String get noSubjectsPrompt =>
      'No subjects available. Please create a subject first.';

  @override
  String get noTimeSlotsPrompt =>
      'No time slots available. Please create a time slot first.';

  @override
  String get emergencyHighFever => 'High fever';

  @override
  String get emergencyFallAccident => 'Fall / Accident';

  @override
  String get emergencyAllergyReaction => 'Acute allergic reaction';

  @override
  String get emergencyOther => 'Other';

  @override
  String get selectStudentEmergencyPrompt =>
      'Please select student experiencing incident.';

  @override
  String get temperatureRangePrompt =>
      'Temperature must be between 34°C and 44°C.';

  @override
  String get emergencySavedContactInvalid =>
      'Incident saved but contact list is invalid. Please reload contacts, do not resubmit form.';

  @override
  String get cannotOpenPhoneCallUseDirect =>
      'Cannot open phone dialer. Please use directory number to call directly.';

  @override
  String get noValidPhoneNumberInContacts =>
      'No valid phone number in emergency contacts.';

  @override
  String get selectParentToCall => 'Select parent to call';

  @override
  String get reportIncidentTitle => 'Report incident';

  @override
  String get notifyParentsAndSchool => 'Notify parents and school';

  @override
  String get emergencyVerificationWarning =>
      'Verify child, details, and recipients before sending emergency alert.';

  @override
  String get changeChild => 'Change child';

  @override
  String get selectStudentHint => 'Select student...';

  @override
  String get tapToSearchAndSelectChild => 'Tap to search and select child';

  @override
  String get incidentTypeLabel => 'Incident type';

  @override
  String get temperatureOptionalLabel => 'Temperature (optional)';

  @override
  String get temperatureHint => 'E.g. 38.5';

  @override
  String get incidentDescriptionLabel => 'Incident description';

  @override
  String get incidentFirstAidHint =>
      'Condition and first aid actions (optional)';

  @override
  String get alertRecipientsLabel => 'Alert recipients';

  @override
  String get loadingContacts => 'Loading contacts...';

  @override
  String get noParentPhoneUpdatedForChild =>
      'No parent phone number updated for this child.';

  @override
  String get reloadContacts => 'Reload contacts';

  @override
  String get sendEmergencyAlertAction => 'Send emergency alert';

  @override
  String get callParentsAction => 'Call parents';

  @override
  String get emergencyOneTapDisclaimer =>
      'One-tap incident log. Push alerts may process in background; call family if immediate confirmation is needed.';

  @override
  String get incidentReportSavedSuccess => 'Incident report saved';

  @override
  String get contactLabel => 'Contact';

  @override
  String get noTeacherDescription => 'No description from teacher.';

  @override
  String get noPushConfirmationYet => 'No push delivery confirmation yet.';

  @override
  String get callParentsNow => 'Call parents now';

  @override
  String get completeAction => 'Complete';

  @override
  String get selectStudentTitle => 'Select student';

  @override
  String get cannotOpenPhoneCallApp => 'Cannot open phone call application.';

  @override
  String get copyAction => 'Copy';

  @override
  String get noTimeAvailable => 'No time available';

  @override
  String get emergencyAlertTitle => 'Emergency Alert';

  @override
  String teacherSentIncidentNotice(Object teacherName) {
    return '$teacherName just sent an incident notice.';
  }

  @override
  String get teacherContentHeader => 'Content from teacher';

  @override
  String temperatureDegrees(Object temp) {
    return 'Temperature · $temp°C';
  }

  @override
  String callTeacherAction(Object teacherName) {
    return 'Call $teacherName';
  }

  @override
  String get acknowledgedDismissSiren => 'Acknowledged · Dismiss siren';

  @override
  String get badgeLateArrivalApproved => 'Late arrival approved';

  @override
  String get badgeRequestApproved => 'Request approved';

  @override
  String get checkAttendanceAfterApprovalHint =>
      'You can check attendance status on the Attendance screen after approving request.';

  @override
  String get lateArrivalApprovedTitle => 'Late arrival request approved';

  @override
  String get leaveRequestApprovedTitle => 'Leave request approved';

  @override
  String get requestUpdatedStatus => 'Request updated';

  @override
  String get requestStatusUpdatedDesc => 'Request status has been updated.';

  @override
  String attendanceDateAfterApproval(Object date) {
    return 'Attendance on $date after approval';
  }

  @override
  String get returnToAttendanceAction => 'Return to Attendance';

  @override
  String leaveRequestDetailOf(Object name) {
    return 'Request detail of $name';
  }

  @override
  String get leaveReasonLabel => 'Leave reason:';

  @override
  String get commonContent => 'Content';

  @override
  String get requestTotalDays => 'Total days';

  @override
  String lateArrivalNewNotice(String name) {
    return 'New late arrival notice — $name';
  }

  @override
  String leaveRequestNewNotice(String name) {
    return 'New leave request — $name';
  }

  @override
  String get lateArrivalNoticeType => 'late arrival notice';

  @override
  String get leaveRequestNoticeType => 'leave request';

  @override
  String get classListTab => 'Class list';

  @override
  String notificationsWithUnreadCount(int count) {
    return 'Notifications, $count unread';
  }

  @override
  String relationSelectChildPrompt(String name) {
    return 'Select your relationship with $name.';
  }

  @override
  String maxImagesLimitWarning(int count) {
    return 'You can only attach up to $count images.';
  }

  @override
  String fileExceedsSizeLimit(String name, int size) {
    return 'File $name exceeds the allowed ${size}MB limit.';
  }

  @override
  String get cannotPickImageFromDevice => 'Cannot pick image from device.';

  @override
  String get bugReportAttachmentsHint =>
      'Attachments · maximum 5 images, each ≤ 5MB';

  @override
  String get bugReportSendFailed =>
      'Failed to send feedback. Please check your network connection and try again.';

  @override
  String get titleRequired => 'Please enter a title for feedback or issue';

  @override
  String get descriptionRequired => 'Please enter a detailed description';

  @override
  String get aboutVersionLabel => 'Version';

  @override
  String get aboutSchoolDefault => 'Hoa Mi Kindergarten';

  @override
  String get aboutSchoolYear => 'School year';

  @override
  String get aboutKeyFeatures => 'KEY FEATURES';

  @override
  String get aboutFeatureVoiceTitle => 'Hands-free AI Voice';

  @override
  String get aboutFeatureVoiceDesc =>
      'Teachers create daily reports via voice, with automatic speech-to-text and classification for meals, naps, and learning.';

  @override
  String get aboutFeatureContactBookTitle => 'Digital Contact Book';

  @override
  String get aboutFeatureContactBookDesc =>
      'Real-time updates of each child\'s activities; parents follow and reply to teacher remarks during the day.';

  @override
  String get aboutFeatureHealthTitle => 'Health & Allergy Records';

  @override
  String get aboutFeatureHealthDesc =>
      'Manage allergies, check-up history, track weight and height, and automatically calculate BMI status.';

  @override
  String get aboutFeatureTimetableTitle => 'Timetable & Leave Requests';

  @override
  String get aboutFeatureTimetableDesc =>
      'View weekly class timetables, submit leave requests online, and receive quick teacher confirmations.';

  @override
  String get aboutDevTeam => 'Development Team';

  @override
  String get aboutTechSupport => 'Technical Support';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutProtected => 'Protected';

  @override
  String get aboutTermsOfService => 'Terms of Service';

  @override
  String get aboutCompliant => 'Compliant';

  @override
  String get cannotLoadDiscussion =>
      'Could not load discussion. Please try again later.';

  @override
  String get cannotPickImageGeneric =>
      'Could not select image. Please try again.';

  @override
  String get attachImageTitle => 'Attach image';

  @override
  String get takePhotoCamera => 'Take photo from camera';

  @override
  String get choosePhotoGallery => 'Choose photo from gallery';

  @override
  String get sentAttachedImage => 'Sent an attached image';

  @override
  String get cannotSendMessage => 'Could not send message. Please try again.';

  @override
  String get cannotSendVoiceMessage =>
      'Could not send voice message. Please try again later.';

  @override
  String get discussionWithParent => 'Discussion with parents';

  @override
  String get discussionWithTeacher => 'Discussion with teacher';

  @override
  String discussionResponseCount(int count) {
    return '$count responses';
  }

  @override
  String get discussionResponded => 'Responded';

  @override
  String get discussionNoDiscussionYet => 'No discussion yet';

  @override
  String get discussionNoResponsesYet => 'No responses yet';

  @override
  String get discussionTeacherEmptyHint =>
      'When parents send feedback on this report, messages will appear here for the teacher to follow up and reply.';

  @override
  String get discussionParentEmptyHint =>
      'Parents can send messages or notes to the teacher about this report.';

  @override
  String get discussionSentReadByParent => 'Sent · Read by parent';

  @override
  String get discussionSentReadByTeacher => 'Sent · Read by teacher';

  @override
  String get discussionAcknowledged => '✓ Acknowledged & resolved';

  @override
  String get discussionMarkHandled => 'Mark as resolved';

  @override
  String get discussionAttachedImage => 'Attached image';

  @override
  String get discussionReadyToSendWithMsg => 'Ready to send with message';

  @override
  String get discussionCancelImage => 'Deselect image';

  @override
  String get discussionAttachImageTooltip => 'Attach photo';

  @override
  String get discussionTeacherInputHint =>
      'Reply to parent about this report...';

  @override
  String get discussionParentInputHint =>
      'Message the teacher about this report...';

  @override
  String get chatWithParent => 'Chat with parent';

  @override
  String get chatWithTeacher => 'Chat with teacher';

  @override
  String childLabelPrefix(String name) {
    return 'Child $name';
  }

  @override
  String get minimizeChatTooltip => 'Minimize chat window';

  @override
  String reviewApprovedCount(int approved, int total) {
    return 'Approved $approved/$total';
  }

  @override
  String get sttCopiedAnalyzedText => 'Analyzed text copied to clipboard.';

  @override
  String sttSplitChildrenCount(int count) {
    return 'Separated $count children';
  }

  @override
  String get sttSaveText => 'Save text';

  @override
  String get sttCannotRecognizeHint =>
      'Could not recognize this segment. Click X above to delete and re-record.';

  @override
  String get sttEditTranscriptHint => 'Enter or edit audio transcript…';

  @override
  String get sttRecognizing => 'Recognizing…';

  @override
  String get sttErrorBadge => 'STT Error';

  @override
  String get sttDoneBadge => 'Done';

  @override
  String sttSegmentIndex(int index) {
    return 'Segment $index';
  }

  @override
  String sttReportsSummary(int parentsCount, int healthCount, String time) {
    return '$parentsCount parents received reports. Health record has $healthCount new rows. All from recording at $time.';
  }

  @override
  String get sttSendReportConfirmTitle => 'Send reports to parents?';

  @override
  String sttDailyReportDate(String date) {
    return 'Daily report · $date';
  }

  @override
  String get sttSaveDraftSuccess => 'Draft saved successfully';

  @override
  String get sttCannotSaveDraft => 'Could not save draft. Please try again.';

  @override
  String get sttCannotSendReport => 'Could not send report. Please try again.';

  @override
  String get sttSentCannotEdit => 'Report has been sent and cannot be edited.';

  @override
  String get sttNoRecordYet => 'No observations yet';

  @override
  String get sttMood => 'Mood';

  @override
  String get sttTeacherNotes => 'Teacher notes';

  @override
  String get sttSaveDraft => 'Save draft';

  @override
  String get sttSendReport => 'Send report';

  @override
  String get sttStepReview => 'Step 3/3 · Review';

  @override
  String get sttNoAudioToPlay => 'No audio file to replay.';

  @override
  String get sttCannotPlayAudio => 'Could not play this audio clip.';

  @override
  String get sttNoMicPermissionTitle => 'Microphone permission required';

  @override
  String get sttCannotRecordTitle => 'Cannot record audio';

  @override
  String get sttOpenSettingsForMic =>
      'Open Settings to grant microphone permission.';

  @override
  String get sttStopRecording => 'Stop recording';

  @override
  String get sttSaveClip => 'Save clip';

  @override
  String get sttStartRecording => 'Start recording';

  @override
  String get sttUploadFile => 'Upload file';

  @override
  String get sttRerecord => 'Re-record';

  @override
  String get sttReprocessClip => 'Reprocess recording';

  @override
  String get sttSendToParents => 'Send report to parents';

  @override
  String get sttEnterTextHint => 'Enter text content...';

  @override
  String get sttReanalyze => 'Re-analyze';

  @override
  String get sttReportSentSuccessTitle => 'Report sent';

  @override
  String get sttUndo => 'Undo';

  @override
  String get sttSearchChildNameOrNick => 'Search child\'s name or nickname';

  @override
  String get sttSearchChild => 'Search child…';

  @override
  String get sttRecordActivityTitle => 'Record activities';

  @override
  String get sttSelectChildToStart => 'Select a child to start recording';

  @override
  String get sttOrSelectEachChild => 'or select each child';

  @override
  String get sttIncidentAlertTitle => 'Incident report';

  @override
  String get sttAnalyzingAudio => 'Analyzing recording';

  @override
  String get sttProcessingTitle => 'Processing';

  @override
  String get sttCannotLoadClassRetry => 'Could not load class · Retry';

  @override
  String get sttCannotLoadReportRetry => 'Could not load report · Retry';

  @override
  String get sttUnknownClass => 'Unassigned';

  @override
  String get sttUnknownSchool => 'School unassigned';

  @override
  String get commonSearchPlaceholder => 'Search...';

  @override
  String get rejectReasonPlaceholder =>
      'Enter a specific reason for parents to understand';

  @override
  String get rejectReasonHelper =>
      'Reason is required (2–500 characters). Parents can view it in request details.';

  @override
  String get commonChild => 'Child';

  @override
  String get requestNoResultYet => 'None yet';

  @override
  String get syncAttendanceNotConfirmed =>
      'Attendance sync not yet confirmed by the system.';

  @override
  String get cannotCancelContactTeacher =>
      'This request cannot be cancelled. Please contact the teacher.';

  @override
  String get leaveRequestDisclaimer =>
      'Request approval does not confirm attendance or replace actual attendance.';

  @override
  String get cannotVerifyChildRequest =>
      'Could not verify child request. Please reload.';

  @override
  String get cancelConfirmPendingPrompt =>
      'Cancellation not yet confirmed. Please refresh before retrying.';

  @override
  String get cancelSessionConfirmTitle => 'Cancel recording session?';

  @override
  String get cancelSessionConfirmDesc =>
      'All recordings in the current session will be discarded.';

  @override
  String get keepSessionAction => 'Keep';

  @override
  String get cancelSessionAction => 'Cancel session';

  @override
  String get openSettingsAction => 'Open Settings';

  @override
  String get laterAction => 'Later';

  @override
  String get audioTooShortError =>
      'Recording is too short or contains no audio. Please try again.';

  @override
  String get cannotSaveAudioError =>
      'Could not save recording. Please record again.';

  @override
  String get recordingHintTitle => 'Tip: narrate the child\'s activities';

  @override
  String get recordingHintDesc =>
      'Mention in order: meals, nap, activities, health, and mood.';

  @override
  String get sendForProcessing => 'Send for processing';

  @override
  String get sendForAnalysis => 'Send for analysis';

  @override
  String get recordingLiveMessage => 'Recording · Speak naturally';

  @override
  String get pressToStartRecording => 'Tap to start recording';

  @override
  String get savingClipToSession => 'Saving audio clip to session…';

  @override
  String get uploadAudioFile => 'Upload audio file';

  @override
  String get chooseAnotherFile => 'Choose another file';

  @override
  String get cancelFileSelection => 'Cancel selection';

  @override
  String get readyToGenerateReports => 'Ready to generate reports';

  @override
  String get approveAll => 'Approve all';

  @override
  String get unapproveAll => 'Unapprove all';

  @override
  String get approvedStatus => 'Approved';

  @override
  String get unapprovedStatus => 'Unapprove';

  @override
  String get discardItem => 'Discard';

  @override
  String get assignThisSegment => 'Assign this segment';

  @override
  String get skipThisSegment => 'Skip this segment';

  @override
  String get unidentifiedChild => 'Unidentified child';

  @override
  String recognizedChildPrefix(String name) {
    return 'Recognized · $name';
  }

  @override
  String discardedChildPrefix(String name) {
    return 'Discarded · $name';
  }

  @override
  String get entireClassOption => 'Entire class';

  @override
  String get assignSegmentTitle => 'Assign segment';

  @override
  String get noDetailsRecorded => 'No detailed information recorded';

  @override
  String get confirmSendAllReports => 'Confirm send for entire class';

  @override
  String get noItemsApprovedToSend => 'No approved items to send';

  @override
  String get allClipsProcessed => 'All clips processed';

  @override
  String forChildOnly(String name) {
    return 'Only $name';
  }

  @override
  String get applyToEntireClass => 'Apply to entire class';

  @override
  String get categoryEating => 'Eating';

  @override
  String get categoryNote => 'Notes';

  @override
  String get noDetailInfoRecorded => 'No detailed information recorded';

  @override
  String wholeClassOption(String className) {
    return 'Whole class $className';
  }

  @override
  String get recordAllChildrenSubtitle =>
      'Record once, create reports for all children.';

  @override
  String childrenCountFormat(int total) {
    return '$total children';
  }

  @override
  String get unidentifiedChildSnippetDefault =>
      'Could not accurately identify the child in class.';

  @override
  String get openNotifications => 'Open notifications';

  @override
  String parentJourneyDaysLabel(int days) {
    return '$days days journey with child at KinderLog';
  }

  @override
  String get changePassword => 'Change password';

  @override
  String get switchChild => 'Switch child';

  @override
  String get childInfoSheetTitle => 'Child Information';

  @override
  String nicknamePrefix(String nickname) {
    return 'Nickname: $nickname';
  }

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }
}
