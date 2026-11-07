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
  restoring: 'جارٍ استعادة الجلسة',
  /** What a role can't open: the server refuses it too, and the shell never draws a link to it. */
  notPermittedBody: 'هذا القسم للمديرين فقط. ارجع إلى لوحة المتابعة.',
  notPermittedBack: 'لوحة المتابعة',
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
  healthNeutral: 'متوقف',
  stopped: 'متوقف',
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

/** LogoField: the two neutral grounds every logo is previewed on (Logo README, T095). */
export const logoPreview = {
  onDark: 'على خلفية داكنة',
  onLight: 'على خلفية فاتحة',
} as const;

/** FrequencyReadout: the dark LTR well, its labels, and what a screen reader hears. */
export const readout = {
  symbolRate: 'معدل الترميز',
  /** «التردد 11843، أفقي، معدل الترميز 27500». */
  spoken: (mhz: number, polarization: string, sr: number): string =>
    `التردد ${mhz}، ${polarization}، معدل الترميز ${sr}`,
  polarizations: {
    H: 'أفقي',
    V: 'رأسي',
    L: 'دائري يسار',
    R: 'دائري يمين',
  } as Record<string, string>,
} as const;

/** Zod's own messages, in the admin's voice, so no schema refusal ever reaches the screen in English. */
export const validation = {
  required: 'هذا الحقل مطلوب',
  tooLong: 'النص أطول من الحد المسموح',
  invalid: 'قيمة غير صحيحة',
  number: 'أدخل رقماً صحيحاً',
  position: 'أدخل موقعاً بين 0 و 180 درجة',
  satelliteRequired: 'اختر قمراً، أو اجعل القناة منصة بلا قمر',
  frequencyRequired: 'أدخل التردد ومعدل الترميز، أو أزل «إظهار في صفحات المباريات»',
  frequencyRequiredOnSatellite: 'أدخل التردد ومعدل الترميز لتحويل القناة إلى قناة على قمر',
} as const;

export const dialogs = {
  cancel: 'إلغاء',
  typeToConfirm: (phrase: string): string => `للتأكيد اكتب ${phrase}`,
  confirmInput: 'نص التأكيد',
  conflictTitleAdminPrefix: 'عدّل',
  conflictTitleSourcePrefix: 'حدّث',
  conflictTitleSuffix: 'هذا العنصر',
  /** The other side's save, with the subject as its own island: «حُفظت نسخة أحدث من «…» في …». */
  conflictBodyBefore: 'حُفظت نسخة أحدث من «',
  conflictBodyAfter: (cairoTime: string): string =>
    `» في ${cairoTime} بتوقيت القاهرة. تعديلاتك لم تُحفظ بعد.`,
  /** `meta.changed_at` was missing: say so instead of showing the client's clock as their save time (A-R2-7). */
  conflictTimeUnknown: '» في وقت غير معروف. تعديلاتك لم تُحفظ بعد.',
  showChanges: 'اعرض التغييرات',
  hideChanges: 'أخفِ التغييرات',
  noChanges: 'لم يتغيّر أي حقل تعرضه هذه الشاشة.',
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
  missingChannels: 'بلا قنوات',
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
    /** A `409` from a bulk write names the rows whose version moved (A-R1-3); the names stay islands (A-R2-9). */
    staleBefore: 'تغيّرت هذه المباريات منذ عرض القائمة: ',
    staleAfter: '. حدّث القائمة ثم أعد المحاولة',
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
  /** A row with no kickoff the sources know yet (A-R1-24). */
  timeUnknown: 'لم يُحدد',
} as const;

