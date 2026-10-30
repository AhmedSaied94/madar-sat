// All admin copy (constitution III: externalized Arabic, product doc §14 voice).
// API errors are shown only through `errorCopy`, keyed by `error.code`; `error.message` is never rendered.

export const brand = {
  wordmark: 'مدار',
  tag: 'ADMIN',
} as const;

export const navGroups = {
  content: 'المحتوى',
  operations: 'التشغيل',
  administration: 'الإدارة',
} as const;

// A0 sidebar labels in product doc §10 A0 order.
export const navLabels = {
  dashboard: 'لوحة المتابعة',
  matches: 'المباريات',
  teams: 'الفرق',
  competitions: 'البطولات',
  channels: 'القنوات',
  satellites: 'الأقمار',
  rightsHolders: 'حقوق البث',
  commentators: 'المعلقون',
  feeds: 'الفيدات',
  lists: 'القوائم',
  sources: 'المصادر',
  reports: 'البلاغات',
  notifications: 'الإشعارات',
  users: 'المستخدمون',
  audit: 'سجل التغييرات',
} as const;

export const sidebar = {
  label: 'القائمة الرئيسية',
  plannedTag: 'V2',
  plannedHint: 'مخطط للإصدار الثاني',
  countWaiting: 'بانتظار العمل',
  countFailing: 'مصدر متعطل',
  countNeutral: 'عناصر',
  logout: 'تسجيل الخروج',
} as const;

export const roles = {
  admin: 'مدير',
  editor: 'محرر',
} as const;

export const shell = {
  searchLabel: 'بحث شامل',
  searchPlaceholder: 'ابحث عن مباراة، فريق، قناة أو تردد...',
  searchShortcut: 'Ctrl K',
  userLabel: 'المستخدم الحالي',
  comingSoonTitle: 'هذا القسم قيد البناء',
  comingSoonBody: 'تصل شاشات الإدارة تباعاً خلال الأيام القادمة.',
} as const;

export const login = {
  formLabel: 'تسجيل الدخول',
  title: 'سجل دخول للوحة التحكم',
  email: 'البريد الإلكتروني',
  password: 'كلمة المرور',
  showPassword: 'إظهار كلمة المرور',
  hidePassword: 'إخفاء كلمة المرور',
  submit: 'دخول',
  submitting: 'جارٍ الدخول…',
  wireguardOnly: 'متاح فقط عبر شبكة WireGuard',
  emailInvalid: 'أدخل بريداً إلكترونياً صحيحاً',
  passwordRequired: 'أدخل كلمة المرور',
  passwordTooLong: 'كلمة المرور أطول من المسموح',
  lockedTitle: 'تم إيقاف الدخول مؤقتاً',
  lockedBefore: 'محاولات كثيرة غير صحيحة لهذا الحساب. حاول مرة أخرى بعد',
  lockedAfter: 'دقيقة أو تواصل مع المدير.',
} as const;

/** «تبقّت N محاولات قبل الإيقاف المؤقت», with the Arabic number agreement for 0, 1 and 2. */
export function attemptsRemaining(count: number): string {
  if (count <= 0) return 'لم تتبقَّ محاولات قبل الإيقاف المؤقت';
  if (count === 1) return 'تبقّت محاولة واحدة قبل الإيقاف المؤقت';
  if (count === 2) return 'تبقّت محاولتان قبل الإيقاف المؤقت';
  return `تبقّت ${count} محاولات قبل الإيقاف المؤقت`;
}

export const toast = {
  saved: 'تم الحفظ',
  saveFailed: 'فشل الحفظ',
  undo: 'تراجع',
  retry: 'إعادة المحاولة',
  dismiss: 'إغلاق',
} as const;

export const statusChips = {
  sent: 'أُرسل',
  failed: 'فشل',
  partial: 'جزئي',
  scheduled: 'مجدول',
  live: 'مباشر',
  manualSource: 'يدوي',
  healthOk: 'سليم',
  healthNearLimit: 'قرب الحد',
  healthOpen: 'مفتوحة',
} as const;

export const table = {
  selectAll: 'تحديد الكل',
  selectRow: 'تحديد الصف',
  selectNamed: (name: string): string => `تحديد ${name}`,
  selectedCount: (count: number): string => `تم تحديد ${count}`,
  bulkActions: 'إجراءات على المحدد',
  sortAscending: 'ترتيب تصاعدي',
  sortDescending: 'ترتيب تنازلي',
  rowActions: 'إجراءات الصف',
  locked: 'قيمة مقفلة: لن يغيّرها الاستيراد',
  warning: 'يحتاج مراجعة',
  loading: 'جارٍ التحميل',
  empty: 'لا توجد بيانات لعرضها',
} as const;

export const field = {
  lockedHint: 'لن يغيّره الاستيراد',
  lockedLabel: 'مقفل من المحرر',
} as const;

