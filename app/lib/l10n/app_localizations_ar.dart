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
}