/** A4 (admin board "Match editor"). */
export const editor = {
  breadcrumbRoot: 'المباريات',
  newMatch: 'مباراة جديدة',
  preview: 'معاينة',
  save: 'حفظ',
  saving: 'جارٍ الحفظ',
  loading: 'جارٍ تحميل المباراة',
  loadFailedBody: 'تحقق من الاتصال ثم أعد المحاولة، أو ارجع إلى القائمة.',
  backToMatches: 'رجوع إلى المباريات',
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
  /** US4 scenario 4's stages, as suggestions over free text (A-R2-5). */
  stagePresets: [
    'الجولة الأولى',
    'ذهاب دور 16',
    'إياب دور 16',
    'ربع النهائي',
    'نصف النهائي',
    'النهائي',
  ],
  teamSearch: 'ابحث عن فريق',
  freeText: 'أو اكتب اسماً',
  channels: 'القنوات الناقلة',
  channelCount: (count: number): string => `${count} قناة`,
  addChannel: 'إضافة قناة',
  searchChannel: 'ابحث عن قناة',
  category: 'التصنيف',
  satellite: 'القمر',
  noSatellite: 'منصات بلا قمر',
  all: 'الكل',
  sports: 'رياضة',
  entertainment: 'ترفيه',
  platform: 'منصة',
  searching: 'جارٍ البحث…',
  noChannels: 'لا قنوات بهذا البحث',
  add: 'إضافة',
  choose: 'اختيار',
  selected: 'مختارة',
  remove: 'إزالة',
  hideFromMatch: 'إخفاء من هذا الماتش فقط',
  hideAlways: 'إخفاء دائماً',
  hiddenAlways: 'مخفية دائماً',
  show: 'إظهار',
  hidePhrase: 'إخفاء دائماً',
  /** «إخفاء «<name>» دائماً؟» built from its parts, so the Latin name stays its own island (A-R1-18). */
  hideTitleBefore: 'إخفاء ',
  hideTitleAfter: ' دائماً؟',
  hideBody: 'لن تظهر هذه القناة في أي مباراة بعد الآن، ولن يعيدها أي مصدر.',
  commentator: (slot: number): string => `المعلق ${slot}`,
  none: 'بدون معلق',
  manualBroadcast: 'البث اليدوي',
  slot1: 'يعرض على',
  slot2: 'يعرض أيضاً على',
  pickFromList: 'اختر من القائمة أو اكتب اسماً',
  slotLogoKept: 'شعار هذه القناة محفوظ',
  statusTitle: 'الحالة والنتيجة',
  status: 'الحالة',
  autoStatus: 'تلقائي · من المصدر',
  manualHint: 'اختيار حالة يدوياً يتقدم على المصدر حتى تعيده إلى «تلقائي».',
  home: 'صاحب الأرض',
  away: 'الضيف',
  scoreLabel: 'النتيجة',
  scoreRequired: 'أدخل نتيجة المباراة كاملة قبل الحفظ',
  penalties: 'ركلات الترجيح',
  scoreNotAllowed: 'لا نتيجة لهذه الحالة',
  period: 'الشوط',
  periodFirstHalf: 'الشوط الأول',
  periodSecondHalf: 'الشوط الثاني',
  periodExtraFirst: 'إضافي أول',
  periodExtraSecond: 'إضافي ثانٍ',
  minute: 'الدقيقة',
  lockedHint: 'لن تغيّر المصادر هذه الحقول. يُقفل الحقل تلقائياً عند تعديله يدوياً.',
  unsaved: 'لديك تغييرات غير محفوظة',
  unsavedBody: 'إذا غادرت الآن ستفقد تعديلات القنوات والمرحلة.',
  leave: 'غادر دون حفظ',
  stay: 'ابقَ',
  saveAndLeave: 'احفظ وغادر',
  noEvents: 'لم تبدأ المباراة بعد.',
} as const;

/** Shared by the D3 screens: one form footer, one close, one retry. */
export const common = {
  save: 'حفظ',
  saving: 'جارٍ الحفظ',
  cancel: 'إلغاء',
  close: 'إغلاق',
  retry: 'إعادة المحاولة',
  loading: 'جارٍ التحميل',
  edit: 'تعديل',
  saved: 'تم الحفظ',
  unsaved: 'لديك تغييرات غير محفوظة',
  leave: 'غادر دون حفظ',
  stay: 'ابقَ',
} as const;

/** SortableList (A6, A7): the drag handle and the Arabic announcements for the keyboard path. */
export const sortable = {
  label: 'الترتيب',
  handle: (name: string): string => `اسحب ${name} لإعادة الترتيب`,
  lifted: (name: string): string => `التقطت ${name}. استخدم السهمين لأعلى وأسفل للتحريك، ومسافة للإفلات.`,
  moved: (name: string, position: number): string => `نُقل ${name} إلى الترتيب ${position}.`,
  dropped: (name: string, position: number): string => `أُفلت ${name} في الترتيب ${position}.`,
  cancelled: (name: string): string => `أُلغي نقل ${name}.`,
  saving: 'جارٍ حفظ الترتيب…',
  role: 'قابل للترتيب',
} as const;

/** AudioPlayer (A10): the clip's five states. */
export const audio = {
  play: 'تشغيل المقطع',
  pause: 'إيقاف المقطع مؤقتاً',
  loading: 'جارٍ تحميل المقطع',
  error: 'تعذّر تشغيل المقطع',
  name: (person: string): string => `مقطع ${person}`,
} as const;

/** KpiCard (A2): the link that opens the work behind the figure. */
export const kpi = {
  open: (label: string): string => `افتح ${label}`,
  progress: (value: number, max: number): string => `${value} من ${max}`,
} as const;

/** A5 (admin board "Teams"). No merge tool today. */
export const teams = {
  title: 'الفرق',
  subtitle: (count: number, missingLogo: number): string => `${count} فريقاً · ${missingLogo} بلا شعار`,
  add: 'فريق جديد',
  search: 'ابحث في الفرق',
  searchHint: 'يتجاهل البحث الهمزات والتاء المربوطة',
  competitionFilter: 'البطولة',
  missingLogoOnly: 'بلا شعار',
  all: 'الكل',
  columns: {
    team: 'الفريق',
    primary: 'البطولة الرئيسية',
    competitions: 'البطولات',
    country: 'الدولة',
    stadium: 'الملعب',
    externalIds: 'المعرفات',
    edit: 'تعديل',
  },
  editor: {
    newTitle: 'فريق جديد',
    title: 'تعديل الفريق',
    name: 'اسم الفريق',
    primary: 'البطولة الرئيسية',
    competitions: 'بطولات أخرى',
    stadium: 'الملعب',
    country: 'الدولة',
    logo: 'الشعار',
    logoUpload: 'رفع شعار',
    externalIds: 'المعرفات الخارجية',
    externalHint: 'تأتي من المصادر ولا تُعدّل من هنا.',
    noCompetition: 'بلا بطولة',
    unsavedBody: 'إذا غادرت الآن ستفقد تعديلات الفريق.',
    empty: 'لا فرق بهذا البحث',
    emptyBody: 'جرّب اسماً آخر أو أزل الفلاتر.',
  },
} as const;

