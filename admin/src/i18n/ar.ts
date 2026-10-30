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
  | 'network_error';

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
};

const unknownErrorCopy = 'حدث خطأ غير متوقع. حاول مرة أخرى';

const isErrorCode = (code: string): code is ErrorCode => Object.hasOwn(errorCopy, code);

/** Arabic copy for an API `error.code`; unknown codes get a generic line, never the server text. */
export function copyForErrorCode(code: string): string {
  return isErrorCode(code) ? errorCopy[code] : unknownErrorCopy;
}