export const dialogs = {
  cancel: 'إلغاء',
  typeToConfirm: (phrase: string): string => `للتأكيد اكتب ${phrase}`,
  confirmInput: 'نص التأكيد',
  conflictTitleAdminPrefix: 'عدّل',
  conflictTitleSourcePrefix: 'حدّث',
  conflictTitleSuffix: 'هذا العنصر',
  conflictBody: (subject: string, cairoTime: string): string =>
    `حُفظت نسخة أحدث من «${subject}» في ${cairoTime} بتوقيت القاهرة. تعديلاتك لم تُحفظ بعد.`,
  showChanges: 'اعرض التغييرات',
  hideChanges: 'أخفِ التغييرات',
  reload: 'إعادة التحميل',
  discard: 'تجاهل تعديلاتي',
  before: 'قبل',
  after: 'بعد',
} as const;

/** The API's nine match statuses, in A3's chip and A4's override (data-model). */
export const matchStatus = {
  scheduled: 'مجدولة',
  live: 'مباشر',
  halftime: 'بين الشوطين',
  extra_time: 'وقت إضافي',
  penalties: 'ركلات ترجيح',
  finished: 'انتهت',
  postponed: 'مؤجلة',
  cancelled: 'ملغاة',
  abandoned: 'متوقفة',
} as const;

export const matches = {
  title: 'المباريات',
  add: 'إضافة مباراة',
  summary: (count: number, competitions: number, missing: number): string =>
    `${count} مباراة · ${competitions} بطولة · ${missing} بلا قنوات`,
  yesterday: 'أمس',
  today: 'اليوم',
  tomorrow: 'غداً',
  afterTomorrow: 'بعد غد',
  pickDate: 'تاريخ…',
  dayLabel: 'اليوم',
  teamFilter: 'فريق في هذا اليوم',
  competitionFilter: 'البطولة',
  sourceFilter: 'المصدر',
  statusFilter: 'الحالة',
  all: 'الكل',
  missingOnly: 'بلا قنوات فقط',
  columns: {
    time: 'الوقت',
    match: 'المباراة',
    status: 'الحالة',
    channels: 'القنوات',
    commentator: 'المعلق',
    source: 'المصدر',
    locked: 'حقول مقفلة',
    edit: 'تعديل',
    more: 'المزيد',
  },
  groupCount: (count: number): string => `${count}`,
  groupMissing: (count: number): string => `${count} بلا قنوات`,
  selected: (count: number): string => `تم تحديد ${count}`,
  bulkToolbar: 'إجراءات جماعية',
  bulk: {
    changeCompetition: 'تغيير البطولة',
    removeChannels: 'إزالة القنوات',
    cancel: 'إلغاء',
    removePhrase: (count: number): string => `إزالة القنوات من ${count}`,
    removeTitle: (count: number): string => `إزالة القنوات من ${count} مباراة؟`,
    removeBody: 'ستُزال كل قنوات هذه المباريات الظاهرة، مع إعداداتها لهذا الماتش. لا يمكن التراجع.',
    competitionTitle: 'تغيير بطولة المباريات المحددة',
    competitionBody: 'ستنتقل كل المباريات المحددة إلى البطولة التي تختارها.',
    confirm: 'تغيير',
  },
  empty: {
    title: 'لا مباريات في هذا اليوم',
    body: 'جرّب يوماً آخر أو أزل الفلاتر.',
    allClearTitle: 'كل مباريات اليوم لها قنوات',
    allClearBody: 'لا توجد مباريات بلا قنوات في هذا اليوم.',
    allClearAction: 'إزالة الفلتر',
  },
  showing: (shown: number, total: number): string => `عرض ${shown} من ${total}`,
  keyboard: 'للتنقل',
  statusHint: 'تقديري',
} as const;