/** A6 (admin board "Competitions"). */
export const competitions = {
  title: 'البطولات',
  subtitle: (count: number): string => `${count} بطولة · الترتيب يحدد ظهورها في التطبيق`,
  add: 'بطولة جديدة',
  hint: 'اسحب لإعادة الترتيب',
  columns: {
    name: 'البطولة',
    priority: 'الترتيب',
    matches: 'المباريات',
    edit: 'تعديل',
  },
  editor: {
    newTitle: 'بطولة جديدة',
    title: 'تعديل البطولة',
    name: 'اسم البطولة',
    logo: 'الشعار',
    logoUpload: 'رفع شعار',
    unsavedBody: 'إذا غادرت الآن ستفقد تعديلات البطولة.',
    empty: 'لا بطولات بعد',
    emptyBody: 'أضف أول بطولة لتظهر في التطبيق.',
  },
} as const;

/** A6 and A7: the order conflict, and the help text under the list. */
export const ordering = {
  conflictLabel: 'الترتيب',
  serverNewer: 'الخادم يحمل ترتيباً أحدث',
  saveFailed: 'تعذّر حفظ الترتيب',
  saved: 'حُفظ الترتيب',
} as const;

/** A7 (admin board "Satellites"). */
export const satellites = {
  title: 'الأقمار',
  subtitle: (count: number): string => `${count} قمراً · الترتيب يحدد ظهورها في قوائم القنوات`,
  add: 'قمر جديد',
  hint: 'اسحب لإعادة الترتيب',
  rank: (position: number): string => `الترتيب ${position}`,
  channelCount: (count: number): string => `${count} قناة`,
  noFrequencies: 'بلا أقوى/أضعف تردد',
  editNamed: (name: string): string => `تعديل ${name}`,
  editor: {
    newTitle: 'قمر جديد',
    title: 'تعديل القمر',
    nameAr: 'الاسم بالعربية',
    nameEn: 'الاسم بالإنجليزية',
    position: 'الموقع المداري',
    degree: 'الدرجة',
    east: 'E',
    west: 'W',
    positionHint: (stored: string): string => `يُخزّن موجباً للشرق: ${stored}`,
    bestFrequency: 'أقوى تردد',
    worstFrequency: 'أضعف تردد',
    mhz: 'MHz',
    sr: 'SR',
    reception: 'فيديو طريقة الاستقبال',
    receptionHint: 'يجب أن يبدأ الرابط بـ https://',
    receptionInvalid: 'أدخل رابطاً يبدأ بـ https://',
    logo: 'الشعار',
    logoUpload: 'رفع شعار',
    empty: 'لا أقمار بعد',
    emptyBody: 'أضف أول قمر لتظهر قنواته في التطبيق.',
    unsavedBody: 'إذا غادرت الآن ستفقد تعديلات القمر.',
  },
} as const;

/** A8 (admin board "Channels", light) and its editor drawer. */
export const channels = {
  title: 'القنوات',
  subtitle: (total: number, onSatellites: number, platformOnly: number): string =>
    `${total} قناة · ${onSatellites} على أقمار · ${platformOnly} منصة بلا قمر`,
  add: 'قناة جديدة',
  search: 'اسم أو رقم تردد',
  satelliteFilter: 'القمر',
  categoryFilter: 'الفئة',
  accessFilter: 'الوصول',
  missingLogoOnly: 'بلا شعار',
  platformOnly: 'منصات فقط',
  shownInMatch: 'يظهر في المباريات',
  placeholderOnly: 'يحتاج استكمال',
  needsCompletion: 'يحتاج استكمال',
  editNamed: (name: string): string => `تعديل ${name}`,
  addOnAnotherNamed: (name: string): string => `إضافة ${name} على قمر آخر`,
  all: 'الكل',
  sports: 'رياضة',
  entertainment: 'ترفيه',
  free: 'مجانية',
  encrypted: 'مشفرة',
  platform: 'منصة',
  noSatellite: 'منصات بلا قمر',
  noFrequency: 'بلا تردد',
  yes: 'نعم',
  no: 'لا',
  columns: {
    channel: 'القناة',
    frequency: 'التردد',
    access: 'الوصول',
    category: 'الفئة',
    inMatch: 'في المباريات',
    edit: 'تعديل',
  },
  editor: {
    newTitle: 'قناة جديدة',
    title: 'تعديل القناة',
    matchName: 'اسم المطابقة',
    displayName: 'اسم العرض',
    frequency: 'التردد',
    frequencyHint: 'تغيير التردد يرسل تنبيهاً لمتابعي القناة.',
    access: 'الوصول',
    provider: 'المزود',
    package: 'الباقة (اختياري)',
    category: 'الفئة',
    country: 'الدولة',
    satellite: 'القمر',
    showInMatch: 'إظهار في صفحات المباريات',
    logo: 'الشعار',
    logoUpload: 'رفع شعار',
    addOnSatellite: 'إضافة على قمر آخر',
    unsaved: 'لديك تغييرات غير محفوظة',
    unsavedBody: 'إذا غادرت الآن ستفقد تعديلات القناة.',
    loading: 'جارٍ تحميل القناة',
    empty: 'لا قنوات بهذا البحث',
    emptyBody: 'جرّب بحثاً آخر أو أزل الفلاتر.',
  },
} as const;

