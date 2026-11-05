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

  /// No description provided for @splashQuestion.
  ///
  /// In ar, this message translates to:
  /// **'أي قناة تنقل المباراة؟'**
  String get splashQuestion;

  /// No description provided for @splashAnswer.
  ///
  /// In ar, this message translates to:
  /// **'والتردد جاهز.'**
  String get splashAnswer;

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

  /// No description provided for @access.
  ///
  /// In ar, this message translates to:
  /// **'الوصول'**
  String get access;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get category;

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
  /// **'جاري التشغيل...'**
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

  /// No description provided for @s3OnSatellites.
  ///
  /// In ar, this message translates to:
  /// **'على {satellites}'**
  String s3OnSatellites(String satellites);

  /// No description provided for @s3OnDefaultSatellites.
  ///
  /// In ar, this message translates to:
  /// **'على نايل سات وبدر'**
  String get s3OnDefaultSatellites;

  /// No description provided for @s3StartsInMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تبدأ بعد دقيقة} =2{تبدأ بعد دقيقتين} few{تبدأ بعد {count} دقائق} other{تبدأ بعد {count} دقيقة}}'**
  String s3StartsInMinutes(int count);

  /// No description provided for @s3StartsInHours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تبدأ بعد ساعة} =2{تبدأ بعد ساعتين} few{تبدأ بعد {count} ساعات} other{تبدأ بعد {count} ساعة}}'**
  String s3StartsInHours(int count);

  /// No description provided for @s3StartsInDays.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تبدأ بعد يوم} =2{تبدأ بعد يومين} few{تبدأ بعد {count} أيام} other{تبدأ بعد {count} يوم}}'**
  String s3StartsInDays(int count);

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

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @nextCount.
  ///
  /// In ar, this message translates to:
  /// **'التالي ({count})'**
  String nextCount(int count);

  /// No description provided for @gotIt.
  ///
  /// In ar, this message translates to:
  /// **'فهمت'**
  String get gotIt;

  /// No description provided for @later.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get later;

  /// No description provided for @notNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get notNow;

  /// No description provided for @add.
  ///
  /// In ar, this message translates to:
  /// **'أضف'**
  String get add;

  /// No description provided for @onbProgress.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {step} من {count}'**
  String onbProgress(int step, int count);

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في مدار'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'مباراتك، القناة الناقلة، وترددها على طبقك — في مكان واحد.'**
  String get onbWelcomeBody;

  /// No description provided for @onbChooseTheme.
  ///
  /// In ar, this message translates to:
  /// **'اختر المظهر'**
  String get onbChooseTheme;

  /// No description provided for @themeAuto.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي'**
  String get themeAuto;

  /// No description provided for @themeChangeLater.
  ///
  /// In ar, this message translates to:
  /// **'تقدر تغيّره في أي وقت من الإعدادات'**
  String get themeChangeLater;

  /// No description provided for @onbTeamsTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر فرقك المفضلة'**
  String get onbTeamsTitle;

  /// No description provided for @onbTeamsBody.
  ///
  /// In ar, this message translates to:
  /// **'سنعرض مبارياتها أولاً ونذكّرك قبل انطلاقها.'**
  String get onbTeamsBody;

  /// No description provided for @onbSearchTeam.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن فريق...'**
  String get onbSearchTeam;

  /// No description provided for @onbTeamsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد فريقاً بهذا الاسم'**
  String get onbTeamsEmpty;

  /// No description provided for @onbTeamsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب اسماً آخر أو تخطَّ هذه الخطوة.'**
  String get onbTeamsEmptyBody;

  /// No description provided for @onbSatellitesTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الأقمار التي يستقبلها طبقك'**
  String get onbSatellitesTitle;

  /// No description provided for @onbSatellitesBody.
  ///
  /// In ar, this message translates to:
  /// **'سنعرض القنوات على أقمارك أولاً، والمجانية قبل المشفرة.'**
  String get onbSatellitesBody;

  /// No description provided for @mostUsed.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر استخداماً'**
  String get mostUsed;

  /// No description provided for @channelCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} قناة'**
  String channelCount(int count);

  /// No description provided for @onbSatellitesNote.
  ///
  /// In ar, this message translates to:
  /// **'إذا تخطيت هذه الخطوة سنعرض نايل سات وبدر افتراضياً.'**
  String get onbSatellitesNote;

  /// No description provided for @onbNotificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا تفوّت أي مباراة'**
  String get onbNotificationsTitle;

  /// No description provided for @onbNotificationsBody.
  ///
  /// In ar, this message translates to:
  /// **'فعّل التنبيهات لتصلك فقط عن الفرق والقنوات التي تتابعها.'**
  String get onbNotificationsBody;

  /// No description provided for @onbBenefitReminders.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل البداية مع القناة والتردد'**
  String get onbBenefitReminders;

  /// No description provided for @onbBenefitGoals.
  ///
  /// In ar, this message translates to:
  /// **'الأهداف والنتيجة النهائية'**
  String get onbBenefitGoals;

  /// No description provided for @onbBenefitFrequency.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر تردد قناة تتابعها'**
  String get onbBenefitFrequency;

  /// No description provided for @enableNotifications.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل التنبيهات'**
  String get enableNotifications;

  /// No description provided for @onbInstallTitle.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت مدار على iPhone'**
  String get onbInstallTitle;

  /// No description provided for @onbInstallBody.
  ///
  /// In ar, this message translates to:
  /// **'على iPhone لا تصل التنبيهات إلا بعد إضافة مدار إلى الشاشة الرئيسية وفتحه من أيقونته. يتطلب iOS 16.4 أو أحدث.'**
  String get onbInstallBody;

  /// No description provided for @onbInstallStep1.
  ///
  /// In ar, this message translates to:
  /// **'اضغط زر المشاركة في Safari'**
  String get onbInstallStep1;

  /// No description provided for @onbInstallStep2.
  ///
  /// In ar, this message translates to:
  /// **'اختر «إضافة إلى الشاشة الرئيسية»'**
  String get onbInstallStep2;

  /// No description provided for @onbInstallStep3.
  ///
  /// In ar, this message translates to:
  /// **'افتح مدار من أيقونته'**
  String get onbInstallStep3;

  /// No description provided for @s9Upcoming.
  ///
  /// In ar, this message translates to:
  /// **'مبارياتي القادمة'**
  String get s9Upcoming;

  /// No description provided for @s9ShowAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get s9ShowAll;

  /// No description provided for @s9TeamsSection.
  ///
  /// In ar, this message translates to:
  /// **'الفرق'**
  String get s9TeamsSection;

  /// No description provided for @s9CompetitionsSection.
  ///
  /// In ar, this message translates to:
  /// **'البطولات'**
  String get s9CompetitionsSection;

  /// No description provided for @s9EmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لم تتابع شيئاً بعد'**
  String get s9EmptyTitle;

  /// No description provided for @s9EmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'تابع فرقك لتصلك مبارياتها وتنبيهاتها.'**
  String get s9EmptyBody;

  /// No description provided for @addTeams.
  ///
  /// In ar, this message translates to:
  /// **'أضف فرقاً'**
  String get addTeams;

  /// No description provided for @s9NoUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'لا مباريات قادمة لفرقك الآن'**
  String get s9NoUpcoming;

  /// No description provided for @s9RemoveTeam.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name} من المفضلة'**
  String s9RemoveTeam(String name);

  /// No description provided for @todayAt.
  ///
  /// In ar, this message translates to:
  /// **'اليوم · {time}'**
  String todayAt(String time);

  /// No description provided for @dayAt.
  ///
  /// In ar, this message translates to:
  /// **'{weekday} · {time}'**
  String dayAt(String weekday, String time);

  /// No description provided for @s15SectionTime.
  ///
  /// In ar, this message translates to:
  /// **'التوقيت'**
  String get s15SectionTime;

  /// No description provided for @s15TimeZone.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة الزمنية'**
  String get s15TimeZone;

  /// No description provided for @s15AutomaticWithOffset.
  ///
  /// In ar, this message translates to:
  /// **'تلقائي ({offset})'**
  String s15AutomaticWithOffset(String offset);

  /// No description provided for @s15TimeFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة الوقت'**
  String get s15TimeFormat;

  /// No description provided for @s15H12.
  ///
  /// In ar, this message translates to:
  /// **'12 ساعة · {time}'**
  String s15H12(String time);

  /// No description provided for @s15H24.
  ///
  /// In ar, this message translates to:
  /// **'24 ساعة · {time}'**
  String s15H24(String time);

  /// No description provided for @s15SectionAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get s15SectionAppearance;

  /// No description provided for @s15Mode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع'**
  String get s15Mode;

  /// No description provided for @s15FontSize.
  ///
  /// In ar, this message translates to:
  /// **'حجم الخط'**
  String get s15FontSize;

  /// No description provided for @s15FontNote.
  ///
  /// In ar, this message translates to:
  /// **'يُضاف إلى حجم خط الجهاز'**
  String get s15FontNote;

  /// No description provided for @s15FontNormal.
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get s15FontNormal;

  /// No description provided for @s15FontLarge.
  ///
  /// In ar, this message translates to:
  /// **'كبير'**
  String get s15FontLarge;

  /// No description provided for @s15FontXLarge.
  ///
  /// In ar, this message translates to:
  /// **'كبير جداً'**
  String get s15FontXLarge;

  /// No description provided for @s15SectionSatellites.
  ///
  /// In ar, this message translates to:
  /// **'أقماري'**
  String get s15SectionSatellites;

  /// No description provided for @s15ChooseSatellites.
  ///
  /// In ar, this message translates to:
  /// **'اختر أقماري'**
  String get s15ChooseSatellites;

  /// No description provided for @s15NoSatellites.
  ///
  /// In ar, this message translates to:
  /// **'لم تختر أقماراً'**
  String get s15NoSatellites;

  /// No description provided for @s15SectionOnboarding.
  ///
  /// In ar, this message translates to:
  /// **'خطوات البداية'**
  String get s15SectionOnboarding;

  /// No description provided for @s15RestartOnboarding.
  ///
  /// In ar, this message translates to:
  /// **'إعادة خطوات البداية'**
  String get s15RestartOnboarding;

  /// No description provided for @s15SectionAbout.
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get s15SectionAbout;

  /// No description provided for @s15Version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get s15Version;

  /// No description provided for @s15Privacy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get s15Privacy;

  /// No description provided for @s15DeleteDevice.
  ///
  /// In ar, this message translates to:
  /// **'حذف بيانات جهازي'**
  String get s15DeleteDevice;

  /// No description provided for @s15DeleteDeviceBody.
  ///
  /// In ar, this message translates to:
  /// **'المتابعات ورمز الإشعارات من الخادم'**
  String get s15DeleteDeviceBody;

  /// No description provided for @s15DeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف بيانات جهازي؟'**
  String get s15DeleteTitle;

  /// No description provided for @s15DeleteConsequence.
  ///
  /// In ar, this message translates to:
  /// **'سنحذف متابعاتك ورمز الإشعارات من الخادم، وسيبدأ التطبيق من جديد.'**
  String get s15DeleteConsequence;

  /// No description provided for @s15Deleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت بيانات جهازك'**
  String get s15Deleted;

  /// No description provided for @s16InstallBody.
  ///
  /// In ar, this message translates to:
  /// **'لتصلك تنبيهات المباريات وتغيّر الترددات'**
  String get s16InstallBody;

  /// No description provided for @s16InstallRow.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت التطبيق'**
  String get s16InstallRow;

  /// No description provided for @s16Share.
  ///
  /// In ar, this message translates to:
  /// **'شارك التطبيق'**
  String get s16Share;

  /// No description provided for @s16ShareBody.
  ///
  /// In ar, this message translates to:
  /// **'ساعد في انتشار التطبيق'**
  String get s16ShareBody;

  /// No description provided for @s16SettingsBody.
  ///
  /// In ar, this message translates to:
  /// **'التوقيت، المظهر، أقماري'**
  String get s16SettingsBody;

  /// No description provided for @s16Tagline.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد المباريات والقنوات الناقلة والترددات'**
  String get s16Tagline;

  /// No description provided for @s16Version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String s16Version(String version);

  /// No description provided for @s16ShareText.
  ///
  /// In ar, this message translates to:
  /// **'مدار سات — {tagline} {link}'**
  String s16ShareText(String tagline, String link);

  /// No description provided for @s0UpdateTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديث مطلوب'**
  String get s0UpdateTitle;

  /// No description provided for @s0UpdateBody.
  ///
  /// In ar, this message translates to:
  /// **'يوجد إصدار جديد من التطبيق. يرجى التحديث للاستمرار.'**
  String get s0UpdateBody;

  /// No description provided for @s0YourVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدارك {version}'**
  String s0YourVersion(String version);

  /// No description provided for @s0UpdateNow.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الآن'**
  String get s0UpdateNow;

  /// No description provided for @s0UpdateOpensStore.
  ///
  /// In ar, this message translates to:
  /// **'يفتح صفحة التطبيق على Google Play'**
  String get s0UpdateOpensStore;

  /// No description provided for @s0OfflineBanner.
  ///
  /// In ar, this message translates to:
  /// **'أنت غير متصل — آخر تحديث {age}'**
  String s0OfflineBanner(String age);

  /// No description provided for @s0ExitToClose.
  ///
  /// In ar, this message translates to:
  /// **'اضغط رجوع مرة أخرى للخروج'**
  String get s0ExitToClose;

  /// No description provided for @s0LoadFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء الاتصال بالخادم. حاول مرة أخرى بعد قليل.'**
  String get s0LoadFailedBody;

  /// No description provided for @s0Retrying.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ المحاولة...'**
  String get s0Retrying;

  /// No description provided for @followMatch.
  ///
  /// In ar, this message translates to:
  /// **'تابع المباراة'**
  String get followMatch;

  /// No description provided for @followingMatch.
  ///
  /// In ar, this message translates to:
  /// **'تتابع المباراة'**
  String get followingMatch;

  /// No description provided for @unfollow.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المتابعة'**
  String get unfollow;

  /// No description provided for @s3ChooseSatellitesChip.
  ///
  /// In ar, this message translates to:
  /// **'حدد أقمارك'**
  String get s3ChooseSatellitesChip;

  /// No description provided for @remindersOn.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات مفعّلة'**
  String get remindersOn;

  /// No description provided for @remindersOff.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل التنبيهات'**
  String get remindersOff;

  /// No description provided for @pushPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات غير مسموحة لهذا التطبيق — افتح إعدادات الجهاز لتفعيلها'**
  String get pushPermissionDenied;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'طلبات كثيرة، حاول بعد {seconds} ثانية'**
  String errorRateLimited(int seconds);

  /// No description provided for @errorUnknownFollowTarget.
  ///
  /// In ar, this message translates to:
  /// **'بعض العناصر لم تعد متاحة، أزلناها من متابعاتك'**
  String get errorUnknownFollowTarget;

  /// No description provided for @errorTooManyFollows.
  ///
  /// In ar, this message translates to:
  /// **'وصلت للحد الأقصى ({max}) من المتابعات'**
  String errorTooManyFollows(int max);

  /// No description provided for @errorUnknownSatellite.
  ///
  /// In ar, this message translates to:
  /// **'أحد الأقمار لم يعد متاحاً، أعد اختيار أقماري'**
  String get errorUnknownSatellite;

  /// No description provided for @openChannel.
  ///
  /// In ar, this message translates to:
  /// **'عرض القناة'**
  String get openChannel;

  /// No description provided for @weekdayDay.
  ///
  /// In ar, this message translates to:
  /// **'{weekday} {day}'**
  String weekdayDay(String weekday, String day);

  /// No description provided for @s6FollowChannel.
  ///
  /// In ar, this message translates to:
  /// **'تابع القناة'**
  String get s6FollowChannel;

  /// No description provided for @s6FollowingChannel.
  ///
  /// In ar, this message translates to:
  /// **'تتابع القناة'**
  String get s6FollowingChannel;

  /// No description provided for @s6FollowChannelHint.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه عند تغيّر التردد'**
  String get s6FollowChannelHint;

  /// No description provided for @s6Copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get s6Copy;

  /// No description provided for @s6OtherSatellites.
  ///
  /// In ar, this message translates to:
  /// **'على أقمار أخرى'**
  String get s6OtherSatellites;

  /// No description provided for @s6UpcomingOnChannel.
  ///
  /// In ar, this message translates to:
  /// **'المباريات القادمة على القناة'**
  String get s6UpcomingOnChannel;

  /// No description provided for @s6FrequencyHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل التردد'**
  String get s6FrequencyHistory;

  /// No description provided for @s6Share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة القناة'**
  String get s6Share;

  /// No description provided for @s6ShareText.
  ///
  /// In ar, this message translates to:
  /// **'{name} على مدار سات'**
  String s6ShareText(String name);

  /// No description provided for @s6TuningWords.
  ///
  /// In ar, this message translates to:
  /// **'الاستقطاب {polarization} · معدل الترميز {rate}'**
  String s6TuningWords(String polarization, String rate);

  /// No description provided for @matchTabUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get matchTabUpcoming;

  /// No description provided for @matchTabResults.
  ///
  /// In ar, this message translates to:
  /// **'النتائج'**
  String get matchTabResults;

  /// No description provided for @s7Title.
  ///
  /// In ar, this message translates to:
  /// **'الفريق'**
  String get s7Title;

  /// No description provided for @s7FollowTeam.
  ///
  /// In ar, this message translates to:
  /// **'تابع الفريق'**
  String get s7FollowTeam;

  /// No description provided for @s7FollowingTeam.
  ///
  /// In ar, this message translates to:
  /// **'تتابع الفريق'**
  String get s7FollowingTeam;

  /// No description provided for @s7NoUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات قادمة'**
  String get s7NoUpcoming;

  /// No description provided for @s7NoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get s7NoResults;

  /// No description provided for @s7ListNote.
  ///
  /// In ar, this message translates to:
  /// **'تظهر المباريات التالية فور إعلان الجدول'**
  String get s7ListNote;

  /// No description provided for @s8Rights.
  ///
  /// In ar, this message translates to:
  /// **'حقوق البث'**
  String get s8Rights;

  /// No description provided for @s8FollowCompetition.
  ///
  /// In ar, this message translates to:
  /// **'تابع البطولة'**
  String get s8FollowCompetition;

  /// No description provided for @s8FollowingCompetition.
  ///
  /// In ar, this message translates to:
  /// **'تتابع البطولة'**
  String get s8FollowingCompetition;

  /// No description provided for @s8NoUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مباريات قادمة'**
  String get s8NoUpcoming;

  /// No description provided for @s8Title.
  ///
  /// In ar, this message translates to:
  /// **'البطولة'**
  String get s8Title;

  /// No description provided for @s8RightsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{جهة واحدة} =2{جهتان} few{{count} جهات} other{{count} جهة}}'**
  String s8RightsCount(int count);

  /// No description provided for @s8RightsLine.
  ///
  /// In ar, this message translates to:
  /// **'{satellites} · {competitions}'**
  String s8RightsLine(String satellites, String competitions);

  /// No description provided for @s8CompetitionsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بطولة واحدة} =2{بطولتان} few{{count} بطولات} other{{count} بطولة}}'**
  String s8CompetitionsCount(int count);
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