/** A4 (admin board "Match editor"). */
export const editor = {
  breadcrumbRoot: 'المباريات',
  newMatch: 'مباراة جديدة',
  preview: 'معاينة',
  save: 'حفظ',
  saving: 'جارٍ الحفظ',
  discard: 'تجاهل',
  detailsTab: 'التفاصيل',
  historyTab: 'السجل',
  teamsAndTime: 'الفريقان والموعد',
  homeTeam: 'صاحب الأرض',
  awayTeam: 'الضيف',
  date: 'التاريخ',
  time: 'الوقت',
  cairoNote: 'بتوقيت القاهرة',
  savedAs: (utc: string): string => `يُحفظ ${utc} UTC`,
  timeTbd: 'الموعد لم يتحدد',
  competition: 'البطولة',
  stadium: 'الملعب',
  stage: 'المرحلة',
  teamSearch: 'ابحث عن فريق',
  freeText: 'أو اكتب اسماً',
  channels: 'القنوات الناقلة',
  channelCount: (count: number): string => `${count} قناة`,
  addChannel: 'إضافة قناة',
  searchChannel: 'ابحث عن قناة',
  category: 'التصنيف',
  all: 'الكل',
  sports: 'رياضة',
  entertainment: 'ترفيه',
  platform: 'منصة',
  searching: 'جارٍ البحث…',
  noChannels: 'لا قنوات بهذا البحث',
  add: 'إضافة',
  remove: 'إزالة',
  hideFromMatch: 'إخفاء من هذا الماتش فقط',
  hideAlways: 'إخفاء دائماً',
  hiddenAlways: 'مخفية دائماً',
  show: 'إظهار',
  hidePhrase: 'إخفاء دائماً',
  hideTitle: (name: string): string => `إخفاء «${name}» دائماً؟`,
  hideBody: 'لن تظهر هذه القناة في أي مباراة بعد الآن، ولن يعيدها أي مصدر.',
  commentator: (slot: number): string => `المعلق ${slot}`,
  none: 'بدون معلق',
  manualBroadcast: 'البث اليدوي',
  slot1: 'يعرض على',
  slot2: 'يعرض أيضاً على',
  pickFromList: 'اختر من القائمة أو اكتب اسماً',
  statusTitle: 'الحالة والنتيجة',
  status: 'الحالة',
  autoStatus: 'تلقائي · من المصدر',
  manualHint: 'اختيار حالة يدوياً يتقدم على المصدر حتى تعيده إلى «تلقائي».',
  home: 'صاحب الأرض',
  away: 'الضيف',
  scoreLabel: 'النتيجة',
  penalties: 'ركلات الترجيح',
  scoreNotAllowed: 'لا نتيجة لهذه الحالة',
  lockedFields: 'الحقول المقفلة',
  lockedHint: 'لن تغيّر المصادر هذه الحقول. يُقفل الحقل تلقائياً عند تعديله يدوياً.',
  unsaved: 'لديك تغييرات غير محفوظة',
  unsavedBody: 'إذا غادرت الآن ستفقد تعديلات القنوات والمرحلة.',
  leave: 'غادر دون حفظ',
  stay: 'ابقَ',
  saveAndLeave: 'احفظ وغادر',
  noEvents: 'لم تبدأ المباراة بعد.',
} as const;

export type ErrorCode =
  | 'invalid_credentials'
  | 'account_locked'
  | 'validation_error'
  | 'not_implemented'
  | 'csrf_failed'
  | 'refresh_invalid'
  | 'unauthenticated'
  | 'token_expired'
  | 'internal_error'
  | 'network_error'
  | 'invalid_response'
  | 'forbidden'
  | 'edit_conflict'
  | 'in_use'
  | 'already_exists'
  | 'file_too_large'
  | 'unsupported_media_type'
  | 'media_invalid'
  | 'precondition_required'
  | 'match_not_found'
  | 'team_not_found'
  | 'competition_not_found'
  | 'satellite_not_found'
  | 'channel_not_found'
  | 'commentator_not_found'
  | 'hidden_name_not_found';

export const errorCopy: Record<ErrorCode, string> = {
  invalid_credentials: 'إيميل أو باسوورد غلط',
  account_locked: 'تم إيقاف الدخول مؤقتاً',
  validation_error: 'راجع البيانات المدخلة ثم حاول مرة أخرى',
  not_implemented: 'هذه الخدمة غير متاحة بعد',
  csrf_failed: 'انتهت صلاحية الجلسة الآمنة. حدّث الصفحة وحاول مرة أخرى',
  refresh_invalid: 'انتهت الجلسة. سجّل الدخول مرة أخرى',
  unauthenticated: 'سجّل الدخول للمتابعة',
  token_expired: 'انتهت الجلسة. سجّل الدخول مرة أخرى',
  internal_error: 'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل',
  network_error: 'تعذّر الاتصال بالخادم. تأكد من اتصال WireGuard وحاول مرة أخرى',
  invalid_response: 'رد غير متوقع من الخادم. حاول مرة أخرى',
  forbidden: 'صلاحيتك لا تسمح بهذا الإجراء',
  edit_conflict: 'عُدّل هذا العنصر من شخص آخر. راجع التغييرات قبل الحفظ',
  in_use: 'هذا العنصر مستخدم في مكان آخر. أزله من هناك أولاً',
  already_exists: 'يوجد عنصر بنفس القيمة بالفعل',
  file_too_large: 'الملف أكبر من الحد المسموح',
  unsupported_media_type: 'نوع الملف غير مدعوم',
  media_invalid: 'تعذّر قراءة الملف. جرّب ملفاً آخر',
  precondition_required: 'أعد تحميل الصفحة ثم حاول مرة أخرى',
  match_not_found: 'هذه المباراة غير موجودة. ربما حُذفت',
  team_not_found: 'هذا الفريق غير موجود. ربما حُذف',
  competition_not_found: 'هذه البطولة غير موجودة. ربما حُذفت',
  satellite_not_found: 'هذا القمر غير موجود. ربما حُذف',
  channel_not_found: 'هذه القناة غير موجودة. ربما حُذفت',
  commentator_not_found: 'هذا المعلق غير موجود. ربما حُذف',
  hidden_name_not_found: 'هذا الاسم غير مخفي',
};

const unknownErrorCopy = 'حدث خطأ غير متوقع. حاول مرة أخرى';

const isErrorCode = (code: string): code is ErrorCode => Object.hasOwn(errorCopy, code);

/** Arabic copy for an API `error.code`; unknown codes get a generic line, never the server text. */
export function copyForErrorCode(code: string): string {
  return isErrorCode(code) ? errorCopy[code] : unknownErrorCopy;
}