/** A10 (admin board "Commentators"). */
export const commentators = {
  title: 'المعلقون',
  subtitle: (count: number, withoutProfile: number): string => `${count} معلقاً · ${withoutProfile} اسماً على المباريات بلا ملف`,
  add: 'معلق جديد',
  search: 'ابحث عن معلق',
  withoutPhoto: 'بلا صورة',
  withoutAudio: 'بلا صوت',
  usage: (matches: number): string => `${matches} مباراة`,
  options: (name: string): string => `خيارات ${name}`,
  columns: {
    name: 'المعلق',
    usage: 'المباريات',
    audio: 'المقطع',
    edit: 'تعديل',
  },
  delete: {
    title: (name: string): string => `حذف «${name}»؟`,
    body: (matches: number): string => `يُستخدم في ${matches} مباراة. سيُزال من كل القنوات المرتبطة.`,
    inUse: (matches: number): string => `لم يُحذف: يُستخدم في ${matches} مباراة. أزله منها أولاً.`,
    confirm: 'حذف',
  },
  editor: {
    newTitle: 'معلق جديد',
    title: 'تعديل المعلق',
    name: 'اسم المعلق',
    photo: 'الصورة',
    photoUpload: 'رفع صورة',
    audio: 'المقطع الصوتي',
    audioUpload: 'رفع مقطع',
    unsavedBody: 'إذا غادرت الآن ستفقد تعديلات المعلق.',
    empty: 'لا معلقين بهذا البحث',
    emptyBody: 'جرّب اسماً آخر أو أزل الفلاتر.',
  },
} as const;

/** A13 (admin board "Sources" and "Run detail"). */
export const sources = {
  title: 'المصادر',
  subtitle: (count: number): string => `${count} مصدراً · التشغيل والمراقبة`,
  runNow: 'تشغيل الآن',
  running: 'جارٍ التشغيل',
  pause: 'إيقاف',
  resume: 'استئناف',
  paused: 'موقوف',
  breakerOpen: 'الدائرة مفتوحة',
  healthy: 'سليم',
  lastSuccess: (cairo: string): string => `آخر نجاح ${cairo}`,
  neverSucceeded: 'لم ينجح بعد',
  errorRate: (rate: number): string => `نسبة الأخطاء ${rate}%`,
  noErrorRate: 'لا تشغيلات في 24 ساعة',
  itemsSparkline: 'عدد العناصر في آخر 24 ساعة',
  openRuns: 'السجل',
  runsTitle: (name: string): string => `تشغيلات ${name}`,
  runStatus: {
    running: 'قيد التشغيل',
    succeeded: 'نجح',
    partial: 'جزئي',
    failed: 'فشل',
    stopped: 'متوقف',
  },
  columns: {
    started: 'البداية',
    status: 'الحالة',
    found: 'وُجد',
    upserted: 'حُفظ',
    httpErrors: 'أخطاء HTTP',
    detail: 'التفاصيل',
  },
  noRuns: 'لا تشغيلات بعد',
  loadMore: 'المزيد',
  previous: 'السابق',
  runQueued: 'أُرسل المصدر للتشغيل',
  pauseDone: 'أُوقف المصدر',
  resumeDone: 'استُؤنف المصدر',
  detail: {
    title: 'تفاصيل التشغيلة',
    back: 'رجوع إلى المصادر',
    loading: 'جارٍ تحميل التشغيلة',
    notFound: 'سجل هذه التشغيلة غير موجود. ربما حُذف بعد خمسة أيام',
    itemsFound: 'العناصر الموجودة',
    itemsUpserted: 'العناصر المحفوظة',
    httpErrors: 'أخطاء HTTP',
    started: 'بدأت',
    finishedAt: 'انتهت',
    log: 'السجل',
    logUnavailable: 'لا سجل محفوظ لهذه التشغيلة',
    unmatched: 'مباريات لم تُطابق',
    placeholders: 'قنوات مؤقتة أُنشئت',
    skipped: 'قنوات متخطاة',
    errors: 'أخطاء',
    empty: '—',
  },
  /** A13's Live poller card: the readers' states and what the feed is driving. */
  live: {
    name: 'Live poller',
    matchesLive: (count: number): string => `${count} مباشرة`,
    errorShare: (share: number): string => `${share}%`,
    readers: 'المصادر',
    readerState: {
      ok: 'سليم',
      failing: 'متعثر',
      down: 'متوقف',
      invalid: 'مخرجات غير صالحة',
    } as Record<string, string>,
    noRun: 'لا تشغيل يدوي · يعمل من المجدول',
    matchesLabel: 'مباريات مباشرة',
    shareLabel: 'أخطاء',
    readersLabel: 'المصادر',
  },
  /** A13's run detail: the pipeline stages and the saved page (research R13). */
  stages: {
    fetch: 'fetch',
    parse: 'parse',
    normalize: 'normalize',
    resolve: 'resolve',
    upsert: 'upsert',
    notStarted: 'لم يبدأ',
    done: 'تم',
    failed: 'فشل',
    pages: (count: number): string => `${count} صفحات مطلوبة`,
    items: (count: number): string => `${count} عنصر`,
    saved: (count: number): string => `${count} محفوظ`,
    unresolved: (count: number): string => `${count} غير محلول`,
  },
  raw: {
    open: 'الصفحة الخام',
    close: 'إخفاء الصفحة',
    pending: 'جارٍ تحضير الصفحة…',
    gone: 'لم تُحفظ هذه الصفحة أو حُذفت',
    timeout: 'تعذّر تحميل الصفحة الخام. حاول مرة أخرى',
    page: (page: number, pages: number): string => `صفحة ${page + 1} من ${pages}`,
    truncated: 'مختصرة',
    url: 'العنوان',
    inert: 'نص خامل: لا يُنفَّذ أي شيء بداخله',
  },
  /** A13's stopped runs: the scheduler chose not to start, so it is not a fault (contract A13). */
  stopped: {
    not_configured: 'غير مُعدّ',
    budget_reached: 'بلغ الحد اليومي',
    status: 'متوقف',
  },
} as const;

