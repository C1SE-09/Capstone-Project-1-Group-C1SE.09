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

  /// No description provided for @teacherAccountPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get teacherAccountPreferences;

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

  /// No description provided for @parentGreetingGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get parentGreetingGoodMorning;

  /// No description provided for @parentTodayReport.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Report'**
  String get parentTodayReport;

  /// No description provided for @parentNoReportToday.
  ///
  /// In en, this message translates to:
  /// **'No report for today yet.'**
  String get parentNoReportToday;

  /// No description provided for @parentNoAttendanceToday.
  ///
  /// In en, this message translates to:
  /// **'No attendance update for today'**
  String get parentNoAttendanceToday;

  /// No description provided for @parentAllergyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Allergy: {allergy}'**
  String parentAllergyPrefix(String allergy);

  /// No description provided for @parentTeacherNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note from {teacherName}'**
  String parentTeacherNoteTitle(String teacherName);

  /// No description provided for @parentTimetableShortcut.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get parentTimetableShortcut;

  /// No description provided for @parentRequestsShortcut.
  ///
  /// In en, this message translates to:
  /// **'Leave · Late'**
  String get parentRequestsShortcut;

  /// No description provided for @parentUnreadReportsBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No unread reports} =1{1 unread report} other{{count} unread reports}}'**
  String parentUnreadReportsBadge(int count);

  /// No description provided for @parentLoadDataError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load parent data.'**
  String get parentLoadDataError;

  /// No description provided for @parentOpenReportError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this report. Please try again later.'**
  String get parentOpenReportError;

  /// No description provided for @parentNoDataForDay.
  ///
  /// In en, this message translates to:
  /// **'No recorded data for this day.'**
  String get parentNoDataForDay;

  /// No description provided for @parentDailyReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get parentDailyReportTitle;

  /// No description provided for @recordMealItem.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get recordMealItem;

  /// No description provided for @recordNapItem.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get recordNapItem;

  /// No description provided for @recordActivityItem.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get recordActivityItem;

  /// No description provided for @commonNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get commonNotUpdated;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @parentSectionFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get parentSectionFamily;

  /// No description provided for @parentContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get parentContactInfo;

  /// No description provided for @parentChildHealthProfile.
  ///
  /// In en, this message translates to:
  /// **'Child Details · Health Profile'**
  String get parentChildHealthProfile;

  /// No description provided for @parentAllergyCareNotes.
  ///
  /// In en, this message translates to:
  /// **'Allergies & Care Notes'**
  String get parentAllergyCareNotes;

  /// No description provided for @parentSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get parentSectionPreferences;

  /// No description provided for @parentPushEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled on device'**
  String get parentPushEnabled;

  /// No description provided for @parentPushDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled on device'**
  String get parentPushDisabled;

  /// No description provided for @parentFamilySummary.
  ///
  /// In en, this message translates to:
  /// **'Family has {count, plural, =1{1 enrolled child} other{{count} enrolled children}}'**
  String parentFamilySummary(int count);

  /// No description provided for @parentSelectChild.
  ///
  /// In en, this message translates to:
  /// **'Select Child'**
  String get parentSelectChild;

  /// No description provided for @parentSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get parentSelected;

  /// No description provided for @parentDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get parentDateOfBirth;

  /// No description provided for @parentNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname: {nickname}'**
  String parentNickname(String nickname);

  /// No description provided for @parentViewDetail.
  ///
  /// In en, this message translates to:
  /// **'View ›'**
  String get parentViewDetail;

  /// No description provided for @parentReadReport.
  ///
  /// In en, this message translates to:
  /// **'Read report ›'**
  String get parentReadReport;

  /// No description provided for @parentCopyPhoneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy phone number'**
  String get parentCopyPhoneTooltip;

  /// No description provided for @parentCopiedPhoneSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Phone number copied'**
  String get parentCopiedPhoneSnackbar;

  /// No description provided for @parentAccountChildPrefix.
  ///
  /// In en, this message translates to:
  /// **'Parent account of {childName}'**
  String parentAccountChildPrefix(String childName);

  /// No description provided for @parentFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get parentFullNameLabel;

  /// No description provided for @parentRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Role / Relationship'**
  String get parentRelationshipLabel;

  /// No description provided for @parentNoAllergyRecorded.
  ///
  /// In en, this message translates to:
  /// **'No allergies recorded'**
  String get parentNoAllergyRecorded;

  /// No description provided for @parentHasAllergy.
  ///
  /// In en, this message translates to:
  /// **'Has allergies'**
  String get parentHasAllergy;

  /// No description provided for @parentNoAllergy.
  ///
  /// In en, this message translates to:
  /// **'No allergies'**
  String get parentNoAllergy;

  /// No description provided for @parentAllergyNotDeclared.
  ///
  /// In en, this message translates to:
  /// **'Not declared'**
  String get parentAllergyNotDeclared;

  /// No description provided for @parentJourneyDaysText.
  ///
  /// In en, this message translates to:
  /// **'{days} days journeying with KinderLog'**
  String parentJourneyDaysText(int days);

  /// No description provided for @parentEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get parentEditInfo;

  /// No description provided for @parentEditContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Contact Information'**
  String get parentEditContactInfo;

  /// No description provided for @parentHealthChangeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change allergy information?'**
  String get parentHealthChangeConfirmTitle;

  /// No description provided for @parentHealthChangeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Existing allergy information will be overwritten after saving.'**
  String get parentHealthChangeConfirmMessage;

  /// No description provided for @parentHealthContinueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get parentHealthContinueEditing;

  /// No description provided for @parentHealthDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get parentHealthDiscardTitle;

  /// No description provided for @parentHealthDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes you just made will not be saved.'**
  String get parentHealthDiscardMessage;

  /// No description provided for @parentHealthDiscardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get parentHealthDiscardAction;

  /// No description provided for @parentHealthUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Health information updated'**
  String get parentHealthUpdateSuccess;

  /// No description provided for @parentHealthLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load health profile.'**
  String get parentHealthLoadError;

  /// No description provided for @parentHealthAllergyStatus.
  ///
  /// In en, this message translates to:
  /// **'Allergy Status'**
  String get parentHealthAllergyStatus;

  /// No description provided for @parentHealthCareNotes.
  ///
  /// In en, this message translates to:
  /// **'Care Notes'**
  String get parentHealthCareNotes;

  /// No description provided for @teacherGreetingGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get teacherGreetingGoodMorning;

  /// No description provided for @teacherAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get teacherAttentionTitle;

  /// No description provided for @teacherNoAttentionToday.
  ///
  /// In en, this message translates to:
  /// **'No special notes today.'**
  String get teacherNoAttentionToday;

  /// No description provided for @teacherRecordBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Record the day\nfor children'**
  String get teacherRecordBannerTitle;

  /// No description provided for @teacherRecordBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Meals, nap, activities and care notes.'**
  String get teacherRecordBannerSubtitle;

  /// No description provided for @teacherStartReport.
  ///
  /// In en, this message translates to:
  /// **'Start Daily Report'**
  String get teacherStartReport;

  /// No description provided for @teacherTodayAttendance.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Attendance'**
  String get teacherTodayAttendance;

  /// No description provided for @teacherReportIncident.
  ///
  /// In en, this message translates to:
  /// **'Incident'**
  String get teacherReportIncident;

  /// No description provided for @teacherSendToParents.
  ///
  /// In en, this message translates to:
  /// **'Send to Parents'**
  String get teacherSendToParents;

  /// No description provided for @teacherSearchChildHint.
  ///
  /// In en, this message translates to:
  /// **'Search child name...'**
  String get teacherSearchChildHint;

  /// No description provided for @teacherNoChildrenFound.
  ///
  /// In en, this message translates to:
  /// **'No matching children found'**
  String get teacherNoChildrenFound;

  /// No description provided for @teacherOverviewLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load overview · Retry'**
  String get teacherOverviewLoadError;

  /// No description provided for @teacherNoSchoolInfo.
  ///
  /// In en, this message translates to:
  /// **'School info unavailable'**
  String get teacherNoSchoolInfo;

  /// No description provided for @attendanceSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Attendance'**
  String get attendanceSaveButton;

  /// No description provided for @attendanceDiscardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard attendance changes?'**
  String get attendanceDiscardConfirmTitle;

  /// No description provided for @attendanceDiscardConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes on attendance cards will not be saved.'**
  String get attendanceDiscardConfirmMessage;

  /// No description provided for @attendanceContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Attendance'**
  String get attendanceContinue;

  /// No description provided for @attendanceDiscardAction.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get attendanceDiscardAction;

  /// No description provided for @dayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dayMonday;

  /// No description provided for @dayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dayTuesday;

  /// No description provided for @dayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dayWednesday;

  /// No description provided for @dayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dayThursday;

  /// No description provided for @dayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dayFriday;

  /// No description provided for @daySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get daySaturday;

  /// No description provided for @daySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get daySunday;

  /// No description provided for @dayShortMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayShortMon;

  /// No description provided for @dayShortTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayShortTue;

  /// No description provided for @dayShortWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayShortWed;

  /// No description provided for @dayShortThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayShortThu;

  /// No description provided for @dayShortFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayShortFri;

  /// No description provided for @dayShortSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get dayShortSat;

  /// No description provided for @dayShortSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get dayShortSun;

  /// No description provided for @timetableMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get timetableMorning;

  /// No description provided for @timetableAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get timetableAfternoon;

  /// No description provided for @timetableEmpty.
  ///
  /// In en, this message translates to:
  /// **'No classes scheduled'**
  String get timetableEmpty;

  /// No description provided for @parentRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave / Late Requests'**
  String get parentRequestsTitle;

  /// No description provided for @parentRequestsNew.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get parentRequestsNew;

  /// No description provided for @leaveRequestsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get leaveRequestsCancelled;

  /// No description provided for @leaveTypeAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get leaveTypeAbsent;

  /// No description provided for @leaveTypeLate.
  ///
  /// In en, this message translates to:
  /// **'Late Arrival'**
  String get leaveTypeLate;

  /// No description provided for @parentRequestsFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Leave / Late Request'**
  String get parentRequestsFormTitle;

  /// No description provided for @parentRequestsTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Type'**
  String get parentRequestsTypeLabel;

  /// No description provided for @parentRequestsFromDate.
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get parentRequestsFromDate;

  /// No description provided for @parentRequestsToDate.
  ///
  /// In en, this message translates to:
  /// **'To Date'**
  String get parentRequestsToDate;

  /// No description provided for @parentRequestsLateDate.
  ///
  /// In en, this message translates to:
  /// **'Late Date'**
  String get parentRequestsLateDate;

  /// No description provided for @parentRequestsExpectedTime.
  ///
  /// In en, this message translates to:
  /// **'Expected Arrival Time'**
  String get parentRequestsExpectedTime;

  /// No description provided for @parentRequestsReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get parentRequestsReasonLabel;

  /// No description provided for @parentRequestsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get parentRequestsSubmit;

  /// No description provided for @aboutAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Kindergarten Communication & Reporting'**
  String get aboutAppTagline;

  /// No description provided for @aboutAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive administrative & digital connection between School · Teachers · Parents.'**
  String get aboutAppDescription;

  /// No description provided for @voiceChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a reply...'**
  String get voiceChatInputHint;

  /// No description provided for @voiceChatRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get voiceChatRecording;

  /// No description provided for @voiceChatSendReply.
  ///
  /// In en, this message translates to:
  /// **'Send reply'**
  String get voiceChatSendReply;
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
