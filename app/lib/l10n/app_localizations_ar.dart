// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'مدار سات';

  @override
  String get brandMark => 'مدار';

  @override
  String get navMatches => 'المباريات';

  @override
  String get navSatellites => 'أقماري';

  @override
  String get navFrequencies => 'الترددات';

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get navMore => 'المزيد';

  @override
  String get search => 'بحث';

  @override
  String get back => 'رجوع';

  @override
  String get share => 'مشاركة';

  @override
  String get today => 'اليوم';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get gallery => 'معرض المكوّنات';

  @override
  String get emptyDayTitle => 'لا توجد مباريات في هذا اليوم';

  @override
  String get emptyDayBody => 'جرّب يوماً آخر أو اسحب القائمة لتحديثها.';

  @override
  String get emptyLiveTitle => 'لا توجد مباريات مباشرة الآن';

  @override
  String get emptyMyMatchesTitle => 'تابع فرقك لتظهر مبارياتها هنا';

  @override
  String get loadFailedTitle => 'تعذّر تحميل البيانات';

  @override
  String get noConnectionTitle => 'لا يوجد اتصال بالإنترنت';

  @override
  String get noConnectionBody => 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get timeTbd => 'لم يُحدد';

  @override
  String get live => 'مباشر';

  @override
  String get halftime => 'استراحة';

  @override
  String get extraTime => 'إضافي';

  @override
  String get penalties => 'ركلات الترجيح';

  @override
  String get finished => 'انتهت';

  @override
  String get postponed => 'تأجلت';

  @override
  String get cancelled => 'أُلغيت';

  @override
  String get abandoned => 'توقفت';

  @override
  String imminent(Object minutes) {
    return 'بعد $minutes د';
  }

  @override
  String get free => 'مجانية';

  @override
  String get encrypted => 'مشفرة';

  @override
  String get onMySatellites => 'على أقمارك';

  @override
  String get changedRecently => 'تغيّر مؤخراً';

  @override
  String get categorySports => 'رياضة';

  @override
  String get categoryEntertainment => 'ترفيه';

  @override
  String channelsMore(Object count) {
    return '+$count';
  }

  @override
  String get satellite => 'القمر';

  @override
  String get frequency => 'التردد';

  @override
  String get polarization => 'الاستقطاب';

  @override
  String get symbolRate => 'معدل الترميز';

  @override
  String get polHorizontal => 'أفقي';

  @override
  String get polVertical => 'رأسي';

  @override
  String get polLeft => 'يسار';

  @override
  String get polRight => 'يمين';

  @override
  String get copiedFrequency => 'تم نسخ التردد';

  @override
  String get frequencyNote => 'ملاحظة التردد';

  @override
  String get access => 'الوصول';

  @override
  String get category => 'الفئة';

  @override
  String get details => 'التفاصيل';

  @override
  String get amMarker => 'ص';

  @override
  String get pmMarker => 'م';

  @override
  String get errorNotFound => 'لم نجد ما تبحث عنه';

  @override
  String get errorValidation => 'تحقّق من البيانات المدخلة';

  @override
  String get errorInternal => 'حدث خطأ غير متوقع';

  @override
  String get errorNetwork => 'تعذّر الاتصال بالخادم';

  @override
  String get errorNotImplemented => 'هذه الخدمة غير متاحة بعد';

  @override
  String vs(Object away, Object home) {
    return '$home ضد $away';
  }

  @override
  String minuteShort(Object minute) {
    return '$minute′';
  }

  @override
  String minuteSemantics(Object minute) {
    return 'الدقيقة $minute';
  }

  @override
  String scoreSemantics(Object away, Object home) {
    return 'النتيجة $home مقابل $away';
  }

  @override
  String channelOn(Object channel) {
    return 'على $channel';
  }

  @override
  String get listSeparator => '، ';

  @override
  String get scoreSeparator => '-';

  @override
  String fullDate(Object day, Object month, Object weekday) {
    return '$weekday $day $month';
  }

  @override
  String get weekdayMon => 'الإثنين';

  @override
  String get weekdayTue => 'الثلاثاء';

  @override
  String get weekdayWed => 'الأربعاء';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get weekdayShortMon => 'إثنين';

  @override
  String get weekdayShortTue => 'ثلاثاء';

  @override
  String get weekdayShortWed => 'أربعاء';

  @override
  String get weekdayShortThu => 'خميس';

  @override
  String get weekdayShortFri => 'جمعة';

  @override
  String get weekdayShortSat => 'سبت';

  @override
  String get weekdayShortSun => 'أحد';

  @override
  String get month1 => 'يناير';

  @override
  String get month2 => 'فبراير';

  @override
  String get month3 => 'مارس';

  @override
  String get month4 => 'أبريل';

  @override
  String get month5 => 'مايو';

  @override
  String get month6 => 'يونيو';

  @override
  String get month7 => 'يوليو';

  @override
  String get month8 => 'أغسطس';

  @override
  String get month9 => 'سبتمبر';

  @override
  String get month10 => 'أكتوبر';

  @override
  String get month11 => 'نوفمبر';

  @override
  String get month12 => 'ديسمبر';

  @override
  String get statusEstimated => 'تقديري';

  @override
  String get copyFrequency => 'نسخ التردد';

  @override
  String get follow => 'تابع';

  @override
  String get following => 'المفضلة';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get country => 'الدولة';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get textScale => 'حجم الخط';

  @override
  String get filterAll => 'الكل';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String staleHint(Object age) {
    return 'آخر تحديث $age';
  }

  @override
  String get ageJustNow => 'الآن';

  @override
  String ageMinutes(Object count) {
    return 'منذ $count د';
  }

  @override
  String ageHours(Object count) {
    return 'منذ $count س';
  }

  @override
  String ageDays(Object count) {
    return 'منذ $count يوم';
  }

  @override
  String get commentator => 'المعلّق';

  @override
  String commentatorPlay(Object name) {
    return 'تشغيل مقطع صوتي لـ $name';
  }

  @override
  String get commentatorPause => 'إيقاف المقطع';

  @override
  String get commentatorLoading => 'جارٍ تحميل المقطع';

  @override
  String get commentatorPlaying => 'جاري التشغيل...';

  @override
  String get commentatorError => 'تعذّر تشغيل المقطع';

  @override
  String get receptionVideo => 'فيديو الاستقبال';

  @override
  String get s2TbdGroup => 'موعد لم يُحدد';

  @override
  String get s2ShowAllMatches => 'عرض كل المباريات';

  @override
  String get s3Title => 'تفاصيل المباراة';

  @override
  String get s3WhereToWatch => 'أين تشاهد';

  @override
  String s3OnSatellites(String satellites) {
    return 'على $satellites';
  }

  @override
  String get s3OnDefaultSatellites => 'على نايل سات وبدر';

  @override
  String s3StartsInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبدأ بعد $count دقيقة',
      few: 'تبدأ بعد $count دقائق',
      two: 'تبدأ بعد دقيقتين',
      one: 'تبدأ بعد دقيقة',
    );
    return '$_temp0';
  }

  @override
  String s3StartsInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبدأ بعد $count ساعة',
      few: 'تبدأ بعد $count ساعات',
      two: 'تبدأ بعد ساعتين',
      one: 'تبدأ بعد ساعة',
    );
    return '$_temp0';
  }

  @override
  String s3StartsInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبدأ بعد $count يوم',
      few: 'تبدأ بعد $count أيام',
      two: 'تبدأ بعد يومين',
      one: 'تبدأ بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String s3ChannelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قناة',
      few: '$count قنوات',
      two: 'قناتان',
      one: 'قناة واحدة',
    );
    return '$_temp0';
  }

  @override
  String s3SatellitesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قمرًا',
      few: '$count أقمار',
      two: 'قمرين',
      one: 'قمر واحد',
    );
    return '$_temp0';
  }

  @override
  String s3PlatformsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منصة',
      few: '$count منصات',
      two: 'منصتان',
      one: 'منصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String s3ChannelsOnSatellites(Object channels, Object satellites) {
    return '$channels على $satellites';
  }

  @override
  String get s3FreeOnly => 'المجانية فقط';

  @override
  String get s3SearchHint => 'ابحث عن قمر أو قناة...';

  @override
  String get s3OtherSatellites => 'أقمار أخرى';

  @override
  String get s3OtherPlatforms => 'منصات وقنوات أخرى';

  @override
  String get s3NoSatellite => 'بدون قمر';

  @override
  String get s3NothingOnMySatellites =>
      'لا توجد قنوات على أقمارك لهذه المباراة';

  @override
  String get s3NoResults => 'لا توجد قنوات مطابقة لبحثك';

  @override
  String get s3BackToTop => 'العودة لأعلى القنوات';

  @override
  String get s3BroadcastOn => 'يعرض على';

  @override
  String get s3BroadcastAlsoOn => 'يعرض أيضاً على';

  @override
  String get s3MatchInfo => 'معلومات المباراة';

  @override
  String get s3Stadium => 'الملعب';

  @override
  String get s3LocalBroadcasterEg => 'القناة الناقلة في مصر';

  @override
  String get s3NoChannelsTitle => 'لم تُضف القنوات الناقلة بعد';

  @override
  String get s3NoChannelsBody => 'ستظهر القنوات والترددات هنا فور إضافتها.';

  @override
  String get s3Refresh => 'تحديث';

  @override
  String get s3OpenFailed => 'تعذّر فتح الرابط';

  @override
  String s3DateTime(Object date, Object time) {
    return '$date · $time';
  }

  @override
  String s4NoMatchesTitle(Object satellites) {
    return 'لا توجد مباريات على $satellites لهذا اليوم';
  }

  @override
  String get s4NoMatchesBody => 'اسحب القائمة لتحديثها.';

  @override
  String get s4NoSatellitesTitle => 'لم تختر أقماراً بعد';

  @override
  String get s4NoSatellitesBody =>
      'اختر قمراً واحداً على الأقل لتظهر المباريات المنقولة عليه.';

  @override
  String get s4ChooseSatellites => 'اختر أقمارك';

  @override
  String get s5SearchSatellites => 'ابحث عن قمر...';

  @override
  String s5SatelliteCount(Object count) {
    return '$count قمراً';
  }

  @override
  String get s5SectionAll => 'كل الأقمار';

  @override
  String get s5MineMarker => 'طبقي';

  @override
  String s5ChannelCount(Object count) {
    return '$count قناة';
  }

  @override
  String get s5NoSatellitesTitle => 'لا توجد أقمار مطابقة';

  @override
  String get s5NoSatellitesBody => 'جرّب اسماً أو موقعاً آخر.';

  @override
  String get s5ReceptionHowTo => 'طريقة استقبال القمر';

  @override
  String get s5ReceptionOpenFailed => 'تعذّر فتح الفيديو';

  @override
  String get s5StrongestFrequency => 'أقوى تردد';

  @override
  String get s5WeakestFrequency => 'أضعف تردد';

  @override
  String get s5SearchChannels => 'بحث في القنوات...';

  @override
  String s5CategoryTab(Object count, Object label) {
    return '$label $count';
  }

  @override
  String get s5NoSportsTitle => 'لا توجد قنوات رياضة على هذا القمر';

  @override
  String get s5NoEntertainmentTitle => 'لا توجد قنوات ترفيه على هذا القمر';

  @override
  String get s5NoResultsTitle => 'لا توجد قنوات مطابقة';

  @override
  String get s5NoResultsBody => 'جرّب اسم قناة أو أرقاماً من التردد.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get skip => 'تخطي';

  @override
  String get next => 'التالي';

  @override
  String nextCount(int count) {
    return 'التالي ($count)';
  }

  @override
  String get gotIt => 'فهمت';

  @override
  String get later => 'لاحقاً';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get add => 'أضف';

  @override
  String onbProgress(int step, int count) {
    return 'الخطوة $step من $count';
  }

  @override
  String get onbWelcomeTitle => 'مرحباً بك في مدار';

  @override
  String get onbWelcomeBody =>
      'مباراتك، القناة الناقلة، وترددها على طبقك — في مكان واحد.';

  @override
  String get onbChooseTheme => 'اختر المظهر';

  @override
  String get themeAuto => 'تلقائي';

  @override
  String get themeChangeLater => 'تقدر تغيّره في أي وقت من الإعدادات';

  @override
  String get onbTeamsTitle => 'اختر فرقك المفضلة';

  @override
  String get onbTeamsBody => 'سنعرض مبارياتها أولاً ونذكّرك قبل انطلاقها.';

  @override
  String get onbSearchTeam => 'ابحث عن فريق...';

  @override
  String get onbTeamsEmpty => 'لم نجد فريقاً بهذا الاسم';

  @override
  String get onbTeamsEmptyBody => 'جرّب اسماً آخر أو تخطَّ هذه الخطوة.';

  @override
  String get onbSatellitesTitle => 'اختر الأقمار التي يستقبلها طبقك';

  @override
  String get onbSatellitesBody =>
      'سنعرض القنوات على أقمارك أولاً، والمجانية قبل المشفرة.';

  @override
  String get mostUsed => 'الأكثر استخداماً';

  @override
  String channelCount(int count) {
    return '$count قناة';
  }

  @override
  String get onbSatellitesNote =>
      'إذا تخطيت هذه الخطوة سنعرض نايل سات وبدر افتراضياً.';

  @override
  String get onbNotificationsTitle => 'لا تفوّت أي مباراة';

  @override
  String get onbNotificationsBody =>
      'فعّل التنبيهات لتصلك فقط عن الفرق والقنوات التي تتابعها.';

  @override
  String get onbBenefitReminders => 'تذكير قبل البداية مع القناة والتردد';

  @override
  String get onbBenefitGoals => 'الأهداف والنتيجة النهائية';

  @override
  String get onbBenefitFrequency => 'تغيّر تردد قناة تتابعها';

  @override
  String get enableNotifications => 'تفعيل التنبيهات';

  @override
  String get onbInstallTitle => 'ثبّت مدار على iPhone';

  @override
  String get onbInstallBody =>
      'على iPhone لا تصل التنبيهات إلا بعد إضافة مدار إلى الشاشة الرئيسية وفتحه من أيقونته. يتطلب iOS 16.4 أو أحدث.';

  @override
  String get onbInstallStep1 => 'اضغط زر المشاركة في Safari';

  @override
  String get onbInstallStep2 => 'اختر «إضافة إلى الشاشة الرئيسية»';

  @override
  String get onbInstallStep3 => 'افتح مدار من أيقونته';

  @override
  String get s9Upcoming => 'مبارياتي القادمة';

  @override
  String get s9ShowAll => 'عرض الكل';

  @override
  String get s9TeamsSection => 'الفرق';

  @override
  String get s9EmptyTitle => 'لم تتابع شيئاً بعد';

  @override
  String get s9EmptyBody => 'تابع فرقك لتصلك مبارياتها وتنبيهاتها.';

  @override
  String get addTeams => 'أضف فرقاً';

  @override
  String get s9NoUpcoming => 'لا مباريات قادمة لفرقك الآن';

  @override
  String s9RemoveTeam(String name) {
    return 'إزالة $name من المفضلة';
  }

  @override
  String todayAt(String time) {
    return 'اليوم · $time';
  }

  @override
  String dayAt(String weekday, String time) {
    return '$weekday · $time';
  }

  @override
  String get s15SectionTime => 'التوقيت';

  @override
  String get s15TimeZone => 'المنطقة الزمنية';

  @override
  String s15AutomaticWithOffset(String offset) {
    return 'تلقائي ($offset)';
  }

  @override
  String get s15TimeFormat => 'صيغة الوقت';

  @override
  String s15H12(String time) {
    return '12 ساعة · $time';
  }

  @override
  String s15H24(String time) {
    return '24 ساعة · $time';
  }

  @override
  String get s15SectionAppearance => 'المظهر';

  @override
  String get s15Mode => 'الوضع';

  @override
  String get s15FontSize => 'حجم الخط';

  @override
  String get s15FontNote => 'يُضاف إلى حجم خط الجهاز';

  @override
  String get s15FontNormal => 'عادي';

  @override
  String get s15FontLarge => 'كبير';

  @override
  String get s15FontXLarge => 'كبير جداً';

  @override
  String get s15SectionSatellites => 'أقماري';

  @override
  String get s15ChooseSatellites => 'اختر أقماري';

  @override
  String get s15NoSatellites => 'لم تختر أقماراً';

  @override
  String get s15SectionOnboarding => 'خطوات البداية';

  @override
  String get s15RestartOnboarding => 'إعادة خطوات البداية';

  @override
  String get s15SectionAbout => 'عن التطبيق';

  @override
  String get s15Version => 'الإصدار';

  @override
  String get s15Privacy => 'سياسة الخصوصية';

  @override
  String get s15DeleteDevice => 'حذف بيانات جهازي';

  @override
  String get s15DeleteDeviceBody => 'المتابعات ورمز الإشعارات من الخادم';

  @override
  String get s15DeleteTitle => 'حذف بيانات جهازي؟';

  @override
  String get s15DeleteConsequence =>
      'سنحذف متابعاتك ورمز الإشعارات من الخادم، وسيبدأ التطبيق من جديد.';

  @override
  String get s15Deleted => 'حُذفت بيانات جهازك';

  @override
  String get s16InstallBody => 'لتصلك تنبيهات المباريات وتغيّر الترددات';

  @override
  String get s16Share => 'شارك التطبيق';

  @override
  String get s16ShareBody => 'ساعد في انتشار التطبيق';

  @override
  String get s16SettingsBody => 'التوقيت، المظهر، أقماري';

  @override
  String get s16Tagline => 'مواعيد المباريات والقنوات الناقلة والترددات';

  @override
  String s16Version(String version) {
    return 'الإصدار $version';
  }

  @override
  String s16ShareText(String tagline, String link) {
    return 'مدار سات — $tagline $link';
  }

  @override
  String get s0UpdateTitle => 'تحديث مطلوب';

  @override
  String get s0UpdateBody =>
      'يوجد إصدار جديد من التطبيق. يرجى التحديث للاستمرار.';

  @override
  String s0YourVersion(String version) {
    return 'إصدارك $version';
  }

  @override
  String get s0UpdateNow => 'تحديث الآن';

  @override
  String get s0UpdateOpensStore => 'يفتح صفحة التطبيق على Google Play';

  @override
  String s0OfflineBanner(String age) {
    return 'أنت غير متصل — آخر تحديث $age';
  }

  @override
  String get s0ExitToClose => 'اضغط رجوع مرة أخرى للخروج';

  @override
  String get s0LoadFailedBody =>
      'حدث خطأ أثناء الاتصال بالخادم. حاول مرة أخرى بعد قليل.';

  @override
  String get s0Retrying => 'جارٍ المحاولة...';

  @override
  String get followMatch => 'تابع المباراة';

  @override
  String get followingMatch => 'تتابع المباراة';

  @override
  String get unfollow => 'إلغاء المتابعة';

  @override
  String get s3ChooseSatellitesChip => 'حدد أقمارك';

  @override
  String get remindersOn => 'التنبيهات مفعّلة';

  @override
  String get remindersOff => 'تفعيل التنبيهات';

  @override
  String get pushPermissionDenied =>
      'الإشعارات غير مسموحة لهذا التطبيق — افتح إعدادات الجهاز لتفعيلها';

  @override
  String errorRateLimited(int seconds) {
    return 'طلبات كثيرة، حاول بعد $seconds ثانية';
  }

  @override
  String get errorUnknownFollowTarget =>
      'بعض العناصر لم تعد متاحة، أزلناها من متابعاتك';

  @override
  String errorTooManyFollows(int max) {
    return 'وصلت للحد الأقصى ($max) من المتابعات';
  }

  @override
  String get errorUnknownSatellite =>
      'أحد الأقمار لم يعد متاحاً، أعد اختيار أقماري';
}