/** The forced password change (contract admin-screens "Change password"): no board, so A1's form. */
export const changePassword = {
  title: 'تغيير كلمة المرور',
  lead: 'يجب تغيير كلمة المرور قبل متابعة العمل.',
  current: 'كلمة المرور الحالية',
  next: 'كلمة المرور الجديدة',
  confirm: 'تأكيد كلمة المرور الجديدة',
  hint: '12 حرفاً على الأقل',
  submit: 'حفظ كلمة المرور',
  submitting: 'جارٍ الحفظ',
  mismatch: 'كلمتا المرور غير متطابقتين',
  tooShort: 'كلمة المرور الجديدة أقل من 12 حرفاً',
} as const;

/** A15 (admin board "Notifications"): the outbox, its reasons, and the composer beside it. */
export const notifications = {
  title: 'الإشعارات',
  subtitle: 'صندوق الإرسال وإنشاء إعلان · الإرسال للمديرين فقط',
  logTitle: 'صندوق الإرسال',
  columns: {
    type: 'النوع',
    target: 'الهدف',
    recipients: 'المستقبلون',
    sent: 'نجح',
    failed: 'فشل',
    time: 'الوقت',
    status: 'الحالة',
  },
  allDevices: 'جميع الأجهزة',
  correction: 'تصحيح',
  test: 'تجريبي',
  filters: {
    type: 'النوع',
    status: 'الحالة',
    all: 'الكل',
  },
  status: {
    pending: 'مجدول',
    sending: 'جارٍ الإرسال',
    sent: 'أُرسل',
    failed: 'فشل',
    cancelled: 'ملغى',
  },
  /** The outbox `error` in Arabic; anything else is the push service's text and shows raw. */
  reason: {
    late: 'متأخر عن الموعد',
    match_finished: 'انتهت المباراة',
    score_fell: 'انخفضت النتيجة',
    no_net_change: 'لم يتغيّر شيء',
    type_off: 'نوع الإشعار متوقف',
    admin: 'أُلغي من الإدارة',
  } as Record<string, string>,
  loadMore: 'المزيد',
  previous: 'السابق',
  empty: {
    title: 'لا إشعارات بعد',
    body: 'سيظهر هنا كل ما يُرسل، مع عدّاده وسببه.',
  },
  cancel: 'إلغاء الإعلان',
  cancelTitle: 'إلغاء الإعلان؟',
  cancelBody: 'لن يصل إلى أي جهاز. لا يمكن التراجع.',
  cancelConfirm: 'إلغاء الإعلان',
  cancelDone: 'أُلغي الإعلان',
  composer: {
    title: 'إعلان جديد',
    titleField: 'العنوان',
    bodyField: 'النص',
    target: 'يفتح',
    targetNone: 'بلا رابط',
    pickMatch: 'اختر مباراة',
    pickChannel: 'اختر قناة',
    clearTarget: 'إزالة الرابط',
    when: 'الموعد',
    now: 'الآن',
    scheduled: 'مجدول',
    whenLabel: 'الموعد بتوقيت القاهرة',
    whenPast: 'اختر موعداً بعد الآن',
    whenRequired: 'اختر الموعد',
    audience: 'الجمهور',
    kinds: {
      all: 'كل الأجهزة',
      team: 'فريق',
      competition: 'بطولة',
      match: 'مباراة',
      channel: 'قناة',
    },
    team: 'الفريق',
    competition: 'البطولة',
    chooseMatch: 'المباراة',
    chooseChannel: 'القناة',
    reach: (devices: string): string => `≈ ${devices} جهاز`,
    reachAge: (seconds: number): string => `حُسب قبل ${seconds} ث`,
    reachUnavailable: 'تعذّر حساب عدد الأجهزة',
    send: 'إرسال الآن',
    schedule: 'جدولة الإرسال',
    sending: 'جارٍ الإرسال',
    confirmTitle: 'إرسال إلى كل الأجهزة؟',
    confirmBody: (devices: string): string => `سيصل إلى ${devices} جهازاً. لا يمكن التراجع بعد الإرسال.`,
    confirm: 'إرسال',
    sent: 'أُرسل الإعلان',
    scheduledDone: 'جُدول الإعلان',
    preview: {
      android: 'Android',
      iphone: 'iPhone (PWA مثبّت)',
      appName: 'مدار',
    },
    testSend: 'إرسال تجريبي لجهازي',
    testSent: (device: string): string => `أُرسل التجريبي إلى ${device}`,
    noDevice: 'لا جهاز محفوظ بعد',
    deviceId: 'معرّف الجهاز',
    saveDevice: 'حفظ الجهاز',
    deviceSaved: 'حُفظ الجهاز',
    deviceNoToken: 'الجهاز المحفوظ بلا رمز إشعار',
    platforms: { android: 'Android', ios: 'iOS', web: 'ويب' } as Record<string, string>,
    emptyBody: 'اكتب عنواناً ونصاً قبل الإرسال',
  },
} as const;

