import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// App name shown in title bar
  ///
  /// In en, this message translates to:
  /// **'KinderLog'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again later.'**
  String get commonError;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get languageVietnamese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Display Language'**
  String get languageSelectTitle;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get navClass;

  /// No description provided for @navRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navRecord;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get navTimetable;

  /// No description provided for @navAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get navAttendance;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get accountSettings;

  /// No description provided for @accountSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get accountSupport;

  /// No description provided for @accountSettingsAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Settings & Support'**
  String get accountSettingsAndSupport;

  /// No description provided for @accountChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get accountChangePassword;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Ngôn ngữ / Language'**
  String get accountLanguage;

  /// No description provided for @accountBugReport.
  ///
  /// In en, this message translates to:
  /// **'Bug Report & Feedback'**
  String get accountBugReport;

  /// No description provided for @accountAbout.
  ///
  /// In en, this message translates to:
  /// **'About KinderLog'**
  String get accountAbout;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogout;

  /// No description provided for @accountAssignedClass.
  ///
  /// In en, this message translates to:
  /// **'Assigned Class'**
  String get accountAssignedClass;

  /// No description provided for @accountStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get accountStudents;

  /// No description provided for @accountChildProfile.
  ///
  /// In en, this message translates to:
  /// **'Child Profile'**
  String get accountChildProfile;

  /// No description provided for @accountChildParent.
  ///
  /// In en, this message translates to:
  /// **'Child\'s Parent'**
  String get accountChildParent;

  /// No description provided for @accountTeacherInCharge.
  ///
  /// In en, this message translates to:
  /// **'Teacher in Charge'**
  String get accountTeacherInCharge;

  /// No description provided for @accountPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get accountPhoneNumber;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get accountAddress;

  /// No description provided for @accountWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get accountWeight;

  /// No description provided for @accountHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get accountHeight;

  /// No description provided for @accountBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood Type'**
  String get accountBloodType;

  /// No description provided for @accountAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get accountAllergies;

  /// No description provided for @accountHealthNotes.
  ///
  /// In en, this message translates to:
  /// **'Health Notes'**
  String get accountHealthNotes;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmMessage;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get loginWelcomeBack;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Preserving every precious moment of your child\'s growth together.'**
  String get loginTagline;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'USERNAME'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username or Gmail'**
  String get loginUsernameHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get loginPasswordHint;

  /// No description provided for @loginRememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember password'**
  String get loginRememberPassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @loginFooter.
  ///
  /// In en, this message translates to:
  /// **'Connecting classrooms · Peace of mind every day'**
  String get loginFooter;

  /// No description provided for @loginErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter both username/Gmail and password.'**
  String get loginErrorEmpty;

  /// No description provided for @loginErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your internet connection or try again later.'**
  String get loginErrorFailed;

  /// No description provided for @loginErrorAdminWebOnly.
  ///
  /// In en, this message translates to:
  /// **'Admin accounts are only supported on the Web version. Please visit the admin portal on a desktop browser.'**
  String get loginErrorAdminWebOnly;

  /// No description provided for @loginRememberError.
  ///
  /// In en, this message translates to:
  /// **'Unable to read saved credentials. You can still sign in.'**
  String get loginRememberError;

  /// No description provided for @loginRememberClearError.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear saved credentials. Please try again.'**
  String get loginRememberClearError;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordOldLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordOldLabel;

  /// No description provided for @changePasswordOldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get changePasswordOldHint;

  /// No description provided for @changePasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNewLabel;

  /// No description provided for @changePasswordNewHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get changePasswordNewHint;

  /// No description provided for @changePasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirmLabel;

  /// No description provided for @changePasswordConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get changePasswordConfirmHint;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get changePasswordButton;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully!'**
  String get changePasswordSuccess;

  /// No description provided for @changePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get changePasswordMismatch;

  /// No description provided for @changePasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all password fields.'**
  String get changePasswordEmpty;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email address to receive an OTP code to reset your password.'**
  String get forgotPasswordInstruction;

  /// No description provided for @forgotPasswordEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Email'**
  String get forgotPasswordEmailLabel;

  /// No description provided for @forgotPasswordEmailHint.
  ///
  /// In en, this message translates to:
  /// **'example@gmail.com'**
  String get forgotPasswordEmailHint;

  /// No description provided for @forgotPasswordSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get forgotPasswordSendOtp;

  /// No description provided for @forgotPasswordEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP Code'**
  String get forgotPasswordEnterOtp;

  /// No description provided for @forgotPasswordVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get forgotPasswordVerify;

  /// No description provided for @teacherNavAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get teacherNavAttendance;

  /// No description provided for @teacherNavTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get teacherNavTimetable;

  /// No description provided for @teacherNavRecord.
  ///
  /// In en, this message translates to:
  /// **'Daily Log'**
  String get teacherNavRecord;

  /// No description provided for @teacherNavNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get teacherNavNotifications;

  /// No description provided for @teacherNavAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get teacherNavAccount;

  /// No description provided for @teacherGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, Teacher {name}!'**
  String teacherGreeting(String name);

  /// No description provided for @teacherClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Class {className}'**
  String teacherClassTitle(String className);

  /// No description provided for @teacherStudentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} students'**
  String teacherStudentCount(int count);

  /// No description provided for @teacherAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get teacherAccountTitle;

  /// No description provided for @teacherAccountSectionClass.
  ///
  /// In en, this message translates to:
  /// **'Assigned Class'**
  String get teacherAccountSectionClass;

  /// No description provided for @teacherAccountSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings & Support'**
  String get teacherAccountSectionSettings;

  /// No description provided for @teacherAccountAbout.
  ///
  /// In en, this message translates to:
  /// **'About KinderLog'**
  String get teacherAccountAbout;

  /// No description provided for @teacherAccountQuickBug.
  ///
  /// In en, this message translates to:
  /// **'Bug Report & Feedback'**
  String get teacherAccountQuickBug;

  /// No description provided for @teacherLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get teacherLogoutConfirmTitle;

  /// No description provided for @teacherLogoutConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get teacherLogoutConfirmButton;

  /// No description provided for @attendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Attendance'**
  String get attendanceTitle;

  /// No description provided for @attendanceSummaryPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendanceSummaryPresent;

  /// No description provided for @attendanceSummaryAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceSummaryAbsent;

  /// No description provided for @attendanceSummaryLeave.
  ///
  /// In en, this message translates to:
  /// **'On Leave'**
  String get attendanceSummaryLeave;

  /// No description provided for @attendanceCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Morning Check-in'**
  String get attendanceCheckIn;

  /// No description provided for @attendanceCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Check-out'**
  String get attendanceCheckOut;

  /// No description provided for @attendanceSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Attendance saved successfully!'**
  String get attendanceSaveSuccess;

  /// No description provided for @leaveRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Requests'**
  String get leaveRequestsTitle;

  /// No description provided for @leaveRequestsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get leaveRequestsPending;

  /// No description provided for @leaveRequestsApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get leaveRequestsApproved;

  /// No description provided for @leaveRequestsRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get leaveRequestsRejected;

  /// No description provided for @leaveRequestApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get leaveRequestApprove;

  /// No description provided for @leaveRequestReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get leaveRequestReject;

  /// No description provided for @leaveRequestReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String leaveRequestReason(String reason);

  /// No description provided for @recordTitle.
  ///
  /// In en, this message translates to:
  /// **'Class Daily Log'**
  String get recordTitle;

  /// No description provided for @recordMeal.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get recordMeal;

  /// No description provided for @recordNap.
  ///
  /// In en, this message translates to:
  /// **'Nap'**
  String get recordNap;

  /// No description provided for @recordHygiene.
  ///
  /// In en, this message translates to:
  /// **'Hygiene'**
  String get recordHygiene;

  /// No description provided for @recordActivity.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get recordActivity;

  /// No description provided for @recordHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get recordHealth;

  /// No description provided for @recordVoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Record Voice Note'**
  String get recordVoiceButton;

  /// No description provided for @recordVoiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get recordVoiceListening;

  /// No description provided for @recordVoiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get recordVoiceStop;

  /// No description provided for @recordVoiceProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing voice note...'**
  String get recordVoiceProcessing;

  /// No description provided for @parentNavDaily.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get parentNavDaily;

  /// No description provided for @parentNavActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get parentNavActivities;

  /// No description provided for @parentNavRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get parentNavRequests;

  /// No description provided for @parentNavAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get parentNavAccount;

  /// No description provided for @parentChildProfile.
  ///
  /// In en, this message translates to:
  /// **'Child Profile'**
  String get parentChildProfile;

  /// No description provided for @parentLeaveRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Leave Request'**
  String get parentLeaveRequestButton;

  /// No description provided for @parentHealthNote.
  ///
  /// In en, this message translates to:
  /// **'Health Notes'**
  String get parentHealthNote;

  /// No description provided for @parentDailyReport.
  ///
  /// In en, this message translates to:
  /// **'Child\'s Daily Report'**
  String get parentDailyReport;

  /// No description provided for @parentPushNotification.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get parentPushNotification;

  /// No description provided for @parentPushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified when new daily reports are posted'**
  String get parentPushSubtitle;

  /// No description provided for @parentAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String parentAppVersion(String version);

  /// No description provided for @parentLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get parentLogoutConfirmTitle;

  /// No description provided for @bugReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a Bug'**
  String get bugReportTitle;

  /// No description provided for @bugReportNewButton.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get bugReportNewButton;

  /// No description provided for @bugReportAdminListButton.
  ///
  /// In en, this message translates to:
  /// **'Manage bug reports'**
  String get bugReportAdminListButton;

  /// No description provided for @bugReportFormTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get bugReportFormTitleLabel;

  /// No description provided for @bugReportFormTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe the issue (max 200 chars)'**
  String get bugReportFormTitleHint;

  /// No description provided for @bugReportFormDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get bugReportFormDescriptionLabel;

  /// No description provided for @bugReportFormDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Steps to reproduce, what you expected, what happened (max 4000 chars)'**
  String get bugReportFormDescriptionHint;

  /// No description provided for @bugReportFormCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get bugReportFormCategoryLabel;

  /// No description provided for @bugReportFormSeverityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get bugReportFormSeverityLabel;

  /// No description provided for @bugReportFormAttachmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get bugReportFormAttachmentsLabel;

  /// No description provided for @bugReportFormAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get bugReportFormAddAttachment;

  /// No description provided for @bugReportFormRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bugReportFormRemoveAttachment;

  /// No description provided for @bugReportFormSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get bugReportFormSubmit;

  /// No description provided for @bugReportFormSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get bugReportFormSubmitting;

  /// No description provided for @bugReportFormSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bug report submitted. Admin will review soon.'**
  String get bugReportFormSuccess;

  /// No description provided for @bugReportFormOfflineQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved locally. Will be sent when you are back online.'**
  String get bugReportFormOfflineQueued;

  /// No description provided for @bugReportFormValidationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please fill in title and description.'**
  String get bugReportFormValidationEmpty;

  /// No description provided for @bugReportFormValidationTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title must be at most 200 characters.'**
  String get bugReportFormValidationTitleTooLong;

  /// No description provided for @bugReportFormValidationDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description must be at most 4000 characters.'**
  String get bugReportFormValidationDescriptionTooLong;

  /// No description provided for @bugReportDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug Report Detail'**
  String get bugReportDetailTitle;

  /// No description provided for @bugReportDetailSectionMetadata.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get bugReportDetailSectionMetadata;

  /// No description provided for @bugReportDetailSectionAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get bugReportDetailSectionAttachments;

  /// No description provided for @bugReportDetailSectionHistory.
  ///
  /// In en, this message translates to:
  /// **'Status History'**
  String get bugReportDetailSectionHistory;

  /// No description provided for @bugReportDetailTapToZoom.
  ///
  /// In en, this message translates to:
  /// **'Tap to zoom'**
  String get bugReportDetailTapToZoom;

  /// No description provided for @bugReportAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Bug Reports (Admin)'**
  String get bugReportAdminTitle;

  /// No description provided for @bugReportAdminFilter.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get bugReportAdminFilter;

  /// No description provided for @bugReportAdminSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title...'**
  String get bugReportAdminSearchHint;

  /// No description provided for @bugReportAdminEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports match the current filter.'**
  String get bugReportAdminEmpty;

  /// No description provided for @bugReportAdminUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get bugReportAdminUpdateStatus;

  /// No description provided for @bugReportAdminNewStatus.
  ///
  /// In en, this message translates to:
  /// **'New status'**
  String get bugReportAdminNewStatus;

  /// No description provided for @bugReportAdminAssignee.
  ///
  /// In en, this message translates to:
  /// **'Assign to teacher'**
  String get bugReportAdminAssignee;

  /// No description provided for @bugReportAdminComment.
  ///
  /// In en, this message translates to:
  /// **'Internal comment'**
  String get bugReportAdminComment;

  /// No description provided for @bugReportAdminCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Visible to admin only (optional)'**
  String get bugReportAdminCommentHint;

  /// No description provided for @bugReportAdminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get bugReportAdminSave;

  /// No description provided for @bugReportAdminSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get bugReportAdminSaving;

  /// No description provided for @bugReportAdminSaved.
  ///
  /// In en, this message translates to:
  /// **'Report updated.'**
  String get bugReportAdminSaved;

  /// No description provided for @bugReportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get bugReportStatusOpen;

  /// No description provided for @bugReportStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get bugReportStatusInProgress;

  /// No description provided for @bugReportStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get bugReportStatusResolved;

  /// No description provided for @bugReportStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get bugReportStatusClosed;

  /// No description provided for @bugReportStatusWontFix.
  ///
  /// In en, this message translates to:
  /// **'Won\'t fix'**
  String get bugReportStatusWontFix;

  /// No description provided for @bugReportSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get bugReportSeverityLow;

  /// No description provided for @bugReportSeverityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get bugReportSeverityMedium;

  /// No description provided for @bugReportSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get bugReportSeverityHigh;

  /// No description provided for @bugReportSeverityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get bugReportSeverityCritical;

  /// No description provided for @bugReportCategoryUi.
  ///
  /// In en, this message translates to:
  /// **'UI'**
  String get bugReportCategoryUi;

  /// No description provided for @bugReportCategoryPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get bugReportCategoryPerformance;

  /// No description provided for @bugReportCategoryCrash.
  ///
  /// In en, this message translates to:
  /// **'Crash'**
  String get bugReportCategoryCrash;

  /// No description provided for @bugReportCategoryData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get bugReportCategoryData;

  /// No description provided for @bugReportCategoryNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get bugReportCategoryNotification;

  /// No description provided for @bugReportCategoryNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get bugReportCategoryNetwork;

  /// No description provided for @bugReportCategoryAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get bugReportCategoryAuth;

  /// No description provided for @bugReportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get bugReportCategoryOther;

  /// No description provided for @bugReportCommonAttachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No attachments} =1{1 attachment} other{{count} attachments}}'**
  String bugReportCommonAttachmentsCount(int count);

  /// No description provided for @bugReportCommonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get bugReportCommonRetry;

  /// No description provided for @bugReportCommonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bugReportCommonCancel;

  /// No description provided for @bugReportCommonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bugReportCommonClose;

  /// No description provided for @voiceChatRecordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send voice message'**
  String get voiceChatRecordTooltip;

  /// No description provided for @voiceChatCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording'**
  String get voiceChatCancelTooltip;

  /// No description provided for @voiceChatSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send voice message now'**
  String get voiceChatSendTooltip;

  /// No description provided for @voiceChatPermissionError.
  ///
  /// In en, this message translates to:
  /// **'App needs microphone permission to record voice messages.'**
  String get voiceChatPermissionError;

  /// No description provided for @voiceChatStartError.
  ///
  /// In en, this message translates to:
  /// **'Cannot start recording. Please try again.'**
  String get voiceChatStartError;

  /// No description provided for @voiceChatSendError.
  ///
  /// In en, this message translates to:
  /// **'Error sending voice recording. Please try again.'**
  String get voiceChatSendError;

  /// No description provided for @voiceChatLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load audio'**
  String get voiceChatLoadError;

  /// No description provided for @voiceChatDefaultContent.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceChatDefaultContent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
