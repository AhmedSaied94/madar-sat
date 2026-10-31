import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'مدار سات'**
  String get appName;

  /// No description provided for @brandMark.
  ///
  /// In ar, this message translates to:
  /// **'مدار'**
  String get brandMark;

  /// No description provided for @navMatches.
  ///
  /// In ar, this message translates to:
  /// **'المباريات'**
  String get navMatches;

  /// No description provided for @navSatellites.
  ///
  /// In ar, this message translates to:
  /// **'أقماري'**
  String get navSatellites;

  /// No description provided for @navFrequencies.
  ///
  /// In ar, this message translates to:
  /// **'الترددات'**
  String get navFrequencies;

  /// No description provided for @navFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get navFavorites;

  /// No description provided for @navMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get navMore;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل'**
  String get loading;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'معرض المكوّنات'**
  String get gallery;

  /// No description provided for @emptyDayTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات في هذا اليوم'**
  String get emptyDayTitle;

  /// No description provided for @emptyDayBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب يوماً آخر أو اسحب القائمة لتحديثها.'**
  String get emptyDayBody;

  /// No description provided for @emptyLiveTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات مباشرة الآن'**
  String get emptyLiveTitle;

  /// No description provided for @emptyMyMatchesTitle.
  ///
  /// In ar, this message translates to:
  /// **'تابع فرقك لتظهر مبارياتها هنا'**
  String get emptyMyMatchesTitle;

  /// No description provided for @loadFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البيانات'**
  String get loadFailedTitle;

  /// No description provided for @noConnectionTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get noConnectionTitle;

  /// No description provided for @noConnectionBody.
  ///
  /// In ar, this message translates to:
  /// **'تأكد من اتصالك بالإنترنت وحاول مرة أخرى'**
  String get noConnectionBody;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @timeTbd.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحدد'**
  String get timeTbd;

  /// No description provided for @live.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get live;

  /// No description provided for @halftime.
  ///
  /// In ar, this message translates to:
  /// **'استراحة'**
  String get halftime;

  /// No description provided for @extraTime.
  ///
  /// In ar, this message translates to:
  /// **'إضافي'**
  String get extraTime;

  /// No description provided for @penalties.
  ///
  /// In ar, this message translates to:
  /// **'ركلات الترجيح'**
  String get penalties;

  /// No description provided for @finished.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get finished;

  /// No description provided for @postponed.
  ///
  /// In ar, this message translates to:
  /// **'تأجلت'**
  String get postponed;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغيت'**
  String get cancelled;

  /// No description provided for @abandoned.
  ///
  /// In ar, this message translates to:
  /// **'توقفت'**
  String get abandoned;

  /// No description provided for @imminent.
  ///
  /// In ar, this message translates to:
  /// **'بعد {minutes} د'**
  String imminent(Object minutes);

  /// No description provided for @free.
  ///
  /// In ar, this message translates to:
  /// **'مجانية'**
  String get free;

  /// No description provided for @encrypted.
  ///
  /// In ar, this message translates to:
  /// **'مشفرة'**
  String get encrypted;

  /// No description provided for @onMySatellites.
  ///
  /// In ar, this message translates to:
  /// **'على أقمارك'**
  String get onMySatellites;

  /// No description provided for @changedRecently.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر مؤخراً'**
  String get changedRecently;

  /// No description provided for @categorySports.
  ///
  /// In ar, this message translates to:
  /// **'رياضة'**
  String get categorySports;

  /// No description provided for @categoryEntertainment.
  ///
  /// In ar, this message translates to:
  /// **'ترفيه'**
  String get categoryEntertainment;

  /// No description provided for @channelsMore.
  ///
  /// In ar, this message translates to:
  /// **'+{count}'**
  String channelsMore(Object count);

  /// No description provided for @satellite.
  ///
  /// In ar, this message translates to:
  /// **'القمر'**
  String get satellite;

  /// No description provided for @frequency.
  ///
  /// In ar, this message translates to:
  /// **'التردد'**
  String get frequency;

  /// No description provided for @polarization.
  ///
  /// In ar, this message translates to:
  /// **'الاستقطاب'**
  String get polarization;

  /// No description provided for @symbolRate.
  ///
  /// In ar, this message translates to:
  /// **'معدل الترميز'**
  String get symbolRate;

  /// No description provided for @polHorizontal.
  ///
  /// In ar, this message translates to:
  /// **'أفقي'**
  String get polHorizontal;

  /// No description provided for @polVertical.
  ///
  /// In ar, this message translates to:
  /// **'رأسي'**
  String get polVertical;

  /// No description provided for @polLeft.
  ///
  /// In ar, this message translates to:
  /// **'يسار'**
  String get polLeft;

  /// No description provided for @polRight.
  ///
  /// In ar, this message translates to:
  /// **'يمين'**
  String get polRight;

  /// No description provided for @copiedFrequency.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ التردد'**
  String get copiedFrequency;

  /// No description provided for @frequencyNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة التردد'**
  String get frequencyNote;

  /// No description provided for @details.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get details;

  /// No description provided for @amMarker.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get amMarker;

  /// No description provided for @pmMarker.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get pmMarker;

  /// No description provided for @errorNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد ما تبحث عنه'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In ar, this message translates to:
  /// **'تحقّق من البيانات المدخلة'**
  String get errorValidation;

  /// No description provided for @errorInternal.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع'**
  String get errorInternal;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم'**
  String get errorNetwork;

  /// No description provided for @errorNotImplemented.
  ///
  /// In ar, this message translates to:
  /// **'هذه الخدمة غير متاحة بعد'**
  String get errorNotImplemented;

  /// No description provided for @vs.
  ///
  /// In ar, this message translates to:
  /// **'{home} ضد {away}'**
  String vs(Object away, Object home);

  /// No description provided for @minuteShort.
  ///
  /// In ar, this message translates to:
  /// **'{minute}′'**
  String minuteShort(Object minute);

  /// No description provided for @minuteSemantics.
  ///
  /// In ar, this message translates to:
  /// **'الدقيقة {minute}'**
  String minuteSemantics(Object minute);

  /// No description provided for @scoreSemantics.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة {home} مقابل {away}'**
  String scoreSemantics(Object away, Object home);

  /// No description provided for @channelOn.
  ///
  /// In ar, this message translates to:
  /// **'على {channel}'**
  String channelOn(Object channel);

  /// No description provided for @listSeparator.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// No description provided for @scoreSeparator.
  ///
  /// In ar, this message translates to:
  /// **'-'**
  String get scoreSeparator;

  /// No description provided for @fullDate.
  ///
  /// In ar, this message translates to:
  /// **'{weekday} {day} {month}'**
  String fullDate(Object day, Object month, Object weekday);

  /// No description provided for @weekdayMon.
  ///
  /// In ar, this message translates to:
  /// **'الإثنين'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get weekdaySun;

  /// No description provided for @weekdayShortMon.
  ///
  /// In ar, this message translates to:
  /// **'إثنين'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثاء'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In ar, this message translates to:
  /// **'أربعاء'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In ar, this message translates to:
  /// **'خميس'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In ar, this message translates to:
  /// **'جمعة'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In ar, this message translates to:
  /// **'سبت'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In ar, this message translates to:
  /// **'أحد'**
  String get weekdayShortSun;

  /// No description provided for @month1.
  ///
  /// In ar, this message translates to:
  /// **'يناير'**
  String get month1;

  /// No description provided for @month2.
  ///
  /// In ar, this message translates to:
  /// **'فبراير'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In ar, this message translates to:
  /// **'مارس'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In ar, this message translates to:
  /// **'أبريل'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In ar, this message translates to:
  /// **'مايو'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In ar, this message translates to:
  /// **'يونيو'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In ar, this message translates to:
  /// **'يوليو'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In ar, this message translates to:
  /// **'أغسطس'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In ar, this message translates to:
  /// **'سبتمبر'**
  String get month9;

  /// No description provided for @month10.
  ///
  /// In ar, this message translates to:
  /// **'أكتوبر'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In ar, this message translates to:
  /// **'نوفمبر'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In ar, this message translates to:
  /// **'ديسمبر'**
  String get month12;

  /// No description provided for @statusEstimated.
  ///
  /// In ar, this message translates to:
  /// **'تقديري'**
  String get statusEstimated;

  /// No description provided for @copyFrequency.
  ///
  /// In ar, this message translates to:
  /// **'نسخ التردد'**
  String get copyFrequency;

  /// No description provided for @follow.
  ///
  /// In ar, this message translates to:
  /// **'تابع'**
  String get follow;

  /// No description provided for @following.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get following;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @country.
  ///
  /// In ar, this message translates to:
  /// **'الدولة'**
  String get country;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @textScale.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get textScale;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @clearSearch.
  ///
  /// In ar, this message translates to:
  /// **'مسح البحث'**
  String get clearSearch;

  /// No description provided for @staleHint.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث {age}'**
  String staleHint(Object age);

  /// No description provided for @ageJustNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get ageJustNow;

  /// No description provided for @ageMinutes.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} د'**
  String ageMinutes(Object count);

  /// No description provided for @ageHours.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} س'**
  String ageHours(Object count);

  /// No description provided for @ageDays.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} يوم'**
  String ageDays(Object count);

  /// No description provided for @commentator.
  ///
  /// In ar, this message translates to:
  /// **'المعلّق'**
  String get commentator;

  /// No description provided for @commentatorPlay.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل مقطع صوتي لـ {name}'**
  String commentatorPlay(Object name);

  /// No description provided for @commentatorPause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف المقطع'**
  String get commentatorPause;

  /// No description provided for @commentatorLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل المقطع'**
  String get commentatorLoading;

  /// No description provided for @commentatorPlaying.
  ///
  /// In ar, this message translates to:
  /// **'يُشغَّل الآن'**
  String get commentatorPlaying;

  /// No description provided for @commentatorError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل المقطع'**
  String get commentatorError;

  /// No description provided for @receptionVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو الاستقبال'**
  String get receptionVideo;

  /// No description provided for @s2TbdGroup.
  ///
  /// In ar, this message translates to:
  /// **'موعد لم يُحدد'**
  String get s2TbdGroup;

  /// No description provided for @s2ShowAllMatches.
  ///
  /// In ar, this message translates to:
  /// **'عرض كل المباريات'**
  String get s2ShowAllMatches;

  /// No description provided for @s3Title.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المباراة'**
  String get s3Title;

  /// No description provided for @s3WhereToWatch.
  ///
  /// In ar, this message translates to:
  /// **'أين تشاهد'**
  String get s3WhereToWatch;

  /// No description provided for @s3ChannelsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قناة واحدة} =2{قناتان} few{{count} قنوات} other{{count} قناة}}'**
  String s3ChannelsCount(int count);

  /// No description provided for @s3SatellitesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قمر واحد} =2{قمرين} few{{count} أقمار} other{{count} قمرًا}}'**
  String s3SatellitesCount(int count);

  /// No description provided for @s3PlatformsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منصة واحدة} =2{منصتان} few{{count} منصات} other{{count} منصة}}'**
  String s3PlatformsCount(int count);

  /// No description provided for @s3ChannelsOnSatellites.
  ///
  /// In ar, this message translates to:
  /// **'{channels} على {satellites}'**
  String s3ChannelsOnSatellites(Object channels, Object satellites);

  /// No description provided for @s3FreeOnly.
  ///
  /// In ar, this message translates to:
  /// **'المجانية فقط'**
  String get s3FreeOnly;

  /// No description provided for @s3SearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن قمر أو قناة...'**
  String get s3SearchHint;

  /// No description provided for @s3OtherSatellites.
  ///
  /// In ar, this message translates to:
  /// **'أقمار أخرى'**
  String get s3OtherSatellites;

  /// No description provided for @s3OtherPlatforms.
  ///
  /// In ar, this message translates to:
  /// **'منصات وقنوات أخرى'**
  String get s3OtherPlatforms;

  /// No description provided for @s3NoSatellite.
  ///
  /// In ar, this message translates to:
  /// **'بدون قمر'**
  String get s3NoSatellite;

  /// No description provided for @s3NothingOnMySatellites.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قنوات على أقمارك لهذه المباراة'**
  String get s3NothingOnMySatellites;

  /// No description provided for @s3NoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قنوات مطابقة لبحثك'**
  String get s3NoResults;

  /// No description provided for @s3BackToTop.
  ///
  /// In ar, this message translates to:
  /// **'العودة لأعلى القنوات'**
  String get s3BackToTop;

  /// No description provided for @s3BroadcastOn.
  ///
  /// In ar, this message translates to:
  /// **'يعرض على'**
  String get s3BroadcastOn;

  /// No description provided for @s3BroadcastAlsoOn.
  ///
  /// In ar, this message translates to:
  /// **'يعرض أيضاً على'**
  String get s3BroadcastAlsoOn;

  /// No description provided for @s3MatchInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات المباراة'**
  String get s3MatchInfo;

  /// No description provided for @s3Stadium.
  ///
  /// In ar, this message translates to:
  /// **'الملعب'**
  String get s3Stadium;

  /// No description provided for @s3LocalBroadcasterEg.
  ///
  /// In ar, this message translates to:
  /// **'القناة الناقلة في مصر'**
  String get s3LocalBroadcasterEg;

  /// No description provided for @s3NoChannelsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تُضف القنوات الناقلة بعد'**
  String get s3NoChannelsTitle;

  /// No description provided for @s3NoChannelsBody.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر القنوات والترددات هنا فور إضافتها.'**
  String get s3NoChannelsBody;

  /// No description provided for @s3Refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get s3Refresh;

  /// No description provided for @s3OpenFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط'**
  String get s3OpenFailed;

  /// No description provided for @s3DateTime.
  ///
  /// In ar, this message translates to:
  /// **'{date} · {time}'**
  String s3DateTime(Object date, Object time);

  /// No description provided for @s4NoMatchesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات على {satellites} لهذا اليوم'**
  String s4NoMatchesTitle(Object satellites);

  /// No description provided for @s4NoMatchesBody.
  ///
  /// In ar, this message translates to:
  /// **'اسحب القائمة لتحديثها.'**
  String get s4NoMatchesBody;

  /// No description provided for @s4NoSatellitesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تختر أقماراً بعد'**
  String get s4NoSatellitesTitle;

  /// No description provided for @s4NoSatellitesBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر قمراً واحداً على الأقل لتظهر المباريات المنقولة عليه.'**
  String get s4NoSatellitesBody;

  /// No description provided for @s4ChooseSatellites.
  ///
  /// In ar, this message translates to:
  /// **'اختر أقمارك'**
  String get s4ChooseSatellites;

  /// No description provided for @s5SearchSatellites.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن قمر...'**
  String get s5SearchSatellites;

  /// No description provided for @s5SatelliteCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} قمراً'**
  String s5SatelliteCount(Object count);

  /// No description provided for @s5SectionAll.
  ///
  /// In ar, this message translates to:
  /// **'كل الأقمار'**
  String get s5SectionAll;

  /// No description provided for @s5MineMarker.
  ///
  /// In ar, this message translates to:
  /// **'طبقي'**
  String get s5MineMarker;

  /// No description provided for @s5ChannelCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} قناة'**
  String s5ChannelCount(Object count);

  /// No description provided for @s5NoSatellitesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أقمار مطابقة'**
  String get s5NoSatellitesTitle;

  /// No description provided for @s5NoSatellitesBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسماً أو موقعاً آخر.'**
  String get s5NoSatellitesBody;

  /// No description provided for @s5ReceptionHowTo.
  ///
  /// In ar, this message translates to:
  /// **'طريقة استقبال القمر'**
  String get s5ReceptionHowTo;

  /// No description provided for @s5ReceptionOpenFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الفيديو'**
  String get s5ReceptionOpenFailed;

  /// No description provided for @s5StrongestFrequency.
  ///
  /// In ar, this message translates to:
  /// **'أقوى تردد'**
  String get s5StrongestFrequency;

  /// No description provided for @s5WeakestFrequency.
  ///
  /// In ar, this message translates to:
  /// **'أضعف تردد'**
  String get s5WeakestFrequency;

  /// No description provided for @s5SearchChannels.
  ///
  /// In ar, this message translates to:
  /// **'بحث في القنوات...'**
  String get s5SearchChannels;

  /// No description provided for @s5CategoryTab.
  ///
  /// In ar, this message translates to:
  /// **'{label} {count}'**
  String s5CategoryTab(Object count, Object label);

  /// No description provided for @s5NoSportsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قنوات رياضة على هذا القمر'**
  String get s5NoSportsTitle;

  /// No description provided for @s5NoEntertainmentTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قنوات ترفيه على هذا القمر'**
  String get s5NoEntertainmentTitle;

  /// No description provided for @s5NoResultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قنوات مطابقة'**
  String get s5NoResultsTitle;

  /// No description provided for @s5NoResultsBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسم قناة أو أرقاماً من التردد.'**
  String get s5NoResultsBody;
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
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