/** A16 (admin board "Users"): the accounts, their status, and the temporary password shown once. */
export const users = {
  title: 'المستخدمون',
  subtitle: (count: number): string => `${count} حسابات · كل حساب له سجل تغييرات مستقل`,
  add: 'مستخدم جديد',
  newTitle: 'مستخدم جديد',
  editTitle: 'تعديل مستخدم',
  columns: {
    user: 'المستخدم',
    role: 'الدور',
    status: 'الحالة',
    lastLogin: 'آخر دخول',
    totp: 'التحقق بخطوتين',
  },
  totpPlanned: 'V2',
  status: {
    active: 'نشط',
    locked: (minutes: number): string => `مقفل مؤقتاً · ${minutes} د`,
    disabled: 'معطّل',
  },
  options: 'خيارات',
  menu: {
    edit: 'تعديل',
    reset: 'إعادة تعيين كلمة المرور',
    deactivate: 'تعطيل',
    reactivate: 'إعادة تنشيط',
  },
  fields: {
    name: 'الاسم',
    email: 'البريد الإلكتروني',
    role: 'الدور',
  },
  roleHints: {
    editor: 'المباريات والقنوات والفرق والمحتوى',
    admin: 'كل ما سبق + المستخدمون والمصادر وإرسال الإعلانات والحذف الجماعي',
  },
  tempPassword: 'كلمة مرور مؤقتة',
  tempPasswordHint: '12 حرفاً على الأقل · تُغيَّر عند أول دخول',
  copy: 'نسخ',
  copied: 'نُسخت كلمة المرور',
  create: 'إنشاء الحساب',
  save: 'حفظ',
  resetTitle: 'إعادة تعيين كلمة المرور؟',
  resetBody: 'ستُلغى كلمة المرور الحالية وتُسلَّم كلمة مرور مؤقتة جديدة مرة واحدة.',
  resetConfirm: 'إعادة تعيين',
  deactivateTitle: 'تعطيل الحساب؟',
  deactivateBody: 'يُرفض كل طلب منها فوراً، وتُلغى جلساتها. يمكنك تنشيطها مرة أخرى.',
  deactivateConfirm: 'تعطيل',
  reactivateTitle: 'إعادة تنشيط الحساب؟',
  reactivateBody: 'تدخل من جديد بعد أن تسجّل الدخول بكلمة مرورها.',
  reactivateConfirm: 'إعادة تنشيط',
  /** The two refusals the drawer says before the server has to (contract A16). */
  cannotChangeSelf: 'لا يمكنك تغيير دورك أو تعطيل حسابك',
  lastAdmin: 'لا يمكن تعطيل آخر مدير نشط. أضف مديراً آخر أولاً',
  disabledForSelf: 'لا يمكنك تغيير دورك أو تعطيل حسابك',
  neverLoggedIn: 'لم يدخل بعد',
  empty: {
    title: 'لا حسابات بعد',
    body: 'أضف أول محرر ليعمل معك على المحتوى.',
  },
} as const;

