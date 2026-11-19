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
  /// **'Password confirmation does not match.'**
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
  /// **'Login email'**
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

  /// No description provided for @authRememberSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Logged in, but could not save your remember choice. Please try again on this device; web requires HTTPS or localhost.'**
  String get authRememberSnackBar;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password via email'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1/3 · Enter email'**
  String get forgotPasswordStep1;

  /// No description provided for @forgotPasswordStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email. KinderLog will send a confirmation code for you to reset your password.'**
  String get forgotPasswordStep1Desc;

  /// No description provided for @forgotPasswordStep2.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP Code'**
  String get forgotPasswordStep2;

  /// No description provided for @forgotPasswordStep3.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get forgotPasswordStep3;

  /// No description provided for @forgotPasswordEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get forgotPasswordEmailInvalid;

  /// No description provided for @forgotPasswordSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send confirmation code'**
  String get forgotPasswordSendCode;

  /// No description provided for @forgotPasswordSendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending code...'**
  String get forgotPasswordSendingCode;

  /// No description provided for @forgotPasswordResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get forgotPasswordResendCode;

  /// No description provided for @forgotPasswordResendAfter.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String forgotPasswordResendAfter(Object seconds);

  /// No description provided for @forgotPasswordOtpLengthError.
  ///
  /// In en, this message translates to:
  /// **'Please enter all 6 digits of the verification code.'**
  String get forgotPasswordOtpLengthError;

  /// No description provided for @forgotPasswordOtpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification code accepted! Please create a new password.'**
  String get forgotPasswordOtpSuccess;

  /// No description provided for @forgotPasswordOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired verification code. Please check again.'**
  String get forgotPasswordOtpInvalid;

  /// No description provided for @forgotPasswordPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'New password must have at least 6 characters.'**
  String get forgotPasswordPasswordMinLength;

  /// No description provided for @forgotPasswordPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Password confirmation does not match.'**
  String get forgotPasswordPasswordMismatch;

  /// No description provided for @forgotPasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get forgotPasswordSuccessTitle;

  /// No description provided for @forgotPasswordSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully. Please log in with your new password.'**
  String get forgotPasswordSuccessDesc;

  /// No description provided for @forgotPasswordLoginNow.
  ///
  /// In en, this message translates to:
  /// **'LOG IN NOW'**
  String get forgotPasswordLoginNow;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotPasswordNewPasswordLabel;

  /// No description provided for @forgotPasswordNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get forgotPasswordNewPasswordHint;

  /// No description provided for @forgotPasswordConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get forgotPasswordConfirmPasswordLabel;

  /// No description provided for @forgotPasswordConfirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get forgotPasswordConfirmPasswordHint;

  /// No description provided for @forgotPasswordUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'UPDATE PASSWORD'**
  String get forgotPasswordUpdateButton;

  /// No description provided for @forgotPasswordCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check email {email}'**
  String forgotPasswordCheckEmail(Object email);

  /// No description provided for @forgotPasswordOtpHelp.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code (Valid for 5 minutes)'**
  String get forgotPasswordOtpHelp;

  /// No description provided for @forgotPasswordChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Use another email'**
  String get forgotPasswordChangeEmail;

  /// No description provided for @forgotPasswordConfirmOtp.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM OTP'**
  String get forgotPasswordConfirmOtp;

  /// No description provided for @forgotPasswordErrorSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset password request. Please check your internet connection or try again later.'**
  String get forgotPasswordErrorSendFailed;

  /// No description provided for @forgotPasswordErrorResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot resend verification code right now. Please try again in a few minutes.'**
  String get forgotPasswordErrorResendFailed;

  /// No description provided for @forgotPasswordErrorResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset was unsuccessful. Please try again in a few minutes.'**
  String get forgotPasswordErrorResetFailed;

  /// No description provided for @forgotPasswordSpamHelp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Check your spam folder, or wait 60 seconds to resend.'**
  String get forgotPasswordSpamHelp;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your KinderLog account'**
  String get changePasswordSubtitle;

  /// No description provided for @changePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// No description provided for @changePasswordCurrentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password.'**
  String get changePasswordCurrentEmpty;

  /// No description provided for @changePasswordNewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new password.'**
  String get changePasswordNewEmpty;

  /// No description provided for @changePasswordNewMinLength.
  ///
  /// In en, this message translates to:
  /// **'New password must have at least 6 characters.'**
  String get changePasswordNewMinLength;

  /// No description provided for @changePasswordConfirmEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password.'**
  String get changePasswordConfirmEmpty;

  /// No description provided for @changePasswordSameAsCurrent.
  ///
  /// In en, this message translates to:
  /// **'New password cannot be the same as current password.'**
  String get changePasswordSameAsCurrent;

  /// No description provided for @changePasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot change password right now. Please try again in a few minutes.'**
  String get changePasswordFailed;

  /// No description provided for @changePasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'New password requirements'**
  String get changePasswordRequirements;

  /// No description provided for @changePasswordReqMinLength.
  ///
  /// In en, this message translates to:
  /// **'· Minimum 6 characters'**
  String get changePasswordReqMinLength;

  /// No description provided for @changePasswordLogoutOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'Log out of other devices'**
  String get changePasswordLogoutOtherDevices;

  /// No description provided for @changePasswordLogoutOtherDevicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Other devices will need to log in again.'**
  String get changePasswordLogoutOtherDevicesDesc;

  /// No description provided for @changePasswordSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get changePasswordSaveButton;

  /// No description provided for @noAssignmentClassIcon.
  ///
  /// In en, this message translates to:
  /// **'Class group icon'**
  String get noAssignmentClassIcon;

  /// No description provided for @relationFather.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get relationFather;

  /// No description provided for @relationMother.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get relationMother;

  /// No description provided for @relationGrandpa.
  ///
  /// In en, this message translates to:
  /// **'Grandfather'**
  String get relationGrandpa;

  /// No description provided for @relationGrandma.
  ///
  /// In en, this message translates to:
  /// **'Grandmother'**
  String get relationGrandma;

  /// No description provided for @relationGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get relationGuardian;

  /// No description provided for @relationTitle.
  ///
  /// In en, this message translates to:
  /// **'Relationship with child'**
  String get relationTitle;

  /// No description provided for @relationSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select relationship'**
  String get relationSelectTitle;

  /// No description provided for @genderBoy.
  ///
  /// In en, this message translates to:
  /// **'Boy (Male)'**
  String get genderBoy;

  /// No description provided for @genderGirl.
  ///
  /// In en, this message translates to:
  /// **'Girl (Female)'**
  String get genderGirl;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @childInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Information'**
  String get childInfoTitle;

  /// No description provided for @childEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit child info'**
  String get childEditInfo;

  /// No description provided for @childNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get childNotUpdated;

  /// No description provided for @childSelectDob.
  ///
  /// In en, this message translates to:
  /// **'Select child\'s date of birth'**
  String get childSelectDob;

  /// No description provided for @healthAllergyYes.
  ///
  /// In en, this message translates to:
  /// **'Has allergies'**
  String get healthAllergyYes;

  /// No description provided for @healthAllergyNone.
  ///
  /// In en, this message translates to:
  /// **'No recorded allergies'**
  String get healthAllergyNone;

  /// No description provided for @healthAllergyUndeclared.
  ///
  /// In en, this message translates to:
  /// **'Allergies not declared'**
  String get healthAllergyUndeclared;

  /// No description provided for @healthUndeclared.
  ///
  /// In en, this message translates to:
  /// **'Not declared'**
  String get healthUndeclared;

  /// No description provided for @healthProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes'**
  String get healthProfileSaveFailed;

  /// No description provided for @healthProfileSaveFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Please check your network and try again. Your input has been preserved.'**
  String get healthProfileSaveFailedDesc;

  /// No description provided for @requestExpectedArrival.
  ///
  /// In en, this message translates to:
  /// **'Expected arrival time'**
  String get requestExpectedArrival;

  /// No description provided for @requestFromDate.
  ///
  /// In en, this message translates to:
  /// **'From date'**
  String get requestFromDate;

  /// No description provided for @requestToDate.
  ///
  /// In en, this message translates to:
  /// **'To date'**
  String get requestToDate;

  /// No description provided for @requestLateDate.
  ///
  /// In en, this message translates to:
  /// **'Late arrival date'**
  String get requestLateDate;

  /// No description provided for @requestSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get requestSelectDate;

  /// No description provided for @requestType.
  ///
  /// In en, this message translates to:
  /// **'Request type'**
  String get requestType;

  /// No description provided for @requestDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get requestDiscardTitle;

  /// No description provided for @requestDiscardDesc.
  ///
  /// In en, this message translates to:
  /// **'Unsubmitted request content will not be saved.'**
  String get requestDiscardDesc;

  /// No description provided for @requestKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get requestKeepEditing;

  /// No description provided for @requestDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get requestDiscardConfirm;

  /// No description provided for @requestNoClassWarning.
  ///
  /// In en, this message translates to:
  /// **'No class information assigned yet. Please contact the school.'**
  String get requestNoClassWarning;

  /// No description provided for @requestDateRangeHelp.
  ///
  /// In en, this message translates to:
  /// **'Select future dates and times; max 366 days per request.'**
  String get requestDateRangeHelp;

  /// No description provided for @requestMealWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitting after 7:30 AM'**
  String get requestMealWarningTitle;

  /// No description provided for @requestMealWarningConfirm.
  ///
  /// In en, this message translates to:
  /// **'Agree & Submit'**
  String get requestMealWarningConfirm;

  /// No description provided for @requestSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit request. Content is kept for you to retry.'**
  String get requestSaveFailed;

  /// No description provided for @requestFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load requests. Please try again.'**
  String get requestFetchFailed;

  /// No description provided for @requestLoadingList.
  ///
  /// In en, this message translates to:
  /// **'Loading requests...'**
  String get requestLoadingList;

  /// No description provided for @requestEmptyList.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get requestEmptyList;

  /// No description provided for @requestLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get requestLoadMore;

  /// No description provided for @requestCreateNew.
  ///
  /// In en, this message translates to:
  /// **'CREATE NEW REQUEST'**
  String get requestCreateNew;

  /// No description provided for @requestSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request submitted successfully'**
  String get requestSubmittedSuccess;

  /// No description provided for @requestStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get requestStatus;

  /// No description provided for @requestPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Request submitted, pending review. You will be notified when teacher approves.'**
  String get requestPendingNote;

  /// No description provided for @requestHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Request submitted. View history to track latest review status.'**
  String get requestHistoryNote;

  /// No description provided for @requestViewMyRequests.
  ///
  /// In en, this message translates to:
  /// **'VIEW MY REQUESTS'**
  String get requestViewMyRequests;

  /// No description provided for @requestBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get requestBackHome;

  /// No description provided for @requestTeacherApproved.
  ///
  /// In en, this message translates to:
  /// **'Teacher approved'**
  String get requestTeacherApproved;

  /// No description provided for @requestTeacherRejected.
  ///
  /// In en, this message translates to:
  /// **'Teacher rejected'**
  String get requestTeacherRejected;

  /// No description provided for @requestParentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Parent cancelled request'**
  String get requestParentCancelled;

  /// No description provided for @requestTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get requestTimeLabel;

  /// No description provided for @contactEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Contact Information'**
  String get contactEditTitle;

  /// No description provided for @contactEditDesc.
  ///
  /// In en, this message translates to:
  /// **'Update contact info for school communication when needed.'**
  String get contactEditDesc;

  /// No description provided for @contactPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number *'**
  String get contactPhoneLabel;

  /// No description provided for @contactPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'10 digits, starting with 0'**
  String get contactPhoneHint;

  /// No description provided for @contactEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address. Please check again.'**
  String get contactEmailInvalid;

  /// No description provided for @contactSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Parent info saved successfully'**
  String get contactSaveSuccess;

  /// No description provided for @contactSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save information, please try again.'**
  String get contactSaveFailed;

  /// No description provided for @notificationsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsAll;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsReport.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get notificationsReport;

  /// No description provided for @notificationsReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No new reports.'**
  String get notificationsReportEmpty;

  /// No description provided for @notificationsHealthEmpty.
  ///
  /// In en, this message translates to:
  /// **'No health notifications.'**
  String get notificationsHealthEmpty;

  /// No description provided for @notificationsLeaveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No new leave requests.'**
  String get notificationsLeaveEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notificationsNew;

  /// No description provided for @notificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// No description provided for @commonAllChildren.
  ///
  /// In en, this message translates to:
  /// **'All children'**
  String get commonAllChildren;

  /// No description provided for @commonClassroom.
  ///
  /// In en, this message translates to:
  /// **'CLASSROOM'**
  String get commonClassroom;

  /// No description provided for @commonClass.
  ///
  /// In en, this message translates to:
  /// **'CLASS'**
  String get commonClass;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commonSaveChanges;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get commonSending;

  /// No description provided for @commonSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get commonSent;

  /// No description provided for @commonRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get commonRead;

  /// No description provided for @commonDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get commonDraft;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get commonEarlier;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get commonMorning;

  /// No description provided for @commonAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get commonAfternoon;

  /// No description provided for @commonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get commonOther;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonEmpty;

  /// No description provided for @entityParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get entityParent;

  /// No description provided for @entityTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get entityTeacher;

  /// No description provided for @entityHeadTeacher.
  ///
  /// In en, this message translates to:
  /// **'Head teacher'**
  String get entityHeadTeacher;

  /// No description provided for @entityStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get entityStudent;

  /// No description provided for @entityChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get entityChildren;

  /// No description provided for @entityChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get entityChild;

  /// No description provided for @entityClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get entityClass;

  /// No description provided for @entityClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get entityClassroom;

  /// No description provided for @entitySchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get entitySchool;

  /// No description provided for @entityPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get entityPhoneNumber;

  /// No description provided for @entityEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get entityEmail;

  /// No description provided for @entityDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get entityDateOfBirth;

  /// No description provided for @entityGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get entityGender;

  /// No description provided for @entityAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get entityAddress;

  /// No description provided for @attendanceListTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance List'**
  String get attendanceListTitle;

  /// No description provided for @attendanceStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get attendanceStatusArrived;

  /// No description provided for @attendanceStatusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceStatusAbsent;

  /// No description provided for @attendanceStatusExcused.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get attendanceStatusExcused;

  /// No description provided for @attendanceStatusLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceStatusLate;

  /// No description provided for @attendanceStatusOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get attendanceStatusOnTime;

  /// No description provided for @attendanceSendAbsentAlert.
  ///
  /// In en, this message translates to:
  /// **'Send absent notification'**
  String get attendanceSendAbsentAlert;

  /// No description provided for @attendanceSendAbsentAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Send absent notification?'**
  String get attendanceSendAbsentAlertTitle;

  /// No description provided for @attendanceSendAlert.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get attendanceSendAlert;

  /// No description provided for @attendanceClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get attendanceClearSearch;

  /// No description provided for @attendanceNoMatchingStudent.
  ///
  /// In en, this message translates to:
  /// **'No matching students found.'**
  String get attendanceNoMatchingStudent;

  /// No description provided for @attendanceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save attendance. Please try again later.'**
  String get attendanceSaveFailed;

  /// No description provided for @attendanceNoDataForDay.
  ///
  /// In en, this message translates to:
  /// **'No attendance data for this day.'**
  String get attendanceNoDataForDay;

  /// No description provided for @attendanceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load attendance for the selected date.'**
  String get attendanceLoadFailed;

  /// No description provided for @attendanceViewClassRequests.
  ///
  /// In en, this message translates to:
  /// **'View class leave requests'**
  String get attendanceViewClassRequests;

  /// No description provided for @attendanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get attendanceUpdated;

  /// No description provided for @attendancePrevDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get attendancePrevDay;

  /// No description provided for @attendanceNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get attendanceNextDay;

  /// No description provided for @timetableTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get timetableTitle;

  /// No description provided for @timetableInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get timetableInProgress;

  /// No description provided for @timetableUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get timetableUpcoming;

  /// No description provided for @timetableDayView.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get timetableDayView;

  /// No description provided for @timetableWeekView.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get timetableWeekView;

  /// No description provided for @timetableNoActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get timetableNoActivities;

  /// No description provided for @timetableTimeConflict.
  ///
  /// In en, this message translates to:
  /// **'Time slot conflict'**
  String get timetableTimeConflict;

  /// No description provided for @timetableAddActivity.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get timetableAddActivity;

  /// No description provided for @timetableEditActivity.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get timetableEditActivity;

  /// No description provided for @timetableActivityAdded.
  ///
  /// In en, this message translates to:
  /// **'Activity added'**
  String get timetableActivityAdded;

  /// No description provided for @timetableActivityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Activity updated'**
  String get timetableActivityUpdated;

  /// No description provided for @timetableActivityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity deleted'**
  String get timetableActivityDeleted;

  /// No description provided for @timetableSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save activity. Please try again.'**
  String get timetableSaveFailed;

  /// No description provided for @timetableDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete activity. Please try again.'**
  String get timetableDeleteFailed;

  /// No description provided for @timetableNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter activity name.'**
  String get timetableNameRequired;

  /// No description provided for @timetableSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a subject / activity.'**
  String get timetableSubjectRequired;

  /// No description provided for @timetableSlotRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a time slot.'**
  String get timetableSlotRequired;

  /// No description provided for @timetableTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Time slot'**
  String get timetableTimeSlot;

  /// No description provided for @timetableSubjectOrActivity.
  ///
  /// In en, this message translates to:
  /// **'Subject / Activity'**
  String get timetableSubjectOrActivity;

  /// No description provided for @timetableRoomOptional.
  ///
  /// In en, this message translates to:
  /// **'Room (optional)'**
  String get timetableRoomOptional;

  /// No description provided for @timetableMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get timetableMeals;

  /// No description provided for @timetableCreativeActivities.
  ///
  /// In en, this message translates to:
  /// **'Creative activities'**
  String get timetableCreativeActivities;

  /// No description provided for @timetableOutdoorActivities.
  ///
  /// In en, this message translates to:
  /// **'Outdoor activities'**
  String get timetableOutdoorActivities;

  /// No description provided for @timetableSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get timetableSleep;

  /// No description provided for @timetableHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get timetableHealth;

  /// No description provided for @subjectMath.
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get subjectMath;

  /// No description provided for @subjectLiterature.
  ///
  /// In en, this message translates to:
  /// **'Literature'**
  String get subjectLiterature;

  /// No description provided for @subjectForeignLanguage.
  ///
  /// In en, this message translates to:
  /// **'Foreign Language'**
  String get subjectForeignLanguage;

  /// No description provided for @subjectMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get subjectMusic;

  /// No description provided for @subjectArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get subjectArt;

  /// No description provided for @subjectPE.
  ///
  /// In en, this message translates to:
  /// **'Physical Education'**
  String get subjectPE;

  /// No description provided for @incidentReport.
  ///
  /// In en, this message translates to:
  /// **'Report incident'**
  String get incidentReport;

  /// No description provided for @incidentNotifyParentsSchool.
  ///
  /// In en, this message translates to:
  /// **'Notify parents and school'**
  String get incidentNotifyParentsSchool;

  /// No description provided for @incidentType.
  ///
  /// In en, this message translates to:
  /// **'Incident type'**
  String get incidentType;

  /// No description provided for @incidentDescription.
  ///
  /// In en, this message translates to:
  /// **'Incident description'**
  String get incidentDescription;

  /// No description provided for @incidentSendEmergencyAlert.
  ///
  /// In en, this message translates to:
  /// **'Send emergency alert'**
  String get incidentSendEmergencyAlert;

  /// No description provided for @incidentCallParent.
  ///
  /// In en, this message translates to:
  /// **'Call parent'**
  String get incidentCallParent;

  /// No description provided for @incidentCallParentNow.
  ///
  /// In en, this message translates to:
  /// **'Call parent now'**
  String get incidentCallParentNow;

  /// No description provided for @incidentHighFever.
  ///
  /// In en, this message translates to:
  /// **'High fever'**
  String get incidentHighFever;

  /// No description provided for @incidentFallAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident / Fall'**
  String get incidentFallAccident;

  /// No description provided for @incidentAcuteAllergy.
  ///
  /// In en, this message translates to:
  /// **'Acute allergy'**
  String get incidentAcuteAllergy;

  /// No description provided for @incidentStudentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a student.'**
  String get incidentStudentRequired;

  /// No description provided for @incidentTempInvalid.
  ///
  /// In en, this message translates to:
  /// **'Temperature must be between 34°C and 44°C.'**
  String get incidentTempInvalid;

  /// No description provided for @incidentNoValidPhone.
  ///
  /// In en, this message translates to:
  /// **'No valid phone number in emergency contacts.'**
  String get incidentNoValidPhone;

  /// No description provided for @incidentSelectParentToCall.
  ///
  /// In en, this message translates to:
  /// **'Select parent to call'**
  String get incidentSelectParentToCall;

  /// No description provided for @incidentTempOptional.
  ///
  /// In en, this message translates to:
  /// **'Temperature (optional)'**
  String get incidentTempOptional;

  /// No description provided for @incidentRecipients.
  ///
  /// In en, this message translates to:
  /// **'Alert recipients'**
  String get incidentRecipients;

  /// No description provided for @incidentReloadContacts.
  ///
  /// In en, this message translates to:
  /// **'Reload contacts'**
  String get incidentReloadContacts;

  /// No description provided for @incidentRecordSaved.
  ///
  /// In en, this message translates to:
  /// **'Incident record saved'**
  String get incidentRecordSaved;

  /// No description provided for @incidentSelectStudent.
  ///
  /// In en, this message translates to:
  /// **'Select student'**
  String get incidentSelectStudent;

  /// No description provided for @incidentSelectStudentEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Select student...'**
  String get incidentSelectStudentEllipsis;

  /// No description provided for @incidentSearchStudentHint.
  ///
  /// In en, this message translates to:
  /// **'Search by child name or nickname...'**
  String get incidentSearchStudentHint;

  /// No description provided for @incidentChangeChild.
  ///
  /// In en, this message translates to:
  /// **'Change child'**
  String get incidentChangeChild;

  /// No description provided for @sttTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing speech to text…'**
  String get sttTranscribing;

  /// No description provided for @sttFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition failed'**
  String get sttFailed;

  /// No description provided for @sttNoText.
  ///
  /// In en, this message translates to:
  /// **'No text content yet'**
  String get sttNoText;

  /// No description provided for @sttDeleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete this recording'**
  String get sttDeleteRecording;

  /// No description provided for @sttCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get sttCollapse;

  /// No description provided for @sttExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand spoken content'**
  String get sttExpand;

  /// No description provided for @sttSpokenContent.
  ///
  /// In en, this message translates to:
  /// **'Spoken content'**
  String get sttSpokenContent;

  /// No description provided for @sttSegmentContent.
  ///
  /// In en, this message translates to:
  /// **'Segment content'**
  String get sttSegmentContent;

  /// No description provided for @sttAnalyzedText.
  ///
  /// In en, this message translates to:
  /// **'Analyzed text'**
  String get sttAnalyzedText;

  /// No description provided for @sttEditAndReanalyze.
  ///
  /// In en, this message translates to:
  /// **'Edit & Reanalyze'**
  String get sttEditAndReanalyze;

  /// No description provided for @sttOriginalAudio.
  ///
  /// In en, this message translates to:
  /// **'Original recording'**
  String get sttOriginalAudio;

  /// No description provided for @sttAudioProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording playback progress'**
  String get sttAudioProgress;

  /// No description provided for @sttSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sent successfully.'**
  String get sttSubmittedSuccess;

  /// No description provided for @sttNoNeedToReenter.
  ///
  /// In en, this message translates to:
  /// **'Nothing more to enter. Reports have been sent to parents.'**
  String get sttNoNeedToReenter;

  /// No description provided for @sttListenAgain.
  ///
  /// In en, this message translates to:
  /// **'Listen to recording again'**
  String get sttListenAgain;

  /// No description provided for @sttBackToClassOverview.
  ///
  /// In en, this message translates to:
  /// **'Back to class overview'**
  String get sttBackToClassOverview;

  /// No description provided for @sttEditReport.
  ///
  /// In en, this message translates to:
  /// **'Edit report'**
  String get sttEditReport;

  /// No description provided for @sttDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get sttDurationMinutes;

  /// No description provided for @sttParentReportsLabel.
  ///
  /// In en, this message translates to:
  /// **'communication books for parents'**
  String get sttParentReportsLabel;

  /// No description provided for @sttHealthRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'entries in health record'**
  String get sttHealthRecordsLabel;

  /// No description provided for @sttRecordForChild.
  ///
  /// In en, this message translates to:
  /// **'Record for child'**
  String get sttRecordForChild;

  /// No description provided for @sttComposeReport.
  ///
  /// In en, this message translates to:
  /// **'Compose report'**
  String get sttComposeReport;

  /// No description provided for @sttDailyObservation.
  ///
  /// In en, this message translates to:
  /// **'Daily observation'**
  String get sttDailyObservation;

  /// No description provided for @sttNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get sttNotRecorded;

  /// No description provided for @sttRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get sttRecorded;

  /// No description provided for @leaveReviewRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get leaveReviewRejectTitle;

  /// No description provided for @leaveReviewRejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason *'**
  String get leaveReviewRejectReasonLabel;

  /// No description provided for @leaveReviewRejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter specific reason so parents understand'**
  String get leaveReviewRejectReasonHint;

  /// No description provided for @leaveReviewRejectReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'Reason required (2–500 chars). Parents will see this in request details.'**
  String get leaveReviewRejectReasonHelp;

  /// No description provided for @leaveReviewRejectSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rejection'**
  String get leaveReviewRejectSubmit;

  /// No description provided for @leaveReviewApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve request'**
  String get leaveReviewApproveTitle;

  /// No description provided for @leaveReviewApproveBtn.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get leaveReviewApproveBtn;

  /// No description provided for @leaveReviewRejectBtn.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get leaveReviewRejectBtn;

  /// No description provided for @leaveReviewRejectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request rejected. Parents can view the reason in app.'**
  String get leaveReviewRejectedSuccess;

  /// No description provided for @leaveReviewApproveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve request. Please try again later.'**
  String get leaveReviewApproveFailed;

  /// No description provided for @leaveReviewRejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject request. Please check again.'**
  String get leaveReviewRejectFailed;

  /// No description provided for @errorGeneralFallback.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again later.'**
  String get errorGeneralFallback;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server. Please check your network connection.'**
  String get errorNoConnection;

  /// No description provided for @errorCannotConnectServer.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server. Please check your Wifi/4G connection or try again later.'**
  String get errorCannotConnectServer;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out. Please check your internet connection.'**
  String get errorTimeout;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Requested data was not found on the system.'**
  String get errorNotFound;

  /// No description provided for @errorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid data submitted. Please check your information.'**
  String get errorBadRequest;

  /// No description provided for @errorServerInternal.
  ///
  /// In en, this message translates to:
  /// **'Server error. Technical team is working on it, please try again later.'**
  String get errorServerInternal;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System is temporarily under maintenance or overloaded. Please try again shortly.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data. Please check your network or try again later.'**
  String get errorLoadFailed;

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save data. Please check your network or try again later.'**
  String get errorSaveFailed;

  /// No description provided for @errorSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send data. Please check your network or try again later.'**
  String get errorSendFailed;

  /// No description provided for @errorUnexpectedGeneric.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again in a few minutes.'**
  String get errorUnexpectedGeneric;

  /// No description provided for @errorUnexpectedTeacher.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again in a few minutes.'**
  String get errorUnexpectedTeacher;

  /// No description provided for @errorPhoneAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Phone number is already in use'**
  String get errorPhoneAlreadyUsed;

  /// No description provided for @errorCannotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Cannot open dialer app.'**
  String get errorCannotOpenDialer;

  /// No description provided for @readReportAction.
  ///
  /// In en, this message translates to:
  /// **'Read report ›'**
  String get readReportAction;

  /// No description provided for @phoneCopied.
  ///
  /// In en, this message translates to:
  /// **'Phone number copied'**
  String get phoneCopied;

  /// No description provided for @childFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get childFullName;

  /// No description provided for @childNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get childNicknameLabel;

  /// No description provided for @childNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get childNotSet;

  /// No description provided for @parentDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get parentDobLabel;

  /// No description provided for @parentAllergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get parentAllergyTitle;

  /// No description provided for @parentHealthProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Health profile'**
  String get parentHealthProfileTitle;

  /// No description provided for @switchChildLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch to another child'**
  String get switchChildLabel;

  /// No description provided for @callHeadTeacher.
  ///
  /// In en, this message translates to:
  /// **'Call head teacher'**
  String get callHeadTeacher;

  /// No description provided for @healthGood.
  ///
  /// In en, this message translates to:
  /// **'Good health'**
  String get healthGood;

  /// No description provided for @parentHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Profile'**
  String get parentHealthTitle;

  /// No description provided for @parentHealthLegacyInfo.
  ///
  /// In en, this message translates to:
  /// **'Information from existing records'**
  String get parentHealthLegacyInfo;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @parentHealthLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last profile update: {who} · {time}'**
  String parentHealthLastUpdated(String who, String time);

  /// No description provided for @parentHealthConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile was updated elsewhere'**
  String get parentHealthConflictTitle;

  /// No description provided for @parentHealthConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Please reload before saving.'**
  String get parentHealthConflictBody;

  /// No description provided for @parentHealthInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Information'**
  String get parentHealthInvalidTitle;

  /// No description provided for @parentHealthInvalidBody.
  ///
  /// In en, this message translates to:
  /// **'Please review allergy information and care notes.'**
  String get parentHealthInvalidBody;

  /// No description provided for @parentHealthTooLongTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Too Long'**
  String get parentHealthTooLongTitle;

  /// No description provided for @parentHealthTooLongBody.
  ///
  /// In en, this message translates to:
  /// **'Allergy description and care notes must not exceed 1000 characters.'**
  String get parentHealthTooLongBody;

  /// No description provided for @parentHealthAllergyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter child\'s allergy description.'**
  String get parentHealthAllergyRequired;

  /// No description provided for @parentHealthUndeclaredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Family has not provided allergy information.'**
  String get parentHealthUndeclaredSubtitle;

  /// No description provided for @parentHealthNoKnownAllergy.
  ///
  /// In en, this message translates to:
  /// **'No known allergies'**
  String get parentHealthNoKnownAllergy;

  /// No description provided for @parentHealthNoKnownAllergySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Family has not recorded any allergies.'**
  String get parentHealthNoKnownAllergySubtitle;

  /// No description provided for @parentHealthHasAllergySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Specify what the child is allergic to.'**
  String get parentHealthHasAllergySubtitle;

  /// No description provided for @parentHealthAllergyLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergy description'**
  String get parentHealthAllergyLabel;

  /// No description provided for @parentHealthAllergyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Peanuts'**
  String get parentHealthAllergyHint;

  /// No description provided for @parentHealthCareNotesHelper.
  ///
  /// In en, this message translates to:
  /// **'Not for daily messages or medication requests.'**
  String get parentHealthCareNotesHelper;

  /// No description provided for @commonReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get commonReload;

  /// No description provided for @commonConfirmChange.
  ///
  /// In en, this message translates to:
  /// **'Confirm Changes'**
  String get commonConfirmChange;

  /// No description provided for @commonStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get commonStay;

  /// No description provided for @parentHealthAllergyNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allergies & Health Notes'**
  String get parentHealthAllergyNotesTitle;

  /// No description provided for @parentHealthAllergySchoolNotice.
  ///
  /// In en, this message translates to:
  /// **'Allergy details the school needs to note'**
  String get parentHealthAllergySchoolNotice;

  /// No description provided for @childEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update information so the school can care for your child better.'**
  String get childEditSubtitle;

  /// No description provided for @childEditFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Child\'s full name *'**
  String get childEditFullNameLabel;

  /// No description provided for @childEditFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nguyen Minh An'**
  String get childEditFullNameHint;

  /// No description provided for @childEditFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Child\'s full name cannot be empty.'**
  String get childEditFullNameRequired;

  /// No description provided for @childEditNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Home nickname'**
  String get childEditNicknameLabel;

  /// No description provided for @childEditNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bo, Soc, Bon…'**
  String get childEditNicknameHint;

  /// No description provided for @childEditDobLabel.
  ///
  /// In en, this message translates to:
  /// **'Child\'s date of birth'**
  String get childEditDobLabel;

  /// No description provided for @childEditDobHint.
  ///
  /// In en, this message translates to:
  /// **'Select date of birth'**
  String get childEditDobHint;

  /// No description provided for @childEditDobFutureError.
  ///
  /// In en, this message translates to:
  /// **'Child\'s date of birth cannot be in the future.'**
  String get childEditDobFutureError;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @childEditSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving information…'**
  String get childEditSaving;

  /// No description provided for @childEditSuccess.
  ///
  /// In en, this message translates to:
  /// **'Child information updated successfully'**
  String get childEditSuccess;

  /// No description provided for @childEditSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save child information. Please try again later.'**
  String get childEditSaveError;

  /// No description provided for @childNicknamePrefix.
  ///
  /// In en, this message translates to:
  /// **'Nickname: {nickname}'**
  String childNicknamePrefix(String nickname);

  /// No description provided for @appVersionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersionNumber(String version);

  /// No description provided for @parentHeroDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days journey with child on KinderLog'**
  String parentHeroDays(int days);

  /// No description provided for @parentJourneyDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days journey with KinderLog'**
  String parentJourneyDaysCount(int days);

  /// No description provided for @requestDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Details'**
  String get requestDetailTitle;

  /// No description provided for @leaveRequestCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Leave Request'**
  String get leaveRequestCreateTitle;

  /// No description provided for @requestCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get requestCancelAction;

  /// No description provided for @requestCancelThisAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request'**
  String get requestCancelThisAction;

  /// No description provided for @leaveRequestCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel leave request?'**
  String get leaveRequestCancelConfirmTitle;

  /// No description provided for @requestKeepAction.
  ///
  /// In en, this message translates to:
  /// **'Keep Request'**
  String get requestKeepAction;

  /// No description provided for @requestSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT REQUEST'**
  String get requestSubmitButton;

  /// No description provided for @requestSubmitNoticeButton.
  ///
  /// In en, this message translates to:
  /// **'SEND NOTICE'**
  String get requestSubmitNoticeButton;

  /// No description provided for @requestSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting request'**
  String get requestSubmitting;

  /// No description provided for @requestSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted'**
  String get requestSubmittedTitle;

  /// No description provided for @requestCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Cancelled'**
  String get requestCancelledTitle;

  /// No description provided for @requestProcessStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing Status'**
  String get requestProcessStatus;

  /// No description provided for @requestReviewResult.
  ///
  /// In en, this message translates to:
  /// **'Review Result'**
  String get requestReviewResult;

  /// No description provided for @requestRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get requestRejectReason;

  /// No description provided for @leaveRequestReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for leave'**
  String get leaveRequestReasonLabel;

  /// No description provided for @lateArrivalReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for late arrival'**
  String get lateArrivalReasonLabel;

  /// No description provided for @leaveRequestReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for child\'s leave'**
  String get leaveRequestReasonHint;

  /// No description provided for @lateArrivalReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for child\'s late arrival'**
  String get lateArrivalReasonHint;

  /// No description provided for @requestReasonMinLength.
  ///
  /// In en, this message translates to:
  /// **'Reason must be at least 3 characters – validated on submit.'**
  String get requestReasonMinLength;

  /// No description provided for @requestReasonMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Reason must not exceed 1000 characters.'**
  String get requestReasonMaxLength;

  /// No description provided for @requestReasonTrimmedError.
  ///
  /// In en, this message translates to:
  /// **'Reason requires at least 3 characters after trimming spaces.'**
  String get requestReasonTrimmedError;

  /// No description provided for @lateArrivalDesc.
  ///
  /// In en, this message translates to:
  /// **'Arrive late today'**
  String get lateArrivalDesc;

  /// No description provided for @leaveMultipleDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'1 day or multiple days'**
  String get leaveMultipleDaysDesc;

  /// No description provided for @lateArrivalBannerNote.
  ///
  /// In en, this message translates to:
  /// **'New request type — notify in advance so teacher knows child\'s arrival schedule'**
  String get lateArrivalBannerNote;

  /// No description provided for @lateArrivalTeacherNote.
  ///
  /// In en, this message translates to:
  /// **'Teacher will see late note during morning attendance.'**
  String get lateArrivalTeacherNote;

  /// No description provided for @lateArrivalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Expected arrival is tentative; request approval does not replace actual attendance.'**
  String get lateArrivalDisclaimer;

  /// No description provided for @lateApprovalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Approved request does not confirm child presence or replace actual attendance.'**
  String get lateApprovalDisclaimer;

  /// No description provided for @syncAttendanceUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'No attendance sync confirmation from system yet.'**
  String get syncAttendanceUnconfirmed;

  /// No description provided for @requestSentToTeacherNote.
  ///
  /// In en, this message translates to:
  /// **'Request will be sent to head teacher for review.'**
  String get requestSentToTeacherNote;

  /// No description provided for @requestWaitingTeacher.
  ///
  /// In en, this message translates to:
  /// **'Waiting for teacher review'**
  String get requestWaitingTeacher;

  /// No description provided for @requestStatusCancelledUpper.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get requestStatusCancelledUpper;

  /// No description provided for @requestStatusRejectedShort.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get requestStatusRejectedShort;

  /// No description provided for @requestStatusApprovedBanner.
  ///
  /// In en, this message translates to:
  /// **'✓ REQUEST APPROVED'**
  String get requestStatusApprovedBanner;

  /// No description provided for @requestBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back to requests'**
  String get requestBackToList;

  /// No description provided for @requestViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View request history'**
  String get requestViewHistory;

  /// No description provided for @requestAttachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get requestAttachmentLabel;

  /// No description provided for @requestAddPrescriptionImage.
  ///
  /// In en, this message translates to:
  /// **'+ Add medical note / prescription photo'**
  String get requestAddPrescriptionImage;

  /// No description provided for @requestPrescriptionImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical note / prescription photo'**
  String get requestPrescriptionImageTitle;

  /// No description provided for @requestMedicalImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical photo'**
  String get requestMedicalImageLabel;

  /// No description provided for @requestMedicalPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Private medical photo · JPEG, PNG, WebP · Up to 5 MiB'**
  String get requestMedicalPhotoHint;

  /// No description provided for @requestMedicalPhotoAccessNote.
  ///
  /// In en, this message translates to:
  /// **'Private medical photo, only authorized viewers can access.'**
  String get requestMedicalPhotoAccessNote;

  /// No description provided for @requestImageTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'Image exceeds 5 MiB. Please select a smaller image.'**
  String get requestImageTooLargeError;

  /// No description provided for @requestCannotDisplayImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot display attached photo.'**
  String get requestCannotDisplayImage;

  /// No description provided for @requestCannotLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot load attached photo. Please try again.'**
  String get requestCannotLoadImage;

  /// No description provided for @requestCannotPickImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot open image. Please check gallery permissions and try again.'**
  String get requestCannotPickImage;

  /// No description provided for @requestRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get requestRemoveAttachment;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get commonSelectTime;

  /// No description provided for @leaveDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave Date'**
  String get leaveDateLabel;

  /// No description provided for @requestDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load request details. Please try again.'**
  String get requestDetailLoadError;

  /// No description provided for @requestDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading request details'**
  String get requestDetailLoading;

  /// No description provided for @requestOpeningImage.
  ///
  /// In en, this message translates to:
  /// **'Opening image…'**
  String get requestOpeningImage;

  /// No description provided for @requestLoadingMedicalImage.
  ///
  /// In en, this message translates to:
  /// **'Loading medical image'**
  String get requestLoadingMedicalImage;

  /// No description provided for @commonTodayPrefix.
  ///
  /// In en, this message translates to:
  /// **'Today — '**
  String get commonTodayPrefix;

  /// No description provided for @requestTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Type'**
  String get requestTypeTitle;

  /// No description provided for @lateDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Late Arrival Date'**
  String get lateDateLabel;

  /// No description provided for @leaveFromDate.
  ///
  /// In en, this message translates to:
  /// **'From Date'**
  String get leaveFromDate;

  /// No description provided for @leaveToDate.
  ///
  /// In en, this message translates to:
  /// **'To Date'**
  String get leaveToDate;

  /// No description provided for @leaveTotalDaysPrefix.
  ///
  /// In en, this message translates to:
  /// **'Total leave duration:'**
  String get leaveTotalDaysPrefix;

  /// No description provided for @lateArrivalExpectedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival time'**
  String get lateArrivalExpectedTime;

  /// No description provided for @commonSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get commonSelectDate;

  /// No description provided for @leaveRequestsNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get leaveRequestsNoRequests;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @commonDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get commonDays;

  /// No description provided for @categoryMeal.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get categoryMeal;

  /// No description provided for @categorySleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get categorySleep;

  /// No description provided for @categoryActivity.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get categoryActivity;

  /// No description provided for @categoryMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get categoryMood;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @reportReadConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Report marked as read ✓'**
  String get reportReadConfirmed;

  /// No description provided for @noChildRegistered.
  ///
  /// In en, this message translates to:
  /// **'No child registered'**
  String get noChildRegistered;

  /// No description provided for @noChildLinkedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your parent account is currently not linked to any child profile.\nPlease contact the school to update your child\'s information.'**
  String get noChildLinkedMessage;

  /// No description provided for @parentNavNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get parentNavNotifications;

  /// No description provided for @notificationsEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No notifications.'**
  String get notificationsEmptyAll;

  /// No description provided for @notificationsEmptyReports.
  ///
  /// In en, this message translates to:
  /// **'No new reports.'**
  String get notificationsEmptyReports;

  /// No description provided for @notificationsEmptyHealth.
  ///
  /// In en, this message translates to:
  /// **'No health notifications.'**
  String get notificationsEmptyHealth;

  /// No description provided for @notificationsEmptyLeave.
  ///
  /// In en, this message translates to:
  /// **'No new leave requests.'**
  String get notificationsEmptyLeave;

  /// No description provided for @notificationsFilterAllChildren.
  ///
  /// In en, this message translates to:
  /// **'All children'**
  String get notificationsFilterAllChildren;

  /// No description provided for @notificationsSectionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notificationsSectionNew;

  /// No description provided for @notificationsSectionEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsSectionEarlier;

  /// No description provided for @commonUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get commonUnread;

  /// No description provided for @parentReportOpenError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open this report. Please try again later.'**
  String get parentReportOpenError;

  /// No description provided for @parentReportNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No recorded details for this day.'**
  String get parentReportNoDetails;

  /// No description provided for @parentReportDatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get parentReportDatePrefix;

  /// No description provided for @parentChildClass.
  ///
  /// In en, this message translates to:
  /// **'Child\'s Class'**
  String get parentChildClass;

  /// No description provided for @classroomTitle.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get classroomTitle;

  /// No description provided for @reportDraftSavedSnackBar.
  ///
  /// In en, this message translates to:
  /// **'Report draft saved'**
  String get reportDraftSavedSnackBar;

  /// No description provided for @noClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Not Assigned to Any Class'**
  String get noClassTitle;

  /// No description provided for @noClassMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has not been assigned to any class yet. Please contact school administration for assistance, or try logging in again later.'**
  String get noClassMessage;

  /// No description provided for @loadClassListErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load class list · Retry'**
  String get loadClassListErrorRetry;

  /// No description provided for @loadClassInfoErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load class info · Retry'**
  String get loadClassInfoErrorRetry;

  /// No description provided for @noSchoolInfo.
  ///
  /// In en, this message translates to:
  /// **'No school information'**
  String get noSchoolInfo;

  /// No description provided for @loadClassListError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load class list. Please try again.'**
  String get loadClassListError;

  /// No description provided for @searchChildNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search child\'s name…'**
  String get searchChildNameHint;

  /// No description provided for @noChildMatched.
  ///
  /// In en, this message translates to:
  /// **'No matching child found.'**
  String get noChildMatched;

  /// No description provided for @allergyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Allergy: '**
  String get allergyPrefix;

  /// No description provided for @allergyTag.
  ///
  /// In en, this message translates to:
  /// **'Allergy {allergy}'**
  String allergyTag(Object allergy);

  /// No description provided for @noCareNotes.
  ///
  /// In en, this message translates to:
  /// **'No care notes yet.'**
  String get noCareNotes;

  /// No description provided for @dailyRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily records'**
  String get dailyRecordTitle;

  /// No description provided for @recordForChildAction.
  ///
  /// In en, this message translates to:
  /// **'Record voice for child'**
  String get recordForChildAction;

  /// No description provided for @viewParentDiscussionAction.
  ///
  /// In en, this message translates to:
  /// **'View parent discussion'**
  String get viewParentDiscussionAction;

  /// No description provided for @healthStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Health: {status}'**
  String healthStatusLabel(Object status);

  /// No description provided for @unrecordedStatus.
  ///
  /// In en, this message translates to:
  /// **'Unrecorded'**
  String get unrecordedStatus;

  /// No description provided for @recordedStatus.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recordedStatus;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @needsAttentionFilter.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttentionFilter;

  /// No description provided for @loadHistoryErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history · Retry'**
  String get loadHistoryErrorRetry;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @searchByChildNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by child name…'**
  String get searchByChildNameHint;

  /// No description provided for @noReportsMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No reports match this filter.'**
  String get noReportsMatchFilter;

  /// No description provided for @dailyReportDateRow.
  ///
  /// In en, this message translates to:
  /// **'Daily report · {time}'**
  String dailyReportDateRow(Object time);

  /// No description provided for @todayText.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayText;

  /// No description provided for @yesterdayText.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayText;

  /// No description provided for @logoutConfirmDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get logoutConfirmDialogTitle;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @notUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get notUpdated;

  /// No description provided for @assignedClassLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned class'**
  String get assignedClassLabel;

  /// No description provided for @classChildrenCount.
  ///
  /// In en, this message translates to:
  /// **'{className} · {count} children'**
  String classChildrenCount(Object className, Object count);

  /// No description provided for @teacherTitle.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherTitle;

  /// No description provided for @teacherPrefix.
  ///
  /// In en, this message translates to:
  /// **'Teacher {name}'**
  String teacherPrefix(String name);

  /// No description provided for @loadAccountErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load account · Retry'**
  String get loadAccountErrorRetry;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @headTeacherRole.
  ///
  /// In en, this message translates to:
  /// **'Head teacher'**
  String get headTeacherRole;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @personalSection.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalSection;

  /// No description provided for @contactInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get contactInfoLabel;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @notificationsNavLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsNavLabel;

  /// No description provided for @changePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordLabel;

  /// No description provided for @languageSettingLabel.
  ///
  /// In en, this message translates to:
  /// **'Language / Ngôn ngữ'**
  String get languageSettingLabel;

  /// No description provided for @vietnameseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt 🇻🇳'**
  String get vietnameseLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English 🇬🇧'**
  String get englishLanguage;

  /// No description provided for @supportSection.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportSection;

  /// No description provided for @helpAndBugReport.
  ///
  /// In en, this message translates to:
  /// **'Help & Bug Report'**
  String get helpAndBugReport;

  /// No description provided for @aboutKinderlog.
  ///
  /// In en, this message translates to:
  /// **'About KinderLog'**
  String get aboutKinderlog;

  /// No description provided for @cannotVerifyClassNotifications.
  ///
  /// In en, this message translates to:
  /// **'Cannot verify class notifications.'**
  String get cannotVerifyClassNotifications;

  /// No description provided for @cannotLoadNotificationsRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications. Please try again.'**
  String get cannotLoadNotificationsRetry;

  /// No description provided for @filterLeaveRequests.
  ///
  /// In en, this message translates to:
  /// **'Leave requests'**
  String get filterLeaveRequests;

  /// No description provided for @filterIncidents.
  ///
  /// In en, this message translates to:
  /// **'Incidents'**
  String get filterIncidents;

  /// No description provided for @badgeLateArrival.
  ///
  /// In en, this message translates to:
  /// **'LATE ARRIVAL'**
  String get badgeLateArrival;

  /// No description provided for @badgeLeaveRequest.
  ///
  /// In en, this message translates to:
  /// **'LEAVE REQUEST'**
  String get badgeLeaveRequest;

  /// No description provided for @newBadgeSuffix.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get newBadgeSuffix;

  /// No description provided for @lateArrivalNotificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Late arrival {date} · Expected {time}'**
  String lateArrivalNotificationDesc(Object date, Object time);

  /// No description provided for @leaveNotificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave {date} ({days} days) · Sent {time}'**
  String leaveNotificationDesc(Object date, Object days, Object time);

  /// No description provided for @healthIncidentNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Health incident — {name}'**
  String healthIncidentNotificationTitle(Object name);

  /// No description provided for @attendanceUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance updated — {name}'**
  String attendanceUpdatedTitle(Object name);

  /// No description provided for @arrivedLateDesc.
  ///
  /// In en, this message translates to:
  /// **'Arrived late{time}'**
  String arrivedLateDesc(Object time);

  /// No description provided for @excusedAbsentDesc.
  ///
  /// In en, this message translates to:
  /// **'Excused absence{note}'**
  String excusedAbsentDesc(Object note);

  /// No description provided for @unexcusedAbsentDesc.
  ///
  /// In en, this message translates to:
  /// **'Absent{note}'**
  String unexcusedAbsentDesc(Object note);

  /// No description provided for @dailyReportSentCount.
  ///
  /// In en, this message translates to:
  /// **'Daily reports sent {sent}/{total}'**
  String dailyReportSentCount(Object sent, Object total);

  /// No description provided for @dailyReportPendingRemaining.
  ///
  /// In en, this message translates to:
  /// **'{names} remaining without reports'**
  String dailyReportPendingRemaining(Object names);

  /// No description provided for @dailyReportDraftCountRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} drafts remaining unsent'**
  String dailyReportDraftCountRemaining(Object count);

  /// No description provided for @dailyReportAllCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed all reports for the class'**
  String get dailyReportAllCompleted;

  /// No description provided for @earlierSection.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlierSection;

  /// No description provided for @noIncidentNotifications.
  ///
  /// In en, this message translates to:
  /// **'No incident notifications yet.'**
  String get noIncidentNotifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications.'**
  String get noNotifications;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @badgeMedication.
  ///
  /// In en, this message translates to:
  /// **'MEDICATION'**
  String get badgeMedication;

  /// No description provided for @badgeIncident.
  ///
  /// In en, this message translates to:
  /// **'INCIDENT'**
  String get badgeIncident;

  /// No description provided for @badgeAttendance.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE'**
  String get badgeAttendance;

  /// No description provided for @badgeReport.
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get badgeReport;

  /// No description provided for @unreadStatus.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unreadStatus;

  /// No description provided for @readStatus.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readStatus;

  /// No description provided for @attendanceSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Attendance saved successfully'**
  String get attendanceSavedSuccess;

  /// No description provided for @cannotSaveAttendanceRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to save attendance. Please try again later.'**
  String get cannotSaveAttendanceRetry;

  /// No description provided for @discardAttendanceChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard attendance changes?'**
  String get discardAttendanceChangesTitle;

  /// No description provided for @discardAttendanceChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes made to the attendance list will not be saved.'**
  String get discardAttendanceChangesMessage;

  /// No description provided for @continueAttendance.
  ///
  /// In en, this message translates to:
  /// **'Continue attendance'**
  String get continueAttendance;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @attendanceNotifiedParentsCount.
  ///
  /// In en, this message translates to:
  /// **'Sent attendance notice to parents ({count} devices received)'**
  String attendanceNotifiedParentsCount(Object count);

  /// No description provided for @cannotSendAttendanceNotification.
  ///
  /// In en, this message translates to:
  /// **'Cannot send notifications at this time. Please check your connection.'**
  String get cannotSendAttendanceNotification;

  /// No description provided for @noAttendanceDataForDate.
  ///
  /// In en, this message translates to:
  /// **'No attendance data for this date.'**
  String get noAttendanceDataForDate;

  /// No description provided for @cannotLoadAttendanceForDate.
  ///
  /// In en, this message translates to:
  /// **'Failed to load attendance for the selected date.'**
  String get cannotLoadAttendanceForDate;

  /// No description provided for @sendAbsentNotification.
  ///
  /// In en, this message translates to:
  /// **'Send absent notification'**
  String get sendAbsentNotification;

  /// No description provided for @attendanceSummaryText.
  ///
  /// In en, this message translates to:
  /// **'{arrived}/{total} children arrived. {onTime} on time, {late} late, {absent} absent, {excusedAbsent} excused.'**
  String attendanceSummaryText(Object absent, Object arrived,
      Object excusedAbsent, Object late, Object onTime, Object total);

  /// No description provided for @studentsArrivedCount.
  ///
  /// In en, this message translates to:
  /// **'{arrived}/{total} children arrived'**
  String studentsArrivedCount(Object arrived, Object total);

  /// No description provided for @onTimeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} on time'**
  String onTimeCount(Object count);

  /// No description provided for @lateCountText.
  ///
  /// In en, this message translates to:
  /// **'{count} late'**
  String lateCountText(Object count);

  /// No description provided for @absentCountText.
  ///
  /// In en, this message translates to:
  /// **'{count} absent'**
  String absentCountText(Object count);

  /// No description provided for @excusedAbsentCountText.
  ///
  /// In en, this message translates to:
  /// **'{count} excused'**
  String excusedAbsentCountText(Object count);

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @pendingLeaveRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} leave requests pending review'**
  String pendingLeaveRequestsCount(Object count);

  /// No description provided for @savingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingStatus;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @updatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updatedStatus;

  /// No description provided for @arrivedAtTime.
  ///
  /// In en, this message translates to:
  /// **'Arrived at {time}'**
  String arrivedAtTime(String time);

  /// No description provided for @expectedAtTime.
  ///
  /// In en, this message translates to:
  /// **'Expected at {time}'**
  String expectedAtTime(Object time);

  /// No description provided for @sendAbsentNoticeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send absent notification?'**
  String get sendAbsentNoticeConfirmTitle;

  /// No description provided for @sendAbsentNoticeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Send push notification to parents of {count} absent children on {date}.'**
  String sendAbsentNoticeConfirmMessage(Object count, Object date);

  /// No description provided for @unsavedAttendanceNoticeWarning.
  ///
  /// In en, this message translates to:
  /// **'Unsaved attendance · You should save attendance before sending notifications.'**
  String get unsavedAttendanceNoticeWarning;

  /// No description provided for @sendNotificationAction.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get sendNotificationAction;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @statusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get statusAbsent;

  /// No description provided for @statusExcusedAbsent.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get statusExcusedAbsent;

  /// No description provided for @statusLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get statusLate;

  /// No description provided for @cannotVerifyClassRequests.
  ///
  /// In en, this message translates to:
  /// **'Cannot verify class requests.'**
  String get cannotVerifyClassRequests;

  /// No description provided for @cannotLoadMoreRequests.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more requests. Please try again.'**
  String get cannotLoadMoreRequests;

  /// No description provided for @cannotLoadRequestsList.
  ///
  /// In en, this message translates to:
  /// **'Failed to load requests list. Please check your network connection.'**
  String get cannotLoadRequestsList;

  /// No description provided for @approveRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve request. Please try again later.'**
  String get approveRequestFailed;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @requestRejectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request rejected. Parents can view the reason in the app.'**
  String get requestRejectedSuccess;

  /// No description provided for @rejectRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject request. Please check again.'**
  String get rejectRequestFailed;

  /// No description provided for @closeImage.
  ///
  /// In en, this message translates to:
  /// **'Close image'**
  String get closeImage;

  /// No description provided for @cannotDisplayImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot display this image.'**
  String get cannotDisplayImage;

  /// No description provided for @cannotLoadAttachment.
  ///
  /// In en, this message translates to:
  /// **'Failed to load attachment. Please try again.'**
  String get cannotLoadAttachment;

  /// No description provided for @reviewLeaveRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Review leave requests'**
  String get reviewLeaveRequestTitle;

  /// No description provided for @totalDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String totalDaysCount(Object days);

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @senderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get senderLabel;

  /// No description provided for @parentRole.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parentRole;

  /// No description provided for @sentAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent at'**
  String get sentAtLabel;

  /// No description provided for @attachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachmentLabel;

  /// No description provided for @viewAttachment.
  ///
  /// In en, this message translates to:
  /// **'View attachment'**
  String get viewAttachment;

  /// No description provided for @rejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get rejectReasonLabel;

  /// No description provided for @etaDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Expected arrival time is not the actual check-in time.'**
  String get etaDisclaimer;

  /// No description provided for @leaveApprovalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'When approved, attendance will be synced to \'Excused absent\'; actual check-in time is retained.'**
  String get leaveApprovalDisclaimer;

  /// No description provided for @rejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectAction;

  /// No description provided for @approveAction.
  ///
  /// In en, this message translates to:
  /// **'Approve request'**
  String get approveAction;

  /// No description provided for @cannotOpenPhoneApp.
  ///
  /// In en, this message translates to:
  /// **'Cannot open phone call application.'**
  String get cannotOpenPhoneApp;

  /// No description provided for @pendingReviewWithCount.
  ///
  /// In en, this message translates to:
  /// **'Pending review ({count})'**
  String pendingReviewWithCount(Object count);

  /// No description provided for @processedTab.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get processedTab;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests pending review'**
  String get noPendingRequests;

  /// No description provided for @noProcessedRequestsHistory.
  ///
  /// In en, this message translates to:
  /// **'No processed request history yet'**
  String get noProcessedRequestsHistory;

  /// No description provided for @recentlyProcessed.
  ///
  /// In en, this message translates to:
  /// **'Recently processed'**
  String get recentlyProcessed;

  /// No description provided for @retryLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Retry loading more'**
  String get retryLoadMore;

  /// No description provided for @viewRequestDetail.
  ///
  /// In en, this message translates to:
  /// **'View request detail'**
  String get viewRequestDetail;

  /// No description provided for @rejectReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason *'**
  String get rejectReasonPrompt;

  /// No description provided for @rejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter specific reason so parents stay informed'**
  String get rejectReasonHint;

  /// No description provided for @rejectReasonValidation.
  ///
  /// In en, this message translates to:
  /// **'Reason is required (2–500 characters). Parents will see this reason in child\'s request details.'**
  String get rejectReasonValidation;

  /// No description provided for @sendRejectionAction.
  ///
  /// In en, this message translates to:
  /// **'Submit rejection'**
  String get sendRejectionAction;

  /// No description provided for @cannotLoadTimetable.
  ///
  /// In en, this message translates to:
  /// **'Failed to load timetable.'**
  String get cannotLoadTimetable;

  /// No description provided for @classTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'Class timetable'**
  String get classTimetableTitle;

  /// No description provided for @searchTimetableHint.
  ///
  /// In en, this message translates to:
  /// **'Search period, subject, time slot (e.g. 08:00, 8h)...'**
  String get searchTimetableHint;

  /// No description provided for @noMatchingActivitiesFound.
  ///
  /// In en, this message translates to:
  /// **'No matching activities found'**
  String get noMatchingActivitiesFound;

  /// No description provided for @searchTimetableSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try searching with a different time slot or subject/room name.'**
  String get searchTimetableSuggestion;

  /// No description provided for @addActivityAction.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get addActivityAction;

  /// No description provided for @conflictsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} conflicts'**
  String conflictsCount(Object count);

  /// No description provided for @noConflicts.
  ///
  /// In en, this message translates to:
  /// **'No conflicts'**
  String get noConflicts;

  /// No description provided for @noActivitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No activities yet'**
  String get noActivitiesYet;

  /// No description provided for @thisWeekWithLabel.
  ///
  /// In en, this message translates to:
  /// **'This week · {label}'**
  String thisWeekWithLabel(Object label);

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room: {room}'**
  String roomLabel(Object room);

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deleteActivityConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this activity?'**
  String get deleteActivityConfirmTitle;

  /// No description provided for @deleteActivityConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Weekly recurring activity — will be removed from class timetable.'**
  String get deleteActivityConfirmMessage;

  /// No description provided for @activityDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Activity deleted'**
  String get activityDeletedSuccess;

  /// No description provided for @cannotDeleteActivity.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete activity. Please try again.'**
  String get cannotDeleteActivity;

  /// No description provided for @noActivitiesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No activities this week.'**
  String get noActivitiesThisWeek;

  /// No description provided for @classHasNoActivitiesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Class has no activities for this week.'**
  String get classHasNoActivitiesThisWeek;

  /// No description provided for @addActivityToSchedulePrompt.
  ///
  /// In en, this message translates to:
  /// **'Add activities to schedule for the class.'**
  String get addActivityToSchedulePrompt;

  /// No description provided for @ongoingStatus.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoingStatus;

  /// No description provided for @upNextStatus.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNextStatus;

  /// No description provided for @timeSlotConflict.
  ///
  /// In en, this message translates to:
  /// **'Time slot conflict'**
  String get timeSlotConflict;

  /// No description provided for @dayTab.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayTab;

  /// No description provided for @weekTab.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get weekTab;

  /// No description provided for @enterActivityNamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter activity name.'**
  String get enterActivityNamePrompt;

  /// No description provided for @selectSubjectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select subject / activity.'**
  String get selectSubjectPrompt;

  /// No description provided for @selectTimeSlotPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select time slot.'**
  String get selectTimeSlotPrompt;

  /// No description provided for @activityAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Activity added'**
  String get activityAddedSuccess;

  /// No description provided for @activityUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Activity updated'**
  String get activityUpdatedSuccess;

  /// No description provided for @cannotSaveActivity.
  ///
  /// In en, this message translates to:
  /// **'Failed to save activity. Please try again.'**
  String get cannotSaveActivity;

  /// No description provided for @editActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivityTitle;

  /// No description provided for @selectClassPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select classroom'**
  String get selectClassPrompt;

  /// No description provided for @activityNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityNameLabel;

  /// No description provided for @activityNameExampleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Creative Drawing'**
  String get activityNameExampleHint;

  /// No description provided for @subjectActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject / Activity'**
  String get subjectActivityLabel;

  /// No description provided for @timeSlotLabel.
  ///
  /// In en, this message translates to:
  /// **'Time slot'**
  String get timeSlotLabel;

  /// No description provided for @dayOfWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of week'**
  String get dayOfWeekLabel;

  /// No description provided for @roomOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Room (optional)'**
  String get roomOptionalLabel;

  /// No description provided for @roomExampleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Art Room'**
  String get roomExampleHint;

  /// No description provided for @timeSlotClashWarning.
  ///
  /// In en, this message translates to:
  /// **'This slot already has \"{activity}\" on {day}.'**
  String timeSlotClashWarning(Object activity, Object day);

  /// No description provided for @saveActivityAction.
  ///
  /// In en, this message translates to:
  /// **'Save activity'**
  String get saveActivityAction;

  /// No description provided for @noSubjectsPrompt.
  ///
  /// In en, this message translates to:
  /// **'No subjects available. Please create a subject first.'**
  String get noSubjectsPrompt;

  /// No description provided for @noTimeSlotsPrompt.
  ///
  /// In en, this message translates to:
  /// **'No time slots available. Please create a time slot first.'**
  String get noTimeSlotsPrompt;

  /// No description provided for @emergencyHighFever.
  ///
  /// In en, this message translates to:
  /// **'High fever'**
  String get emergencyHighFever;

  /// No description provided for @emergencyFallAccident.
  ///
  /// In en, this message translates to:
  /// **'Fall / Accident'**
  String get emergencyFallAccident;

  /// No description provided for @emergencyAllergyReaction.
  ///
  /// In en, this message translates to:
  /// **'Acute allergic reaction'**
  String get emergencyAllergyReaction;

  /// No description provided for @emergencyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get emergencyOther;

  /// No description provided for @selectStudentEmergencyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select student experiencing incident.'**
  String get selectStudentEmergencyPrompt;

  /// No description provided for @temperatureRangePrompt.
  ///
  /// In en, this message translates to:
  /// **'Temperature must be between 34°C and 44°C.'**
  String get temperatureRangePrompt;

  /// No description provided for @emergencySavedContactInvalid.
  ///
  /// In en, this message translates to:
  /// **'Incident saved but contact list is invalid. Please reload contacts, do not resubmit form.'**
  String get emergencySavedContactInvalid;

  /// No description provided for @cannotOpenPhoneCallUseDirect.
  ///
  /// In en, this message translates to:
  /// **'Cannot open phone dialer. Please use directory number to call directly.'**
  String get cannotOpenPhoneCallUseDirect;

  /// No description provided for @noValidPhoneNumberInContacts.
  ///
  /// In en, this message translates to:
  /// **'No valid phone number in emergency contacts.'**
  String get noValidPhoneNumberInContacts;

  /// No description provided for @selectParentToCall.
  ///
  /// In en, this message translates to:
  /// **'Select parent to call'**
  String get selectParentToCall;

  /// No description provided for @reportIncidentTitle.
  ///
  /// In en, this message translates to:
  /// **'Report incident'**
  String get reportIncidentTitle;

  /// No description provided for @notifyParentsAndSchool.
  ///
  /// In en, this message translates to:
  /// **'Notify parents and school'**
  String get notifyParentsAndSchool;

  /// No description provided for @emergencyVerificationWarning.
  ///
  /// In en, this message translates to:
  /// **'Verify child, details, and recipients before sending emergency alert.'**
  String get emergencyVerificationWarning;

  /// No description provided for @changeChild.
  ///
  /// In en, this message translates to:
  /// **'Change child'**
  String get changeChild;

  /// No description provided for @selectStudentHint.
  ///
  /// In en, this message translates to:
  /// **'Select student...'**
  String get selectStudentHint;

  /// No description provided for @tapToSearchAndSelectChild.
  ///
  /// In en, this message translates to:
  /// **'Tap to search and select child'**
  String get tapToSearchAndSelectChild;

  /// No description provided for @incidentTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Incident type'**
  String get incidentTypeLabel;

  /// No description provided for @temperatureOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature (optional)'**
  String get temperatureOptionalLabel;

  /// No description provided for @temperatureHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. 38.5'**
  String get temperatureHint;

  /// No description provided for @incidentDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Incident description'**
  String get incidentDescriptionLabel;

  /// No description provided for @incidentFirstAidHint.
  ///
  /// In en, this message translates to:
  /// **'Condition and first aid actions (optional)'**
  String get incidentFirstAidHint;

  /// No description provided for @alertRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Alert recipients'**
  String get alertRecipientsLabel;

  /// No description provided for @loadingContacts.
  ///
  /// In en, this message translates to:
  /// **'Loading contacts...'**
  String get loadingContacts;

  /// No description provided for @noParentPhoneUpdatedForChild.
  ///
  /// In en, this message translates to:
  /// **'No parent phone number updated for this child.'**
  String get noParentPhoneUpdatedForChild;

  /// No description provided for @reloadContacts.
  ///
  /// In en, this message translates to:
  /// **'Reload contacts'**
  String get reloadContacts;

  /// No description provided for @sendEmergencyAlertAction.
  ///
  /// In en, this message translates to:
  /// **'Send emergency alert'**
  String get sendEmergencyAlertAction;

  /// No description provided for @callParentsAction.
  ///
  /// In en, this message translates to:
  /// **'Call parents'**
  String get callParentsAction;

  /// No description provided for @emergencyOneTapDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'One-tap incident log. Push alerts may process in background; call family if immediate confirmation is needed.'**
  String get emergencyOneTapDisclaimer;

  /// No description provided for @incidentReportSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Incident report saved'**
  String get incidentReportSavedSuccess;

  /// No description provided for @contactLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactLabel;

  /// No description provided for @noTeacherDescription.
  ///
  /// In en, this message translates to:
  /// **'No description from teacher.'**
  String get noTeacherDescription;

  /// No description provided for @noPushConfirmationYet.
  ///
  /// In en, this message translates to:
  /// **'No push delivery confirmation yet.'**
  String get noPushConfirmationYet;

  /// No description provided for @callParentsNow.
  ///
  /// In en, this message translates to:
  /// **'Call parents now'**
  String get callParentsNow;

  /// No description provided for @completeAction.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeAction;

  /// No description provided for @selectStudentTitle.
  ///
  /// In en, this message translates to:
  /// **'Select student'**
  String get selectStudentTitle;

  /// No description provided for @cannotOpenPhoneCallApp.
  ///
  /// In en, this message translates to:
  /// **'Cannot open phone call application.'**
  String get cannotOpenPhoneCallApp;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @noTimeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No time available'**
  String get noTimeAvailable;

  /// No description provided for @emergencyAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert'**
  String get emergencyAlertTitle;

  /// No description provided for @teacherSentIncidentNotice.
  ///
  /// In en, this message translates to:
  /// **'{teacherName} just sent an incident notice.'**
  String teacherSentIncidentNotice(Object teacherName);

  /// No description provided for @teacherContentHeader.
  ///
  /// In en, this message translates to:
  /// **'Content from teacher'**
  String get teacherContentHeader;

  /// No description provided for @temperatureDegrees.
  ///
  /// In en, this message translates to:
  /// **'Temperature · {temp}°C'**
  String temperatureDegrees(Object temp);

  /// No description provided for @callTeacherAction.
  ///
  /// In en, this message translates to:
  /// **'Call {teacherName}'**
  String callTeacherAction(Object teacherName);

  /// No description provided for @acknowledgedDismissSiren.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged · Dismiss siren'**
  String get acknowledgedDismissSiren;

  /// No description provided for @badgeLateArrivalApproved.
  ///
  /// In en, this message translates to:
  /// **'Late arrival approved'**
  String get badgeLateArrivalApproved;

  /// No description provided for @badgeRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get badgeRequestApproved;

  /// No description provided for @checkAttendanceAfterApprovalHint.
  ///
  /// In en, this message translates to:
  /// **'You can check attendance status on the Attendance screen after approving request.'**
  String get checkAttendanceAfterApprovalHint;

  /// No description provided for @lateArrivalApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Late arrival request approved'**
  String get lateArrivalApprovedTitle;

  /// No description provided for @leaveRequestApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave request approved'**
  String get leaveRequestApprovedTitle;

  /// No description provided for @requestUpdatedStatus.
  ///
  /// In en, this message translates to:
  /// **'Request updated'**
  String get requestUpdatedStatus;

  /// No description provided for @requestStatusUpdatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Request status has been updated.'**
  String get requestStatusUpdatedDesc;

  /// No description provided for @attendanceDateAfterApproval.
  ///
  /// In en, this message translates to:
  /// **'Attendance on {date} after approval'**
  String attendanceDateAfterApproval(Object date);

  /// No description provided for @returnToAttendanceAction.
  ///
  /// In en, this message translates to:
  /// **'Return to Attendance'**
  String get returnToAttendanceAction;

  /// No description provided for @leaveRequestDetailOf.
  ///
  /// In en, this message translates to:
  /// **'Request detail of {name}'**
  String leaveRequestDetailOf(Object name);

  /// No description provided for @leaveReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave reason:'**
  String get leaveReasonLabel;

  /// No description provided for @commonContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get commonContent;

  /// No description provided for @requestTotalDays.
  ///
  /// In en, this message translates to:
  /// **'Total days'**
  String get requestTotalDays;

  /// No description provided for @lateArrivalNewNotice.
  ///
  /// In en, this message translates to:
  /// **'New late arrival notice — {name}'**
  String lateArrivalNewNotice(String name);

  /// No description provided for @leaveRequestNewNotice.
  ///
  /// In en, this message translates to:
  /// **'New leave request — {name}'**
  String leaveRequestNewNotice(String name);

  /// No description provided for @lateArrivalNoticeType.
  ///
  /// In en, this message translates to:
  /// **'late arrival notice'**
  String get lateArrivalNoticeType;

  /// No description provided for @leaveRequestNoticeType.
  ///
  /// In en, this message translates to:
  /// **'leave request'**
  String get leaveRequestNoticeType;

  /// No description provided for @classListTab.
  ///
  /// In en, this message translates to:
  /// **'Class list'**
  String get classListTab;

  /// No description provided for @notificationsWithUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread'**
  String notificationsWithUnreadCount(int count);

  /// No description provided for @relationSelectChildPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select your relationship with {name}.'**
  String relationSelectChildPrompt(String name);

  /// No description provided for @maxImagesLimitWarning.
  ///
  /// In en, this message translates to:
  /// **'You can only attach up to {count} images.'**
  String maxImagesLimitWarning(int count);

  /// No description provided for @fileExceedsSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'File {name} exceeds the allowed {size}MB limit.'**
  String fileExceedsSizeLimit(String name, int size);

  /// No description provided for @cannotPickImageFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Cannot pick image from device.'**
  String get cannotPickImageFromDevice;

  /// No description provided for @bugReportAttachmentsHint.
  ///
  /// In en, this message translates to:
  /// **'Attachments · maximum 5 images, each ≤ 5MB'**
  String get bugReportAttachmentsHint;

  /// No description provided for @bugReportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send feedback. Please check your network connection and try again.'**
  String get bugReportSendFailed;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title for feedback or issue'**
  String get titleRequired;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a detailed description'**
  String get descriptionRequired;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @aboutSchoolDefault.
  ///
  /// In en, this message translates to:
  /// **'Hoa Mi Kindergarten'**
  String get aboutSchoolDefault;

  /// No description provided for @aboutSchoolYear.
  ///
  /// In en, this message translates to:
  /// **'School year'**
  String get aboutSchoolYear;

  /// No description provided for @aboutKeyFeatures.
  ///
  /// In en, this message translates to:
  /// **'KEY FEATURES'**
  String get aboutKeyFeatures;

  /// No description provided for @aboutFeatureVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Hands-free AI Voice'**
  String get aboutFeatureVoiceTitle;

  /// No description provided for @aboutFeatureVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Teachers create daily reports via voice, with automatic speech-to-text and classification for meals, naps, and learning.'**
  String get aboutFeatureVoiceDesc;

  /// No description provided for @aboutFeatureContactBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital Contact Book'**
  String get aboutFeatureContactBookTitle;

  /// No description provided for @aboutFeatureContactBookDesc.
  ///
  /// In en, this message translates to:
  /// **'Real-time updates of each child\'s activities; parents follow and reply to teacher remarks during the day.'**
  String get aboutFeatureContactBookDesc;

  /// No description provided for @aboutFeatureHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health & Allergy Records'**
  String get aboutFeatureHealthTitle;

  /// No description provided for @aboutFeatureHealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage allergies, check-up history, track weight and height, and automatically calculate BMI status.'**
  String get aboutFeatureHealthDesc;

  /// No description provided for @aboutFeatureTimetableTitle.
  ///
  /// In en, this message translates to:
  /// **'Timetable & Leave Requests'**
  String get aboutFeatureTimetableTitle;

  /// No description provided for @aboutFeatureTimetableDesc.
  ///
  /// In en, this message translates to:
  /// **'View weekly class timetables, submit leave requests online, and receive quick teacher confirmations.'**
  String get aboutFeatureTimetableDesc;

  /// No description provided for @aboutDevTeam.
  ///
  /// In en, this message translates to:
  /// **'Development Team'**
  String get aboutDevTeam;

  /// No description provided for @aboutTechSupport.
  ///
  /// In en, this message translates to:
  /// **'Technical Support'**
  String get aboutTechSupport;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get aboutProtected;

  /// No description provided for @aboutTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get aboutTermsOfService;

  /// No description provided for @aboutCompliant.
  ///
  /// In en, this message translates to:
  /// **'Compliant'**
  String get aboutCompliant;

  /// No description provided for @cannotLoadDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Could not load discussion. Please try again later.'**
  String get cannotLoadDiscussion;

  /// No description provided for @cannotPickImageGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not select image. Please try again.'**
  String get cannotPickImageGeneric;

  /// No description provided for @attachImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get attachImageTitle;

  /// No description provided for @takePhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo from camera'**
  String get takePhotoCamera;

  /// No description provided for @choosePhotoGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose photo from gallery'**
  String get choosePhotoGallery;

  /// No description provided for @sentAttachedImage.
  ///
  /// In en, this message translates to:
  /// **'Sent an attached image'**
  String get sentAttachedImage;

  /// No description provided for @cannotSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send message. Please try again.'**
  String get cannotSendMessage;

  /// No description provided for @cannotSendVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send voice message. Please try again later.'**
  String get cannotSendVoiceMessage;

  /// No description provided for @discussionWithParent.
  ///
  /// In en, this message translates to:
  /// **'Discussion with parents'**
  String get discussionWithParent;

  /// No description provided for @discussionWithTeacher.
  ///
  /// In en, this message translates to:
  /// **'Discussion with teacher'**
  String get discussionWithTeacher;

  /// No description provided for @discussionResponseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} responses'**
  String discussionResponseCount(int count);

  /// No description provided for @discussionResponded.
  ///
  /// In en, this message translates to:
  /// **'Responded'**
  String get discussionResponded;

  /// No description provided for @discussionNoDiscussionYet.
  ///
  /// In en, this message translates to:
  /// **'No discussion yet'**
  String get discussionNoDiscussionYet;

  /// No description provided for @discussionNoResponsesYet.
  ///
  /// In en, this message translates to:
  /// **'No responses yet'**
  String get discussionNoResponsesYet;

  /// No description provided for @discussionTeacherEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'When parents send feedback on this report, messages will appear here for the teacher to follow up and reply.'**
  String get discussionTeacherEmptyHint;

  /// No description provided for @discussionParentEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Parents can send messages or notes to the teacher about this report.'**
  String get discussionParentEmptyHint;

  /// No description provided for @discussionSentReadByParent.
  ///
  /// In en, this message translates to:
  /// **'Sent · Read by parent'**
  String get discussionSentReadByParent;

  /// No description provided for @discussionSentReadByTeacher.
  ///
  /// In en, this message translates to:
  /// **'Sent · Read by teacher'**
  String get discussionSentReadByTeacher;

  /// No description provided for @discussionAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'✓ Acknowledged & resolved'**
  String get discussionAcknowledged;

  /// No description provided for @discussionMarkHandled.
  ///
  /// In en, this message translates to:
  /// **'Mark as resolved'**
  String get discussionMarkHandled;

  /// No description provided for @discussionAttachedImage.
  ///
  /// In en, this message translates to:
  /// **'Attached image'**
  String get discussionAttachedImage;

  /// No description provided for @discussionReadyToSendWithMsg.
  ///
  /// In en, this message translates to:
  /// **'Ready to send with message'**
  String get discussionReadyToSendWithMsg;

  /// No description provided for @discussionCancelImage.
  ///
  /// In en, this message translates to:
  /// **'Deselect image'**
  String get discussionCancelImage;

  /// No description provided for @discussionAttachImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach photo'**
  String get discussionAttachImageTooltip;

  /// No description provided for @discussionTeacherInputHint.
  ///
  /// In en, this message translates to:
  /// **'Reply to parent about this report...'**
  String get discussionTeacherInputHint;

  /// No description provided for @discussionParentInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message the teacher about this report...'**
  String get discussionParentInputHint;

  /// No description provided for @chatWithParent.
  ///
  /// In en, this message translates to:
  /// **'Chat with parent'**
  String get chatWithParent;

  /// No description provided for @chatWithTeacher.
  ///
  /// In en, this message translates to:
  /// **'Chat with teacher'**
  String get chatWithTeacher;

  /// No description provided for @childLabelPrefix.
  ///
  /// In en, this message translates to:
  /// **'Child {name}'**
  String childLabelPrefix(String name);

  /// No description provided for @minimizeChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Minimize chat window'**
  String get minimizeChatTooltip;

  /// No description provided for @reviewApprovedCount.
  ///
  /// In en, this message translates to:
  /// **'Approved {approved}/{total}'**
  String reviewApprovedCount(int approved, int total);

  /// No description provided for @sttCopiedAnalyzedText.
  ///
  /// In en, this message translates to:
  /// **'Analyzed text copied to clipboard.'**
  String get sttCopiedAnalyzedText;

  /// No description provided for @sttSplitChildrenCount.
  ///
  /// In en, this message translates to:
  /// **'Separated {count} children'**
  String sttSplitChildrenCount(int count);

  /// No description provided for @sttSaveText.
  ///
  /// In en, this message translates to:
  /// **'Save text'**
  String get sttSaveText;

  /// No description provided for @sttCannotRecognizeHint.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize this segment. Click X above to delete and re-record.'**
  String get sttCannotRecognizeHint;

  /// No description provided for @sttEditTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter or edit audio transcript…'**
  String get sttEditTranscriptHint;

  /// No description provided for @sttRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get sttRecognizing;

  /// No description provided for @sttErrorBadge.
  ///
  /// In en, this message translates to:
  /// **'STT Error'**
  String get sttErrorBadge;

  /// No description provided for @sttDoneBadge.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sttDoneBadge;

  /// No description provided for @sttSegmentIndex.
  ///
  /// In en, this message translates to:
  /// **'Segment {index}'**
  String sttSegmentIndex(int index);

  /// No description provided for @sttReportsSummary.
  ///
  /// In en, this message translates to:
  /// **'{parentsCount} parents received reports. Health record has {healthCount} new rows. All from recording at {time}.'**
  String sttReportsSummary(int parentsCount, int healthCount, String time);

  /// No description provided for @sttSendReportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send reports to parents?'**
  String get sttSendReportConfirmTitle;

  /// No description provided for @sttDailyReportDate.
  ///
  /// In en, this message translates to:
  /// **'Daily report · {date}'**
  String sttDailyReportDate(String date);

  /// No description provided for @sttSaveDraftSuccess.
  ///
  /// In en, this message translates to:
  /// **'Draft saved successfully'**
  String get sttSaveDraftSuccess;

  /// No description provided for @sttCannotSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Could not save draft. Please try again.'**
  String get sttCannotSaveDraft;

  /// No description provided for @sttCannotSendReport.
  ///
  /// In en, this message translates to:
  /// **'Could not send report. Please try again.'**
  String get sttCannotSendReport;

  /// No description provided for @sttSentCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'Report has been sent and cannot be edited.'**
  String get sttSentCannotEdit;

  /// No description provided for @sttNoRecordYet.
  ///
  /// In en, this message translates to:
  /// **'No observations yet'**
  String get sttNoRecordYet;

  /// No description provided for @sttMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get sttMood;

  /// No description provided for @sttTeacherNotes.
  ///
  /// In en, this message translates to:
  /// **'Teacher notes'**
  String get sttTeacherNotes;

  /// No description provided for @sttSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get sttSaveDraft;

  /// No description provided for @sttSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get sttSendReport;

  /// No description provided for @sttStepReview.
  ///
  /// In en, this message translates to:
  /// **'Step 3/3 · Review'**
  String get sttStepReview;

  /// No description provided for @sttNoAudioToPlay.
  ///
  /// In en, this message translates to:
  /// **'No audio file to replay.'**
  String get sttNoAudioToPlay;

  /// No description provided for @sttCannotPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Could not play this audio clip.'**
  String get sttCannotPlayAudio;

  /// No description provided for @sttNoMicPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get sttNoMicPermissionTitle;

  /// No description provided for @sttCannotRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot record audio'**
  String get sttCannotRecordTitle;

  /// No description provided for @sttOpenSettingsForMic.
  ///
  /// In en, this message translates to:
  /// **'Open Settings to grant microphone permission.'**
  String get sttOpenSettingsForMic;

  /// No description provided for @sttStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get sttStopRecording;

  /// No description provided for @sttSaveClip.
  ///
  /// In en, this message translates to:
  /// **'Save clip'**
  String get sttSaveClip;

  /// No description provided for @sttStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get sttStartRecording;

  /// No description provided for @sttUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get sttUploadFile;

  /// No description provided for @sttRerecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get sttRerecord;

  /// No description provided for @sttReprocessClip.
  ///
  /// In en, this message translates to:
  /// **'Reprocess recording'**
  String get sttReprocessClip;

  /// No description provided for @sttSendToParents.
  ///
  /// In en, this message translates to:
  /// **'Send report to parents'**
  String get sttSendToParents;

  /// No description provided for @sttEnterTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text content...'**
  String get sttEnterTextHint;

  /// No description provided for @sttReanalyze.
  ///
  /// In en, this message translates to:
  /// **'Re-analyze'**
  String get sttReanalyze;

  /// No description provided for @sttReportSentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get sttReportSentSuccessTitle;

  /// No description provided for @sttUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get sttUndo;

  /// No description provided for @sttSearchChildNameOrNick.
  ///
  /// In en, this message translates to:
  /// **'Search child\'s name or nickname'**
  String get sttSearchChildNameOrNick;

  /// No description provided for @sttSearchChild.
  ///
  /// In en, this message translates to:
  /// **'Search child…'**
  String get sttSearchChild;

  /// No description provided for @sttRecordActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Record activities'**
  String get sttRecordActivityTitle;

  /// No description provided for @sttSelectChildToStart.
  ///
  /// In en, this message translates to:
  /// **'Select a child to start recording'**
  String get sttSelectChildToStart;

  /// No description provided for @sttOrSelectEachChild.
  ///
  /// In en, this message translates to:
  /// **'or select each child'**
  String get sttOrSelectEachChild;

  /// No description provided for @sttIncidentAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Incident report'**
  String get sttIncidentAlertTitle;

  /// No description provided for @sttAnalyzingAudio.
  ///
  /// In en, this message translates to:
  /// **'Analyzing recording'**
  String get sttAnalyzingAudio;

  /// No description provided for @sttProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get sttProcessingTitle;

  /// No description provided for @sttCannotLoadClassRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load class · Retry'**
  String get sttCannotLoadClassRetry;

  /// No description provided for @sttCannotLoadReportRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load report · Retry'**
  String get sttCannotLoadReportRetry;

  /// No description provided for @sttUnknownClass.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get sttUnknownClass;

  /// No description provided for @sttUnknownSchool.
  ///
  /// In en, this message translates to:
  /// **'School unassigned'**
  String get sttUnknownSchool;

  /// No description provided for @commonSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get commonSearchPlaceholder;

  /// No description provided for @rejectReasonPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter a specific reason for parents to understand'**
  String get rejectReasonPlaceholder;

  /// No description provided for @rejectReasonHelper.
  ///
  /// In en, this message translates to:
  /// **'Reason is required (2–500 characters). Parents can view it in request details.'**
  String get rejectReasonHelper;

  /// No description provided for @commonChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get commonChild;

  /// No description provided for @requestNoResultYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get requestNoResultYet;

  /// No description provided for @syncAttendanceNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Attendance sync not yet confirmed by the system.'**
  String get syncAttendanceNotConfirmed;

  /// No description provided for @cannotCancelContactTeacher.
  ///
  /// In en, this message translates to:
  /// **'This request cannot be cancelled. Please contact the teacher.'**
  String get cannotCancelContactTeacher;

  /// No description provided for @leaveRequestDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Request approval does not confirm attendance or replace actual attendance.'**
  String get leaveRequestDisclaimer;

  /// No description provided for @cannotVerifyChildRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not verify child request. Please reload.'**
  String get cannotVerifyChildRequest;

  /// No description provided for @cancelConfirmPendingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Cancellation not yet confirmed. Please refresh before retrying.'**
  String get cancelConfirmPendingPrompt;

  /// No description provided for @cancelSessionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording session?'**
  String get cancelSessionConfirmTitle;

  /// No description provided for @cancelSessionConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'All recordings in the current session will be discarded.'**
  String get cancelSessionConfirmDesc;

  /// No description provided for @keepSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepSessionAction;

  /// No description provided for @cancelSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get cancelSessionAction;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettingsAction;

  /// No description provided for @laterAction.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get laterAction;

  /// No description provided for @audioTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Recording is too short or contains no audio. Please try again.'**
  String get audioTooShortError;

  /// No description provided for @cannotSaveAudioError.
  ///
  /// In en, this message translates to:
  /// **'Could not save recording. Please record again.'**
  String get cannotSaveAudioError;

  /// No description provided for @recordingHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Tip: narrate the child\'s activities'**
  String get recordingHintTitle;

  /// No description provided for @recordingHintDesc.
  ///
  /// In en, this message translates to:
  /// **'Mention in order: meals, nap, activities, health, and mood.'**
  String get recordingHintDesc;

  /// No description provided for @sendForProcessing.
  ///
  /// In en, this message translates to:
  /// **'Send for processing'**
  String get sendForProcessing;

  /// No description provided for @sendForAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Send for analysis'**
  String get sendForAnalysis;

  /// No description provided for @recordingLiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Recording · Speak naturally'**
  String get recordingLiveMessage;

  /// No description provided for @pressToStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Tap to start recording'**
  String get pressToStartRecording;

  /// No description provided for @savingClipToSession.
  ///
  /// In en, this message translates to:
  /// **'Saving audio clip to session…'**
  String get savingClipToSession;

  /// No description provided for @uploadAudioFile.
  ///
  /// In en, this message translates to:
  /// **'Upload audio file'**
  String get uploadAudioFile;

  /// No description provided for @chooseAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFile;

  /// No description provided for @cancelFileSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelFileSelection;

  /// No description provided for @readyToGenerateReports.
  ///
  /// In en, this message translates to:
  /// **'Ready to generate reports'**
  String get readyToGenerateReports;

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve all'**
  String get approveAll;

  /// No description provided for @unapproveAll.
  ///
  /// In en, this message translates to:
  /// **'Unapprove all'**
  String get unapproveAll;

  /// No description provided for @approvedStatus.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvedStatus;

  /// No description provided for @unapprovedStatus.
  ///
  /// In en, this message translates to:
  /// **'Unapprove'**
  String get unapprovedStatus;

  /// No description provided for @discardItem.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardItem;

  /// No description provided for @assignThisSegment.
  ///
  /// In en, this message translates to:
  /// **'Assign this segment'**
  String get assignThisSegment;

  /// No description provided for @skipThisSegment.
  ///
  /// In en, this message translates to:
  /// **'Skip this segment'**
  String get skipThisSegment;

  /// No description provided for @unidentifiedChild.
  ///
  /// In en, this message translates to:
  /// **'Unidentified child'**
  String get unidentifiedChild;

  /// No description provided for @recognizedChildPrefix.
  ///
  /// In en, this message translates to:
  /// **'Recognized · {name}'**
  String recognizedChildPrefix(String name);

  /// No description provided for @discardedChildPrefix.
  ///
  /// In en, this message translates to:
  /// **'Discarded · {name}'**
  String discardedChildPrefix(String name);

  /// No description provided for @entireClassOption.
  ///
  /// In en, this message translates to:
  /// **'Entire class'**
  String get entireClassOption;

  /// No description provided for @assignSegmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign segment'**
  String get assignSegmentTitle;

  /// No description provided for @noDetailsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No detailed information recorded'**
  String get noDetailsRecorded;

  /// No description provided for @confirmSendAllReports.
  ///
  /// In en, this message translates to:
  /// **'Confirm send for entire class'**
  String get confirmSendAllReports;

  /// No description provided for @noItemsApprovedToSend.
  ///
  /// In en, this message translates to:
  /// **'No approved items to send'**
  String get noItemsApprovedToSend;

  /// No description provided for @allClipsProcessed.
  ///
  /// In en, this message translates to:
  /// **'All clips processed'**
  String get allClipsProcessed;

  /// No description provided for @forChildOnly.
  ///
  /// In en, this message translates to:
  /// **'Only {name}'**
  String forChildOnly(String name);

  /// No description provided for @applyToEntireClass.
  ///
  /// In en, this message translates to:
  /// **'Apply to entire class'**
  String get applyToEntireClass;

  /// No description provided for @categoryEating.
  ///
  /// In en, this message translates to:
  /// **'Eating'**
  String get categoryEating;

  /// No description provided for @categoryNote.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get categoryNote;

  /// No description provided for @noDetailInfoRecorded.
  ///
  /// In en, this message translates to:
  /// **'No detailed information recorded'**
  String get noDetailInfoRecorded;

  /// No description provided for @wholeClassOption.
  ///
  /// In en, this message translates to:
  /// **'Whole class {className}'**
  String wholeClassOption(String className);

  /// No description provided for @recordAllChildrenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record once, create reports for all children.'**
  String get recordAllChildrenSubtitle;

  /// No description provided for @childrenCountFormat.
  ///
  /// In en, this message translates to:
  /// **'{total} children'**
  String childrenCountFormat(int total);

  /// No description provided for @unidentifiedChildSnippetDefault.
  ///
  /// In en, this message translates to:
  /// **'Could not accurately identify the child in class.'**
  String get unidentifiedChildSnippetDefault;

  /// No description provided for @openNotifications.
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get openNotifications;

  /// No description provided for @parentJourneyDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'{days} days journey with child at KinderLog'**
  String parentJourneyDaysLabel(int days);

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @switchChild.
  ///
  /// In en, this message translates to:
  /// **'Switch child'**
  String get switchChild;

  /// No description provided for @childInfoSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Information'**
  String get childInfoSheetTitle;

  /// No description provided for @nicknamePrefix.
  ///
  /// In en, this message translates to:
  /// **'Nickname: {nickname}'**
  String nicknamePrefix(String nickname);

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersionLabel(String version);

  /// No description provided for @homeroomTeacher.
  ///
  /// In en, this message translates to:
  /// **'Homeroom Teacher'**
  String get homeroomTeacher;

  /// No description provided for @childrenUnit.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get childrenUnit;

  /// No description provided for @allergyLabel.
  ///
  /// In en, this message translates to:
  /// **'allergy'**
  String get allergyLabel;

  /// No description provided for @needsAttentionLabel.
  ///
  /// In en, this message translates to:
  /// **'needs attention'**
  String get needsAttentionLabel;

  /// No description provided for @dailyReportDate.
  ///
  /// In en, this message translates to:
  /// **'Daily report · {time}'**
  String dailyReportDate(String time);

  /// No description provided for @unmatchedSegmentsNeedConfirm.
  ///
  /// In en, this message translates to:
  /// **'{classLabel} · {count} segment(s) need confirmation'**
  String unmatchedSegmentsNeedConfirm(String classLabel, int count);

  /// No description provided for @readInSpokenOrder.
  ///
  /// In en, this message translates to:
  /// **'Read back in the exact order told.'**
  String get readInSpokenOrder;

  /// No description provided for @expectedAtTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Expected at {time}'**
  String expectedAtTimeFormat(String time);

  /// No description provided for @sendAbsencePushConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send push notification to parents of {count} absent children on {date}.'**
  String sendAbsencePushConfirm(int count, String date);

  /// No description provided for @pendingReportsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{names} have no reports yet'**
  String pendingReportsRemaining(String names);

  /// No description provided for @thisWeekPrefix.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeekPrefix;

  /// No description provided for @sttSeparatedByChild.
  ///
  /// In en, this message translates to:
  /// **'Separated information by child'**
  String get sttSeparatedByChild;

  /// No description provided for @sttMicPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Please grant microphone access to record audio. You can open Device Settings, select Privacy → Microphone and enable it for KinderLog.'**
  String get sttMicPermissionMessage;

  /// No description provided for @sttCannotRecordMessage.
  ///
  /// In en, this message translates to:
  /// **'The app cannot record yet. Please check microphone access in device settings and try again.'**
  String get sttCannotRecordMessage;
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
