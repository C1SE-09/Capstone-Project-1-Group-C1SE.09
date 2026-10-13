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