/** A17 (admin board "Audit"): the log, the diff, and the push an entry produced. */
export const audit = {
  title: 'سجل التغييرات',
  subtitle: 'كل تعديل يُسجَّل باسم صاحبه مع الفرق قبل وبعد',
  filters: {
    user: 'المستخدم',
    entity: 'النوع',
    period: 'الفترة',
    all: 'الكل',
    last7: 'آخر 7 أيام',
    today: 'اليوم',
    last30: 'آخر 30 يوماً',
  },
  entities: {
    match: 'مباراة',
    channel: 'قناة',
    team: 'فريق',
    competition: 'بطولة',
    satellite: 'قمر',
    commentator: 'معلق',
    rights_holder: 'حقوق بث',
    admin_user: 'مستخدم',
  } as Record<string, string>,
  actor: {
    importer: 'مستورد',
    system: 'النظام',
  },
  detailTitle: 'تفاصيل التغيير',
  empty: {
    title: 'لا تغييرات في هذه الفترة',
    body: 'جرّب فترة أطول أو أزل الفلاتر.',
  },
  emptyDetail: 'اختر تغييراً من القائمة لعرض الفرق قبل وبعد.',
  openChannel: 'فتح القناة',
  openMatch: 'فتح المباراة',
  outbox: 'صندوق الإرسال',
  notificationLine: (sent: string, recipients: string): string =>
    `أُرسل تنبيه من صندوق الإرسال إلى ${sent} جهازاً من ${recipients} متابعاً`,
  loadMore: 'المزيد',
  previous: 'السابق',
  readOnly: 'السجل للقراءة فقط. لا استرجاع من هنا.',
} as const;

/** A8's frequency history, under the frequency field (contract A8). */
export const frequencyHistory = {
  title: 'سجل التردد',
  empty: 'لم يتغيّر تردد هذه القناة بعد',
} as const;

/** A2 (admin board "Main"): today's work, the sources' health and the last changes. */
export const dashboard = {
  title: 'لوحة المتابعة',
  subtitle: 'بتوقيت القاهرة · أهم ما يحتاج انتباهك اليوم',
  missing: 'مباريات بلا قنوات',
  missingContext: (matches: number): string => `من ${matches} مباراة اليوم`,
  placeholders: 'قنوات تحتاج استكمال',
  placeholdersContext: 'من المصادر، مخفية حتى تكتمل',
  sourcesHealth: 'صحة المصادر',
  sourcesContext: (healthy: number, total: number): string => `${healthy} من ${total} سليمة`,
  missingTitle: 'مباريات بلا قنوات',
  missingEmpty: 'كل مباريات اليوم لها قنوات',
  missingOpen: 'افتح المباريات',
  sourceTitle: 'صحة المصادر',
  sourceOpen: 'افتح المصادر',
  recentTitle: 'آخر التغييرات',
  recentEmpty: 'لا تغييرات بعد',
  recentLine: (who: string, action: string, entity: string): string => `${who} ${action} ${entity}`,
  bySource: (name: string): string => `مصدر ${name}`,
  actions: {
    create: 'أضاف',
    update: 'عدّل',
    delete: 'حذف',
    bulk: 'حدّث',
  } as Record<string, string>,
  entities: {
    match: 'مباراة',
    team: 'فريق',
    competition: 'بطولة',
    channel: 'قناة',
    satellite: 'قمر',
    commentator: 'معلق',
    source: 'مصدر',
  } as Record<string, string>,
  loading: 'جارٍ تحميل لوحة المتابعة',
} as const;

/** D5's A13 queue: the names the importers couldn't match, and the three ways an editor clears one. */
export const unresolved = {
  title: 'أسماء غير محلولة',
  hint: 'تبقى المباراة بالاسم النصي حتى تُربط',
  count: (total: number): string => `${total}`,
  sourceFilter: 'المصدر',
  allSources: 'الكل',
  columns: {
    name: 'الاسم من المصدر',
    kind: 'النوع',
    source: 'المصدر',
    context: 'سياق المباراة',
    suggestion: 'اقتراح',
    actions: 'الإجراء',
  },
  kinds: {
    team: 'فريق',
    competition: 'بطولة',
    channel: 'قناة',
  } as Record<string, string>,
  link: 'ربط',
  create: 'جديد',
  ignore: 'تجاهل',
  pick: 'اختر الفريق',
  candidates: (count: number): string => `${count} مرشحين بنفس الاسم`,
  confidence: (value: number): string => `${value}%`,
  seen: (count: number): string => `تكرر ${count} مرة`,
  noContext: 'بلا سياق',
  loading: 'جارٍ تحميل الأسماء غير المحلولة',
  empty: 'لا أسماء غير محلولة الآن',
  error: 'تعذّر تحميل الأسماء غير المحلولة',
  loadMore: 'المزيد',
  mapTitle: (name: string): string => `ربط «${name}»`,
  mapHint: 'اختر الهدف ثم احفظ. لا يُكتب شيء قبل الحفظ.',
  target: 'الهدف',
  noSuggestions: 'لا اقتراحات. أنشئ عنصراً جديداً أو تجاهل الاسم.',
  scopeToCompetition: 'حصر الربط على البطولة',
  scopeHint: 'أكثر من فريق يحمل هذا الاسم، فيُربط باسم البطولة الظاهرة في السياق.',
  mapped: 'تم الربط',
  ignored: 'تم التجاهل',
  created: 'أُنشئ العنصر ورُبط الاسم',
  createLeftOpen: 'أُنشئ العنصر لكن لم يُربط الاسم. الصف ما زال مفتوحاً',
  mapFailed: 'تعذّر ربط الاسم',
  ignoreFailed: 'تعذّر تجاهل الاسم',
  createTitle: (name: string): string => `إنشاء عنصر من «${name}»`,
  createKind: 'نوع العنصر الجديد',
} as const;

