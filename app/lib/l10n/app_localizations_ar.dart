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
  String get commentatorPlaying => 'يُشغَّل الآن';

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
}