/** D5's A9: broadcast rights, their competitions and their carriages. */
export const rights = {
  title: 'حقوق البث',
  subtitle: (total: number): string => `${total} جهة · الترتيب يحدد العرض في التطبيق`,
  add: 'جهة جديدة',
  list: 'الجهات',
  search: 'بحث في الجهات',
  loading: 'جارٍ تحميل الجهات',
  empty: 'لا جهات بعد',
  noResults: 'لا جهات تطابق البحث',
  error: 'تعذّر تحميل الجهات',
  competitions: 'البطولات',
  addCompetition: 'أضف بطولة',
  carriages: 'الأقمار والترددات',
  addSatellite: 'قمر آخر',
  addFrequency: 'تردد',
  primary: 'أساسي',
  primaryLabel: 'تردد أساسي',
  access: {
    free: 'مفتوحة',
    encrypted: 'مشفرة',
  } as Record<string, string>,
  beam: {
    wide: 'حزمة واسعة',
    narrow: 'حزمة ضيقة',
  } as Record<string, string>,
  beamLabel: 'الحزمة',
  accessLabel: 'الوصول',
  packageLabel: 'الباقة',
  satellites: 'الأقمار',
  edit: 'تعديل',
  frequency: 'التردد',
  removeCarriage: 'حذف القمر',
  removeFrequency: 'حذف التردد',
  onePrimary: 'لكل قمر تردد أساسي واحد: اختر واحداً فقط',
  primaryRequired: 'اختر تردداً أساسياً في كل قمر',
  nameRequired: 'اسم الجهة مطلوب',
  editTitle: (name: string): string => `تعديل «${name}»`,
  createTitle: 'جهة جديدة',
  deleteTitle: 'حذف الجهة',
  deleteBody: (name: string, satellites: number): string =>
    `ستُحذف «${name}» و${satellites} من مجموعات التردد. لا يمكن التراجع.`,
  deleteConfirm: 'حذف',
  deleted: 'حُذفت الجهة',
  deleteFailed: 'تعذّر حذف الجهة',
  saveFailed: 'تعذّر حفظ الجهة',
  onlyAdmin: 'حذف الجهات للمدير فقط',
  moreCompetitions: (count: number): string => `+${count}`,
  competitionCount: (count: number): string => `${count} بطولة`,
  satelliteCount: (count: number): string => `${count} قمر`,
  noCarriages: 'لا أقمار بعد',
  logo: 'الشعار',
  logoUpload: 'رفع شعار',
  logoRemove: 'إزالة الشعار',
  name: 'اسم الجهة',
  unsavedBody: 'إذا غادرت الآن ستفقد تعديلات الجهة.',
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
  | 'hidden_name_not_found'
  | 'run_in_progress'
  | 'source_not_runnable'
  | 'source_not_found'
  | 'import_run_not_found'
  | 'alias_conflict'
  | 'password_change_required'
  | 'notification_not_cancellable'
  | 'send_at_in_past'
  | 'text_not_allowed'
  | 'test_device_not_set'
  | 'test_device_no_token'
  | 'device_not_found'
  | 'email_taken'
  | 'cannot_change_self'
  | 'last_admin'
  | 'password_too_short'
  | 'password_unchanged';

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
  run_in_progress: 'هذا المصدر يعمل الآن. انتظر انتهاء التشغيل الحالي',
  source_not_runnable: 'لا يمكن تشغيل هذا المصدر يدوياً',
  source_not_found: 'هذا المصدر غير موجود',
  import_run_not_found: 'سجل هذه التشغيلة غير موجود. ربما حُذف بعد خمسة أيام',
  alias_conflict: 'هذا الاسم مرتبط بجهة أخرى. حدّث الصفحة ثم حاول مرة أخرى',
  password_change_required: 'يجب تغيير كلمة المرور قبل المتابعة',
  notification_not_cancellable: 'لا يمكن إلغاء هذا الإشعار',
  send_at_in_past: 'الموعد في الماضي. اختر وقتاً قادماً',
  text_not_allowed: 'العنوان أو النص يحتوي كلاماً غير مسموح',
  test_device_not_set: 'لا جهاز تجريبي محفوظ. احفظ جهازك أولاً',
  test_device_no_token: 'الجهاز المحفوظ بلا رمز إشعار. أعد تسجيل الجهاز',
  device_not_found: 'هذا الجهاز غير موجود',
  email_taken: 'هذا البريد مستخدم لحساب آخر',
  cannot_change_self: 'لا يمكنك تغيير دورك أو تعطيل حسابك',
  last_admin: 'لا يمكن تعطيل آخر مدير نشط. أضف مديراً آخر أولاً',
  password_too_short: 'كلمة المرور الجديدة أقل من 12 حرفاً',
  password_unchanged: 'كلمة المرور الجديدة مثل الحالية. اختر كلمة أخرى',
};

const unknownErrorCopy = 'حدث خطأ غير متوقع. حاول مرة أخرى';

const isErrorCode = (code: string): code is ErrorCode => Object.hasOwn(errorCopy, code);

/** Arabic copy for an API `error.code`; unknown codes get a generic line, never the server text. */
export function copyForErrorCode(code: string): string {
  return isErrorCode(code) ? errorCopy[code] : unknownErrorCopy;
}
