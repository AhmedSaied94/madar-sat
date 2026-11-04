# Madar Sat — Product & Business

| | |
|---|---|
| Status | Draft 1, 2026-10-28 |
| Companion | [system-design.md](system-design.md): architecture, API shapes (§6.3), platform limits (§5.3) |
| Readers | **Claude Design**, which will produce the full UI for the Flutter app (Android, iOS PWA, desktop web) and the admin web. Also the product owner |

The brand is **Madar Sat** (Arabic: **مدار سات**). The product replaces **Sat Air 3.8** (`com.satair.app`); its recovered source is in `old_app/`.

---

## 0. How to use this document (for Claude Design)

**What to deliver**

1. A design system: tokens for light **and** dark, a type scale, and the components in §13.6 with every state.
2. App screens §9 (S0–S16) at 360 × 800 dp, checked at 412 × 915 and at font scale 1.3. Dark and light.
3. Web-specific screens: the iOS install guide (S1.5), push-permission priming on the PWA, and a desktop two-pane layout at 1440 × 900 (§8.3).
4. Admin web screens §10 (A0–A17) at 1440 × 900.
5. Brand assets for Madar Sat: app icon, wordmark (Latin and Arabic), splash, monochrome notification icon.

**Fixed:** content, data fields, states, platform limits, Arabic RTL, both themes, phases.
**Yours to decide:** visual direction (a recommendation is in §13.1), layout, motion, and navigation details. The proposed navigation (§8.2) can change as long as the priorities in §8.1 hold.

**Phase tags:**

| Tag | Meaning | Design depth |
|---|---|---|
| [P] | Parity: exists in Sat Air 3.8 | Full, all states |
| [V1] | New, in the launch release | Full, all states |
| [V2] | After launch | Screen level |
| [V3] | Later | Concept only |

**Use real content.** Sample values and lengths are in §12, and the API shapes are in system-design §6.3.3. No lorem ipsum. Arabic text throughout.

---

## 1. Product summary

Madar Sat is an Arabic-first guide for football fans who watch on a satellite dish. For every match it answers, in two taps or fewer: **where can I watch it, on which satellite and frequency, and can my dish receive it?** Around that answer it adds:
- live scores;
- the commentator for each channel, with a voice clip;
- broadcast rights by competition;
- a complete frequency list for 32 satellites;
- alerts when a followed team plays, scores, or when a followed channel changes frequency.

**Positioning:** for Arab viewers who watch on a dish, Madar Sat is the match guide that knows your dish. It's the only one that joins the fixture list to the exact channels, frequencies and commentators you can receive.

---

## 2. Starting point: Sat Air 3.8

**What it does today** (Android only):
- Four bottom tabs: المباريات (matches), جدول ‹favorite satellite› (matches carried on one chosen satellite, default Amos), الترددات (frequencies), المزيد (more).
- More holds the feeds, broadcast rights, settings and privacy policy, plus two dead "قريباً" (coming soon) items: other sports, and satellite coverage maps.
- Onboarding: theme → favorite teams → favorite satellite.
- Local notifications 15 min before a favorite team's match.
- AdMob banner, plus an interstitial when opening a match or switching tabs.

**UX problems the redesign must fix**

| Problem | Result for users |
|---|---|
| A frequency only appears after expanding each channel card, and the list ignores the user's dish | One match can list **171** channels. Finding *receivable* ones is slow |
| The match list shows no channel at all | Every "where is it on?" question costs an extra tap |
| Live status is guessed from the clock; there are no scores | "مباشر" shows for two hours whatever happens |
| The interstitial fires when a match opens | The ad blocks the answer the user came for |
| Emoji as placeholders and icons (⚽ 🏆 📡 🇪🇬), uneven cards, two "coming soon" dead ends | Looks unfinished |
| Only one favorite satellite; no team, competition or channel pages; search filters only the current day | Can't explore or personalize |
| Dates shown as `الثلاثاء 28-10-2026`; grouping by Cairo day | Hard to read; wrong day for Gulf and European users |
| 35 % of matches have no channel listed | Empty detail screens without explanation |

---

## 3. Users

| Persona | Context | Needs most |
|---|---|---|
| **The Nilesat household** (Egypt, North Africa) | A fixed dish on Nilesat 7°W and maybe Badr 26°E. Follows Al Ahly or Zamalek, the national team, sometimes Spanish and English leagues | Free channels first, today's big matches, which commentator, Egyptian broadcaster |
| **The Gulf league follower** (KSA, UAE, Qatar) | Watches the Saudi league and the Champions League. Mixes satellite with streaming platforms | Correct local times, channel or platform per country, rights holders |
| **The dish tinkerer / installer** | Several satellites or a motorized dish. Helps neighbours | Full frequency lists, frequency changes, best and worst transponders to align, how-to videos, feeds |
| **The diaspora fan** (Europe) | Hotbird 13°E or Astra 19.2°E. Time zone differs from Cairo | Local times, European carriages, "other platforms" by country |

**Jobs to be done**
- *Before the match:* "Tell me where my match is on, on a channel my dish gets, and remind me in time."
- *During the match:* "What's the score now, who scored, and is it still on this channel?"
- *Setting up:* "What frequency do I enter for this channel, did it change, and how do I point my dish?"
- *Planning:* "What's on this week for my teams and competitions?"

---

## 4. Market and differentiation

| Alternative | Examples | What it lacks |
|---|---|---|
| Score apps | Kooora-style, global score apps | Satellite frequencies; the user's dish |
| Arabic schedule sites | YallaKora, FilGoal | Frequencies per satellite; commentators; follows; alerts |
| Frequency databases | KingOfSat, LyngSat, FlySat | Match context; Arabic UX; mobile-first |
| Social pages | Daily "جدول المباريات والقنوات الناقلة" images on Facebook and Telegram | Search, personalization, accuracy, alerts |

**Why Madar Sat wins:**
1. Fixture + channel + satellite + frequency in one place.
2. **My satellites** filters everything to what the user can receive.
3. A commentator per channel, with a voice clip.
4. Frequency-change alerts; nobody else in this niche does this well.
5. Arabic-native design, correct local times.
6. Curated data that improves over time through admin edits and user reports [V2].

---

## 5. Business model

**Revenue**

| Stream | Phase | Rules |
|---|---|---|
| AdMob banner | [P] Android | Pinned above the bottom nav. Not shown in onboarding, settings, the privacy policy, or while a sheet or search is open |
| AdMob interstitial | [P] Android, **changed** | Shown on *return* from match detail and on switching to secondary tabs. Never before the answer. ≥ 90 s apart, at most 4 per session (Remote Config). Never in the first 60 s after launch |
| Ad-free upgrade | [V3] | One-time Play Billing purchase, restored from the store account, so no app account is needed |
| Official-viewing links | [V2] | Where a legal streaming service holds the rights (rights-holder data), link to it, as an affiliate where possible |
| Sponsorship | Later | One sponsor slot (for example, a receiver brand) on satellite pages. Clearly labelled |

The PWA has no ads at launch. AdMob doesn't run there, and web ads in a Flutter canvas are poor. Keeping it ad-free also makes it a better first impression on iOS.

**Costs**

| Item | Cost |
|---|---|
| Infrastructure (OCI Always Free, Firebase Spark, Backblaze free tier) | $0/month |
| Google Play developer account | $25 once |
| Apple Developer Program | $99/year (needed for the iOS app) |
| Domain (recommended) | About $10/year |

**KPIs.** Initial targets, to be revisited after the beta:

| Area | KPI | Target |
|---|---|---|
| Core value | Share of match-detail views that reach a frequency or commentator interaction | Track |
| Data coverage | Matches in prioritized competitions with ≥ 1 channel, 2 h before kickoff | ≥ 95 % (today about 65 % across all matches) |
| Data quality | Median time to resolve a report [V2] | < 24 h |
| Engagement | DAU/MAU | ≥ 25 % |
| Engagement | Follows per active device | ≥ 3 |
| Retention | D1 / D7 / D30 | Baseline in beta |
| Push | Opt-in: Android / PWA | ≥ 60 % / ≥ 30 % of installed |
| Push | Open rate for reminders | ≥ 10 % |
| Quality | Crash-free sessions | ≥ 99.5 % |
| Revenue | ARPDAU (Android), interstitials per session | Track |

**Growth loops**
- **Share a match** [V1]: a link to `/match/<id>` that opens the PWA, or the app via deep link.
- **Share a match card** [V3]: an image with teams, time, channels and frequencies, aimed at the WhatsApp and Telegram groups where today's schedule images circulate.
- **Store search (ASO):** Arabic keywords such as جدول المباريات, القنوات الناقلة, ترددات and نايل سات.
- **"Add to home screen" guide** for iOS visitors.

---

## 6. Scope and roadmap (proposal; confirm O2)

| Feature | Phase | Notes |
|---|---|---|
| Daily match list by competition, date strip, live filter, team search | [P] | Redesigned. Adds a channel line on each row and grouping by local day |
| Match detail: broadcasters, commentators with voice clip, all channels with frequency, other platforms by region, stadium, Egyptian broadcaster | [P] | Restructured around **My satellites** (S3) |
| Satellite schedule tab | [P] | Becomes **أقماري** with several satellites (S4) |
| Frequencies by satellite, sports/entertainment tabs, best/worst frequency, reception video | [P] | Frequency visible without expanding; follow a channel |
| Broadcast rights by satellite or by competition | [P] | |
| Feeds | [P] | Pending O3. The collection is empty today |
| Settings: time zone, 12/24 h, theme, font size, satellite visibility, competition order and hiding | [P] | Adds a "follow the system" theme option and notification preferences |
| Onboarding | [P] | Multi-satellite; notification priming; iOS install guide |
| **Follow** teams, competitions, matches, channels → **My matches** + push | [V1] | Server push on every platform |
| **My satellites** (dish setup) filtering every channel list, free first | [V1] | Uses existing data |
| **Live match center**: score, minute, goals; lineups where available | [V1] | Lineups come from FilGoal where it has them (O7) |
| **Frequency-change alerts** + "changed recently" badges | [V1] | |
| Team, competition and channel pages; global search | [V1] | Needed for following |
| Other sports through a sport switcher on Matches | [V1] | Basketball, handball, volleyball, tennis |
| Share a match link; soft update banner; maintenance screen | [V1] | |
| Satellite finder (azimuth, elevation, LNB skew, compass) | [V2] | |
| Home widget; ongoing live notification (Android) / Live Activity (iOS) | [V2] | Native only |
| Commentator profiles and following | [V2] | |
| "Channel not working / wrong frequency" reports + admin queue | [V2] | |
| iOS App Store app | [V2] | Needs the Apple account |
| Accounts, score predictions, leaderboards | [V3] | |
| Shareable match-card images; add to calendar; ad-free purchase | [V3] | |
| English UI | [V3] | Strings already externalized |
| ~~Web password gate~~, ~~"coming soon" items~~, ~~satellite coverage maps~~, ~~exit yes/no dialog~~ | Dropped | The exit dialog becomes "press back again to exit" |

---

## 7. Platforms and what changes per platform

The full matrix is in system-design §5.3. What it means for the design:

| Topic | Android app | iOS PWA | Desktop web |
|---|---|---|---|
| Ads | Banner slot + interstitials | None. Layout must look complete without a banner | None |
| Push permission | Priming card → OS dialog (Android 13+) | Only **after** "Add to Home Screen". Before that, show the install guide instead | Browser prompt after priming |
| Install | Play Store | In-app install guide (S1.5), reachable from More | Browser install button (optional) |
| Navigation | Bottom nav, system back | Bottom nav, edge swipe; respect safe areas (notch, home indicator) | Navigation rail + list/detail panes |
| Hover/focus | Pressed states | Pressed states | **Hover and visible keyboard focus required** |
| Satellite finder [V2] | Full | Needs a motion-permission tap; no camera overlay | Hidden |

---

## 8. Information architecture

### 8.1 Priorities (fixed)

1. The answer to "where is it on?" is **≤ 2 taps** from launch, and is partly visible on the list row itself.
2. **Personal by default.** My satellites and my teams come first everywhere; everything else is one step away.
3. **Honest data.** Show freshness and "estimated" states, and never present stale data as live.
4. **Arabic-native.** RTL layout with readable left-to-right islands for frequencies and Latin names (§13.4).
5. **Fast and offline-tolerant.** Cached content first, with skeletons only on true first load.
6. **Ads never block the answer.**

### 8.2 Mobile navigation (proposal)

| Tab | Label | Content |
|---|---|---|
| 1 | المباريات (Matches) | S2. Search sits in its header |
| 2 | أقماري (My satellites) | S4: matches carried on my satellites |
| 3 | الترددات (Frequencies) | S5 → S6 |
| 4 | المفضلة (Favorites) | S9: follows + my upcoming matches |
| 5 | المزيد (More) | S16: rights, feeds, settings, install guide, share, about |

The tab order runs right to left. Detail screens push over the tabs and keep the bottom nav hidden; one tab stack per tab.

### 8.3 Desktop and tablet

| Width | Layout |
|---|---|
| < 600 | Phone layout |
| 600–1023 | Bottom nav; detail opens as a full page or a large sheet |
| ≥ 1024 | **Navigation rail on the right** + list pane (≈ 420 px) + detail pane. Selecting a match or channel fills the detail pane without leaving the list |

Content width is capped (about 1200 px for the two panes).

### 8.4 Routes and deep links

`/` · `/live` · `/day/2026-10-28` · `/match/:id` · `/my-satellites` · `/satellites` · `/satellites/:id` · `/channel/:id` · `/team/:id` · `/competition/:id` · `/favorites` · `/rights` · `/rights/:id` · `/feeds` · `/search?q=` · `/settings/*` · `/install`

Native builds use the same paths after `‹scheme›://`. Push notifications open these routes.

---

## 9. App screens

### S0 · System screens [P + V1]

| Screen | Trigger | Content |
|---|---|---|
| Splash | Cold start | Brand mark on the brand background (Android 12 splash API: icon on a solid color) |
| Forced update | Build < `min_supported_build` | Title "تحديث مطلوب", body "يوجد إصدار جديد من التطبيق. يرجى التحديث للاستمرار.", CTA "تحديث الآن" (Play Store; on the PWA, reload) |
| Soft update [V1] | Build < `latest_build` | Dismissible banner: "يتوفر إصدار جديد" + "تحديث" |
| Maintenance [V1] | Remote Config flag | Full screen with the admin's message; cached content stays browsable |
| No connection, nothing cached | First run, offline | "لا يوجد اتصال بالإنترنت" / "تأكد من اتصالك بالإنترنت وحاول مرة أخرى" + "إعادة المحاولة" |
| Load failed | Server error, nothing cached | "تعذّر تحميل البيانات" + retry |
| Offline with cache | Any screen | Slim banner: "أنت غير متصل — آخر تحديث ‹منذ 12 دقيقة›" |
| Exit (Android) | Back on a root tab | Snackbar: "اضغط رجوع مرة أخرى للخروج" |

### S1 · Onboarding [P + V1]

Four steps with progress dots, back and skip. Each step can be reopened later from Settings.

| Step | Content |
|---|---|
| S1.1 Welcome + theme | Logo, "مرحباً بك في مدار سات", one-line value statement. Choice: داكن / فاتح / تلقائي (system), with live preview tiles. Note: "تقدر تغيّره في أي وقت من الإعدادات" |
| S1.2 Teams | "اختر فرقك المفضلة". Search ("ابحث عن فريق..."). Teams grouped under competition headers (logo + name), popular first. Multi-select; selected teams collect in a tray. 1,513 teams, so search does the heavy lifting |
| S1.3 My satellites | "اختر الأقمار التي يستقبلها طبقك". Rows: satellite glyph or logo, Arabic name, English name + position (LTR, `Nilesat 7.0W`), channel count, a "الأكثر استخداماً" badge on the top ones. Multi-select. If skipped, match pages default to Nilesat + Badr, the old app's rule, and show a "حدد أقمارك" prompt |
| S1.4 Notifications | Priming card: what they'll get (reminder before kickoff with the channel, goals, final score, frequency changes) → "تفعيل التنبيهات" opens the OS or browser dialog; "ليس الآن". On iOS Safari when **not installed**, this step shows S1.5 instead |
| S1.5 iOS install guide (PWA) | Three illustrated steps that show the Safari UI: tap Share → "إضافة إلى الشاشة الرئيسية" → open مدار سات from its icon. Explains that alerts need this. Also reachable from More |

### S2 · Matches (المباريات) [P + V1]

**Header:** wordmark at the start side (right) and a search action (→ S14).

**Date strip:** seven day cells (weekday + day number). The selected day is filled and today has a distinct marker. Swiping pages by week, with RTL paging. "اليوم" jumps back to today. A calendar action opens a month picker for past days [V1]. Below the strip the selected date reads as words: `الثلاثاء 28 أكتوبر`.

**Filter chips:** الكل · مبارياتي ‹count› [V1] · مباشر ‹count›. The live chip carries a red dot while any match is live.

**Sport switcher [V1]:** chips with icons for كرة القدم (default), كرة السلة, كرة اليد, الكرة الطائرة, التنس, each showing a count when it has matches. Hidden when only football has matches that day.

**Competition groups:**
- Order: the user's order, then admin priority, then earliest kickoff.
- Header: competition logo, name (≤ 38 characters), stage chip (`الجولة 9`, `ذهاب دور 16`).
- Overflow menu: follow the competition, hide it (with an undo snackbar), open the competition page.

**Match row** (≈ 64–76 dp; two lines of team name allowed):

| Area | Content |
|---|---|
| Start side (right) | Home team logo + name |
| Center | Status block (variants below) |
| End side (left) | Away team logo + name |
| Under the row [V1] | Up to 2 channel names: ones on my satellites first, free first. A "مجانية" marker if any free channel exists, and `+N`. Hidden if there are no channels |
| Markers | Star next to a followed team; bell if a reminder is set |

**Status block variants:**

| Status | Shows |
|---|---|
| Scheduled | Local time: `9:00 م` or `21:00` |
| Imminent (≤ 60 min) | Countdown `بعد 25 د` |
| Live | Score + minute `67′` + subtle pulse, live color |
| Halftime | Score + "استراحة" |
| Extra time | Score + minute + "إضافي" |
| Penalties | Score + penalties "(4-3)" + "ركلات الترجيح" |
| Finished | Score + "انتهت" |
| Postponed | Amber "تأجلت" |
| Cancelled | "أُلغيت" |
| Abandoned | "توقفت" |
| Estimated live (no feed) | "مباشر" without a score, with a quieter treatment |
| Time unknown | "لم يُحدد" |

Matches without a time go into a "موعد لم يُحدد" group at the end.

**Tennis:** player names instead of teams, without logos.

**Interactions:**
- Tapping a row opens S3.
- Pull to refresh.
- Horizontal swipe on the list changes the day (RTL semantics).
- Long-press on a row shows quick actions: follow match, share.

**States:**
- Skeleton on first load (3 groups × 3 rows).
- Empty day: "لا توجد مباريات في هذا اليوم".
- Empty live: "لا توجد مباريات مباشرة الآن".
- Empty "My matches": "تابع فرقك لتظهر مبارياتها هنا" + "اختر فرقاً".
- Offline banner; "last updated" hint.

**Ads:** Android banner above the bottom nav. It takes space only once an ad has loaded, and must not shift content while the user is scrolling.

### S3 · Match detail (تفاصيل المباراة) [P + V1]

**Top bar:** back · follow match (bell, with reminder state) · share [V1].

**Hero:**
- Competition logo + name + stage.
- Large team logos and names, home on the right.
- Center: status, score or kickoff time.
- Below: local date and time (`الثلاثاء 28 أكتوبر · 9:00 م`) and, before kickoff, a countdown.
- When live: minute and period; scores animate when they change.

**Live center [V1]:** shown only when feed data exists.
- Events timeline: goal, own goal ("عكسي"), penalty ("ركلة جزاء"), missed penalty, red card. Each event shows minute, player and side.
- Tabs الأحداث / التشكيل; lineups only when available, as a pitch or two lists.
- If the status is estimated, a note says the score isn't available.

**Where to watch (أين تشاهد):** the core of the screen.

| Part | Content |
|---|---|
| Toolbar | Count, "المجانية فقط" chip, search field when there are more than 6 entries ("ابحث عن قمر أو قناة...") |
| 1 · على أقمارك | Carriages on my satellites, free first. If none are chosen: "على نايل سات وبدر" + a "حدد أقمارك" chip |
| 2 · أقمار أخرى | Collapsible groups per satellite (name + position + count). The first group is open, the rest collapsed |
| 3 · منصات وقنوات أخرى | Channels without a satellite, grouped by region (الشرق الأوسط، أوروبا، آسيا، الأمريكتان، أفريقيا، أوقيانوسيا، أخرى), then by country ("تبث داخل فرنسا"). Collapsed by default; can be hidden in settings |

**Carriage row**, collapsed; the answer is visible without tapping:
- channel logo and name (`beIN SPORTS 1`);
- satellite short name;
- **frequency readout** `11843 H 27500` (LTR);
- access badge: مجانية, or مشفرة plus the provider.

Expanding the row shows:
- satellite in Arabic and English with position;
- frequency, polarization (H أفقي / V رأسي / L / R) and symbol rate;
- access, provider and package; category;
- actions: copy frequency, follow channel, "طريقة استقبال القمر" (video), report a problem [V2].

**Commentators:** inside each channel card, one or two rows with avatar, "المعلق", name, and a play button for the voice clip. States: idle, loading, playing ("جاري التشغيل..."), error. Only one clip plays at a time.

**Manual broadcasters** (free-text, for example "ON Sport 1"): a broadcaster card with logo, label, and optional commentator. The first entry is labelled "يعرض على", the rest "يعرض أيضاً على".

**No channels:** "لم تُضف القنوات الناقلة بعد" + "تابع المباراة وسننبهك عند إضافتها" (follow CTA).

**Very long lists (up to 171):** virtualized, with groups collapsed, and a floating "العودة لأعلى القنوات" button.

**Match info:**
- stadium card ("الملعب"), with a photo if available;
- "القناة الناقلة في مصر" card;
- a match-level commentator card when it isn't tied to a channel.

**Feed link:** "فيد المباراة" appears if a feed exists (pending O3).

**Ads:** banner at the bottom (Android). The interstitial may fire when the user goes **back** from this screen (§5).

### S4 · My satellites (أقماري) [P + V1]

- **Satellite selector:** chips for my satellites (multi-select; "الكل" selects all) + "تعديل" → picker (the S1.3 component).
- **List:** date strip and live chip as in S2. Matches with at least one carriage on the selected satellites, grouped by competition; finished matches sink to the bottom of each group.
- **Row:** teams + status; below it, the channel(s) on those satellites, each with a frequency readout.
- **Empty states:**
  - no matches: "لا توجد مباريات على ‹نايل سات› لهذا اليوم";
  - no satellites chosen: an explanation + "اختر أقمارك".

### S5 · Frequencies (الترددات) [P + V1]

**S5.1 Satellite list:**
- Search field.
- Cards: logo or satellite glyph, Arabic name, English name + position (LTR), channel count, and [V1] a "N تغييرات هذا الأسبوع" badge.
- My satellites are pinned first with a marker.
- Order: admin priority.

**S5.2 Satellite detail:**
- **Header:** names, position.
- **Alignment aids:** "أقوى تردد" (green) and "أضعف تردد" (red), used to align the dish.
- **Video:** "طريقة استقبال القمر" button (opens YouTube).
- **Category switch:** segmented رياضة / ترفيه; swiping switches too.
- **Search:** "بحث في القنوات..." matches names and frequency digits.
- **Rows:** logo, name, frequency readout (always visible), access badge, and a "تغيّر مؤخراً" badge with date [V1]. Expanding a row shows the S3 details plus "عرض القناة" (→ S6).
- **Empty:** "لا توجد قنوات رياضة على هذا القمر".

### S6 · Channel (القناة) [V1]

A sheet on phone, a pane on desktop.
- Header: logo, display name, category, country.
- Carriage card: satellite, frequency readout + copy, access, provider/package.
- Other carriages of the same channel, on other satellites.
- Upcoming matches on this channel over the next 7 days (rows → S3).
- Frequency history: the last 3 changes with dates.
- Actions: "تابع القناة" (frequency alerts), report [V2].

### S7 · Team (الفريق) [V1]

- Header: logo, name, main competition, stadium.
- Follow button, with a sheet of notification types (S10).
- Tabs: القادمة (upcoming) / النتائج (results), as S2-style rows with channel lines.
- Empty: "لا توجد مباريات قادمة".

### S8 · Competition (البطولة) [V1]

- Header: logo, name.
- Actions: follow, hide/show.
- Matches by date (upcoming and results).
- A "حقوق البث" section listing rights holders → S11.4.

### S9 · Favorites (المفضلة) [V1]

- **Top:** "مبارياتي القادمة", the next 3 matches of followed items, plus "عرض الكل" (→ S2 with مبارياتي).
- **Sections:** الفرق · البطولات · القنوات · المعلقون [V2]. Each row shows the item, a bell state and a remove action.
- **Add buttons** open S14 filtered to that type.
- **Empty:** suggestions (popular teams in the user's region) + "أضف فرقاً".

### S10 · Follow notification sheet [V1]

Opened from any follow button. The toggles depend on what's being followed:

| Following | Toggles |
|---|---|
| Team, competition or match | تذكير قبل المباراة, with a lead time of 5/15/30/60 min (default 15) · بداية المباراة · الأهداف · النتيجة النهائية · تحديث القنوات |
| Channel | تغيير التردد |

A footer explains the platform state:
- **notifications off:** how to enable them;
- **iOS not installed:** link to S1.5.

### S11 · Broadcast rights (حقوق البث) [P]

| Screen | Content |
|---|---|
| S11.1 Home | Segmented "حسب القمر" / "حسب البطولة" |
| S11.2 By satellite | Satellite list → rights holders on that satellite |
| S11.3 By competition | Searchable competition list → rights holders |
| S11.4 Holder detail | Header logo + name. "حقوق البث": competitions list (logo + name; up to 29). "الترددات": carriage cards per satellite, each listing several frequencies (primary first) with access and package |

Holder rows show the logo, the name, the first 4 competitions + "+N", and the package count ("باقة" / "باقتان" / "3 باقات").

### S12 · Feeds (الفيدات) [P, pending O3]

- **List:** sorted by date and time, with a "N فيد" count.
- **Card:** both teams with logos, date, match status, and free-text lines (`Eutelsat 3.1°E - 10969 H 7500`), shown LTR.
- **Copy:** "نسخ الفيد" copies all lines.
- **Navigation:** opened from S3 ("فيد المباراة") it scrolls to that feed, and back returns to the match.
- **Empty:** "لا يوجد فيدات".

The feeds collection is empty today, so this screen is low priority. It must never show BISS keys (§16).

### S13 · Other sports [V1]

Folded into S2 through the sport switcher; there's no separate screen. Data comes from sporteventz.

### S14 · Search (البحث) [V1]

- Full-screen field with recent searches.
- Results grouped as فرق · بطولات · قنوات · أقمار · معلقون, with matched text highlighted. Search ignores Arabic letter variants (أ/ا, ة/ه, ى/ي).
- Each row has a follow shortcut.
- **Empty:** "لا توجد نتائج لـ «…»".

### S15 · Settings (الإعدادات) [P + V1]

| Group | Items |
|---|---|
| التوقيت | المنطقة الزمنية: "تلقائي (GMT+3)" or a list from GMT−12 to GMT+14 · صيغة الوقت: 12 / 24 ساعة |
| المظهر | الوضع: داكن / فاتح / تلقائي [V1] · حجم الخط: عادي / كبير / كبير جداً (1.0 / 1.15 / 1.3×, on top of the OS setting) |
| الإشعارات [V1] | Master switch · default reminder lead time · per-type switches · platform state (permission denied → steps to enable; iOS not installed → S1.5) |
| أقماري | Choose my satellites · show/hide satellites in channel lists ("N من 32 مرئي") · show "منصات وقنوات أخرى" |
| البطولات | Order and hide (drag handle ⋮⋮, "اسحب لإعادة الترتيب"), "ترتيب افتراضي", "إظهار الكل" |
| البيانات | Last sync time · clear cache |
| عن التطبيق | Version · share the app · rate · contact/feedback · privacy policy · terms · delete my device data · open-source licenses |

### S16 · More (المزيد) [P]

A list of rows, each with an icon, title and subtitle:
- حقوق البث;
- الفيدات (if kept);
- مكتشف الأقمار [V2];
- تثبيت التطبيق (iOS PWA only, → S1.5);
- شارك التطبيق ("ساعد في انتشار التطبيق");
- الإعدادات;
- سياسة الخصوصية;
- an about card with the brand, tagline "مواعيد المباريات والقنوات الناقلة والترددات" and the version.

### Later screens

| Screen | Content |
|---|---|
| S17 Commentator profile [V2] | Photo, name, voice clip, follow, upcoming matches they commentate (with the channel) |
| S18 Satellite finder [V2] | Choose a satellite (mine first), location permission or city entry. Readouts: azimuth (true and magnetic), elevation, LNB skew. Compass dial with a target needle; calibration hint. Camera overlay on native builds only |
| S19 Report a problem [V2] | Sheet from a carriage or channel. Kind: القناة لا تعمل / التردد خاطئ / القناة لا تنقل المباراة / أخرى. Optional note (≤ 280 characters). Thank-you state |
| S20 Widget + ongoing notification [V2] | Small widget: next followed match + channel. Medium: today's followed matches with status. Ongoing notification during a followed live match: score, minute, channel |
| S21 [V3] | Predictions and leaderboards (needs accounts) · share a match card image · add to calendar · ad-free purchase |

---

## 10. Admin web screens (Arabic, RTL, desktop-first)

Users are 2–5 editors entering data quickly and under time pressure before kickoffs. Optimize for keyboard use, dense tables, and clear source and lock indicators.

| # | Screen | Key content |
|---|---|---|
| A0 | Shell | Sidebar on the right: لوحة المتابعة، المباريات، الفرق، البطولات، القنوات، الأقمار، حقوق البث، المعلقون، الفيدات، القوائم، المصادر، البلاغات [V2]، الإشعارات، المستخدمون، سجل التغييرات. Top bar: global search, user and role |
| A1 | Login | Email + password ("سجل دخول للوحة التحكم"); error "إيميل أو باسوورد غلط"; lockout message; TOTP step [V2] |
| A2 | Dashboard | Today's coverage: matches without channels, by competition priority; matches without a commentator. Source health tiles (last success, items, errors, breaker state). Unresolved names count. Open reports. Recent changes |
| A3 | Matches | Day tabs (أمس / اليوم / غداً / بعد غد / تاريخ…). Filters: competition, source, missing channels, status. Rows grouped by competition: time, teams + logos, status, channel count, commentator, source badges, lock icon. Bulk: change competition, remove channels, delete. "إضافة مباراة" |
| A4 | Match editor | Teams (picker that disambiguates same-name teams by league and logo) · date and time (shown in the admin's zone, stored in UTC) · competition + stage (presets: الجولة الأولى، ذهاب/إياب دور 16، ربع النهائي، نصف النهائي، النهائي) · stadium · status override + score · two manual broadcaster slots (label from presets, logo, commentator) · channel picker (search, satellite filter, رياضة/ترفيه, platforms without satellite) → chosen list with, per channel: source badge, "إخفاء من هذا الماتش فقط", "إخفاء دائماً", commentator 1 and 2 · events (minimal) · locked-fields indicator · history tab |
| A5 | Teams | Table with search and filters (competition, missing logo). Editor: name, aliases, logo upload (preview on dark and light tiles), main and other competitions, stadium, external IDs. **Merge tool**: pick duplicates → choose the survivor → preview the affected matches |
| A6 | Competitions | List with drag-to-rank priority. Editor: name, aliases, logo, "تحديث لوجوهات المباريات" |
| A7 | Satellites | Drag order. Editor: Arabic and English names, orbital position, best and worst frequency, reception video (https only), logo |
| A8 | Channels | Table. Filters: satellite, category, access, missing logo, platform-only, shown on match pages. Editor: matching name, display name, logo, satellite, frequency (MHz / H·V·L·R / symbol rate) or a note, access + provider + package, category, country, show on match pages. Also "إضافة على قمر آخر", frequency history, cleanup tools with typed confirmation |
| A9 | Rights holders | Drag order. Editor: name, logo, competitions multi-select, carriages (satellites multi-select, frequency list with a primary radio, access, package) |
| A10 | Commentators | Table with photo, play button, rename, replace image or audio, merge, delete (shows usage count first) |
| A11 | Lists | Broadcaster presets · hidden channel names, with the explanation "القنوات في هذه القائمة لا تظهر على أي مباراة" |
| A12 | Feeds | Teams, date, lines (one frequency per line). Pending O3 |
| A13 | Sources | Card per source: status, last success, items-found sparkline, error rate, breaker state; "تشغيل الآن", "إيقاف/استئناف". Run history → run detail (log, counts, errors, raw page). **Unresolved names** queue: name, source, match context; actions: map to existing, create new, ignore |
| A14 | Reports [V2] | Queue: kind, channel, match, age, reporter rate. Detail: current carriage data. Actions: accept (opens the channel editor pre-filled), reject |
| A15 | Notifications | Outbox log (type, target, sent/failed, time). Composer (admin only): title, body, deep link (match/channel picker), audience (all / followers of X), schedule, test send, Android and iOS previews |
| A16 | Admin users | Create, role (محرر / مدير), deactivate, reset password |
| A17 | Audit log | Filter by user, entity, date; side-by-side diff |

**Common admin states:**
- table skeletons; empty states;
- toasts: "تم الحفظ", "فشل الحفظ";
- an unsaved-changes guard;
- a conflict dialog: "عدّل ‹user› هذا العنصر — اعرض التغييرات";
- destructive actions need typed confirmation.

---

## 11. Notification catalog

Bidi rule: build every score string from isolated parts (§13.4); don't concatenate a raw `1 - 0`.

| Type | Title | Body | Opens |
|---|---|---|---|
| Kickoff reminder | ‹الأهلي› × ‹الزمالك› بعد 15 دقيقة | على ‹أون سبورت 1› · ‹نايل سات› — اضغط لعرض القنوات والترددات | S3 |
| Match started | بدأت المباراة | ‹الأهلي› × ‹الزمالك› | S3 |
| Goal | هدف لـ ‹الأهلي›! | ‹الأهلي› 1 – 0 ‹الزمالك› · ‹اسم اللاعب› 23′ | S3 |
| Final score | انتهت المباراة | ‹الأهلي› 2 – 1 ‹الزمالك› | S3 |
| Channels updated | قنوات جديدة لمباراة ‹الأهلي› × ‹الزمالك› | أُضيفت ‹beIN SPORTS 1› على ‹نايل سات› | S3, scrolled to channels |
| Frequency changed | تغيّر تردد ‹beIN SPORTS 1› | على ‹نايل سات›: 11843 H 27500 (كان 11766 H 27500) | S6 |
| Announcement | Admin text | Admin text | Deep link |

Notifications for the same match replace each other (tag `match_<id>`). The small icon is a monochrome brand glyph.

---

## 12. Content and data dictionary

Lengths are measured in characters from the 2026-10-28 snapshot.

| Field | Example | Median / p95 / max | Notes |
|---|---|---|---|
| Team name | الأهلي · جمهورية الكونغو الديمقراطية | 8 / 16 / 27 | Up to 2 lines on rows. Not unique |
| Competition | الدوري المصري الممتاز · دوري أبطال أفريقيا \| الأدوار الإقصائية | 19 / 30 / 38 | |
| Stage | الجولة 9 · الجولة 13 - الذهاب · نصف نهائي - الإياب | 17 / 21 / 25 | Chip |
| Stadium | استاد القاهرة · Estádio São Januário (Rio de Janeiro, Rio de Janeiro) | 16 / 28 / 53 | Can be Latin text; truncate |
| Channel display name | أون سبورت 1 · beIN SPORTS 1 · SuperSport Premier League Nigeria | 13 / 22 / 33 | Often Latin |
| Satellite | نايل سات / Nilesat 7.0W · Hotbird 13.0E · DVB T2 | — | Arabic name + English name with position; "DVB T2" is terrestrial |
| Frequency | `11843 H 27500` | fixed | MHz, polarization H/V/L/R, symbol rate. Some carriages have a note instead (`UHF 32`) |
| Access | مجانية / مشفرة · provider beIN | — | See O3 |
| Country (platform rows) | السعودية · الأراضي الفلسطينية المحتلة | 7 / 16 / 26 | |
| Rights holder | CANAL+SPORT · Arena Sport Croatia | 11 / 18 / 19 | Latin brand |
| Commentator | Name + photo + voice clip (≤ 30 s) | — | 119 total |
| Time | `9:00 م` · `21:00` | — | 12 h with ص/م, or 24 h |
| Minute | `67′` · `45+2′` · `90+5′` | — | |
| Counts | 17–97 matches a day · 8–27 competitions a day · 0–171 channels a match · 189 channels on Hotbird | — | Design for both extremes |

Team, competition and channel **logos** are third-party images of uneven quality and aspect ratio, and are sometimes missing. Always show them inside a neutral tile or frame. Placeholders:

| Missing | Placeholder |
|---|---|
| Team | Monogram in a neutral crest |
| Competition | Trophy glyph |
| Channel | Screen glyph + initials |
| Satellite | Satellite glyph |
| Commentator | Initials avatar |

---

## 13. Design-system requirements

### 13.1 Direction

**Recommended: "broadcast control room."**
- Instrument-panel precision: frequency readouts treated like equipment displays, signal and orbit motifs used sparingly.
- Deep ink surfaces in dark mode, a clean paper surface in light mode.
- One energetic brand accent; red reserved for **live** only.

It's a rebrand, so don't carry over Sat Air's look (navy `#0f172a`, blue `#3b82f6`, gray gradient cards). Its *semantic* conventions are worth keeping (§13.2).

**Avoid:** emoji as icons, generic gradient hero blobs, uniform card grids with identical weight, safe gray-on-white with one accent, glassmorphism over long lists (it performs badly in Flutter on low-end Android and on web).

### 13.2 Semantic color tokens (both themes)

| Token group | Members |
|---|---|
| Surfaces | `bg`, `surface-1/2/3`, `elevated`, `overlay`, `divider`, `focus-ring` |
| Text | `text-primary/secondary/tertiary/on-accent/disabled` |
| Brand | `accent`, `accent-container`, `on-accent` |
| Status | `live` (+ container) · `halftime` · `finished` (neutral) · `postponed` (amber) · `cancelled` / `abandoned` (muted) · `estimated` (low-emphasis live) |
| Access | `free` (positive) · `encrypted` (neutral, with a lock icon; it's not an error) |
| Category | `sports`, `entertainment` |
| Data | `frequency` (readout color), `changed` (recent-change badge), `follow` (star/bell) |
| Feedback | `success`, `warning`, `error`, `info` |

Never rely on color alone: live, free and encrypted each have an icon or label too. Contrast must meet WCAG AA in both themes.

### 13.3 Typography

- **Fonts:** one Arabic + Latin UI family with **tabular lining figures**, plus at most one display family for the wordmark and large headings. Both must be OFL or similarly open, and are **bundled**; the PWA must not fetch fonts at runtime. Sat Air used IBM Plex Sans Arabic + Readex Pro; the rebrand can change that.
- **Digits:** frequencies, scores, minutes and times use tabular figures. All digits are Western (0–9).
- **Scale:** the type scale must survive **1.3× in-app** times the OS text scale. Test the match row, status block and bottom nav at 1.3×.

### 13.4 RTL and bidirectional text

- The layout is mirrored: "forward" chevrons point left, and back arrows point right.
- **LTR islands**, rendered as isolated elements and never concatenated into Arabic strings:
  - frequencies (`11843 H 27500`);
  - English satellite names (`Nilesat 7.0W`);
  - Latin channel names (`beIN SPORTS 1`);
  - feed lines.
- Scores: each number sits next to its own team (home on the right). Never render a single `1 - 0` string inside RTL text.
- Dates: `الثلاثاء 28 أكتوبر`, with month names يناير … ديسمبر. Times: `9:00 م` / `21:00`.

### 13.5 Iconography, imagery, motion

- **Icons:** a consistent line-icon set, drawn or chosen for this product, including satellite, dish, signal, frequency, lock/unlock, commentator/mic, whistle, card, ball, own goal, penalty, bell, star, copy and share. No emoji.
- **Logos:** placeholders as in §12.
- **Motion:**
  - live pulse (subtle);
  - a brief highlight when a score changes;
  - date-strip paging;
  - expand/collapse;
  - shimmer skeletons.
- **Reduced motion:** honor the OS setting, which disables the pulse and the shimmer.

### 13.6 Components (each with all states: default, hover [web], pressed, focus, selected, disabled, loading, error)

**App:**
- Navigation: BottomNav, NavRail (desktop), TopBar.
- Matches: DateStrip, FilterChips, SportSwitcher, CompetitionGroupHeader, MatchRow (+ channel line), StatusBlock (every §9 S2 variant), ScoreHero, EventTimelineItem, Lineup.
- Channels: CarriageRow (collapsed/expanded), FrequencyReadout (+ copy feedback), AccessBadge, SatelliteBadge, ChangedBadge, BroadcasterCard, CommentatorRow (idle/loading/playing/error), RegionGroup.
- Actions and inputs: FollowButton, BellButton, SearchField, SegmentedControl, Toggle, Slider/Stepper (font size).
- Containers: ListRow (settings), Sheet, Dialog, Snackbar.
- Feedback: EmptyState, ErrorState, OfflineBanner, StaleHint, Skeletons.
- Platform: AdBannerSlot, InstallGuideStep, PermissionPrimingCard, UpdateBanner.

**Admin:**
- Navigation: SidebarNav.
- Data: DataTable (sort, filter, bulk select, row actions), FilterBar, SourceHealthCard, Sparkline, StatusChip.
- Forms: EntityPicker (with disambiguation), ImageUpload (dark and light preview), AudioUpload + player, DragOrderList, FormSection.
- Feedback: DiffViewer, ConfirmDialog (typed confirmation), Toast, ConflictDialog.

### 13.7 Layout and platform constraints

- **Grid:** 4 dp base; 16 dp phone gutters; touch targets ≥ 48 × 48 dp.
- **Safe areas:** respect them, including the iPhone PWA notch and home indicator.
- **Breakpoints:** see §8.3.
- **Flutter feasibility:** use Material 3 behavior underneath, but it doesn't need to look like Material. Keep shadows and blur modest. Use images as WebP. Lottie is fine for one or two empty states.
- **Device baseline:** low- to mid-range Android (2–4 GB RAM, 360 dp wide).

### 13.8 Accessibility

- Arabic screen-reader labels for composite rows. Example: "الأهلي ضد الزمالك، مباشر، الدقيقة 67، النتيجة 1 مقابل 0، على أون سبورت 1".
- Visible focus on web.
- Contrast at AA or better.
- Font scale as in §13.3.
- Don't encode meaning in color alone.
- Voice clips play only on a user tap and can be paused.

---

## 14. Voice and glossary

**Tone:** short, clear Modern Standard Arabic that's friendly and direct. Sat Air mixed in Egyptian dialect ("تقدر تغيّره", "لازم تسمح"); keep a light touch of warmth, but stay pan-Arab.

| Concept | Arabic | Avoid |
|---|---|---|
| Live | مباشر | |
| Halftime | استراحة | راحة (old) |
| Full time | انتهت | |
| Postponed / cancelled / abandoned | تأجلت / أُلغيت / توقفت | |
| Broadcasting channels | القنوات الناقلة | |
| Shown on / also shown on | يعرض على / يعرض أيضاً على | |
| Satellite / frequency / polarization / symbol rate | القمر / التردد / الاستقطاب / معدل الترميز | |
| Free / encrypted | مجانية / مشفرة | مكسورة, card-sharing names |
| My satellites | أقماري | |
| Commentator | المعلق | |
| Broadcast rights | حقوق البث | |
| Feed | فيد | |
| Follow / following | تابع / المفضلة | |

---

## 15. Analytics

Events go through Firebase Analytics on all platforms, after consent where required:

| Event | Properties |
|---|---|
| `screen_view` | Screen |
| `match_open` | Source (list, push, search, deep link), status |
| `carriage_expand`, `frequency_copy` | Channel, satellite, on_my_satellites |
| `commentator_play` | Commentator |
| `follow_add`, `follow_remove` | Type, target |
| `my_satellites_set` | Count |
| `notification_open` | Type |
| `search` | Result count |
| `install_guide_view`, `pwa_installed` | |
| `report_submit` | Kind |
| `ad_impression` | Format |

---

## 16. Legal, policy and trust

| Topic | Position |
|---|---|
| **Card-sharing labels** | Sat Air's "encryption" field names card-sharing server services (`Mega Share`, `Apollo`, `VIP`) and marks channels "ليست مكسورة" ("not cracked"). That points users to unauthorized decryption. It risks removal from Google Play and the App Store under intellectual-property policies, and action from rights holders. **Recommendation (O3):** don't carry it over. Show only مجانية / مشفرة + the official provider or package. The designs should assume this |
| **Feeds with BISS keys** | Same issue. If Feeds are kept, show frequencies only, never keys |
| Data sources | Fixtures and channels are scraped; site terms may forbid this. The curated channel and frequency data is our own. Plan a licensed fixtures API once revenue allows |
| Logos and voice clips | Third-party marks and recordings, common in this category. Credit the sources and respond to takedown requests within 48 h |
| Privacy | No accounts. Anonymous device ID, push token, time zone and follows. A data-deletion option in Settings. A privacy policy page and the Play data-safety form are required |
| Ads consent | The AdMob UMP consent form is required for EEA/UK users, which includes diaspora users |
| Store policies | Interstitials only at natural transitions (Google's "unexpected interstitials" policy). The iOS app later needs native value (push, widget) to pass guideline 4.2 |

---

## 17. Launch plan and success criteria

1. **Closed beta:** Play internal track + a private PWA link, 20–50 testers from the owner's communities. Run it alongside Sat Air for 2–3 weeks.
2. **Open beta:** Play open testing + a public PWA link with the install guide.
3. **Launch:** be stable 2–3 weeks *before* a high-traffic period (for example, the Champions League knockout rounds in February–March), not in the middle of a tournament.

**Launch gate:**
- crash-free sessions ≥ 99.5 %;
- ≥ 95 % channel coverage in prioritized competitions at T−2 h;
- live status correct on a 2-week sample;
- push delivery verified on Android and on an installed iOS PWA;
- consent flow, privacy policy and data-safety form complete.

---

## 18. Open decisions

O1–O3 and O7 are the same items as in system-design §3.2. O8–O10 are product-only.

| # | Decision | Owner input needed |
|---|---|---|
| O1 | Package ID (the name is set: Madar Sat / مدار سات) | Trademark and store-name checks for "Madar Sat", then the ID |
| O2 | v1 scope (§6) | Confirm or trim [V1] items |
| O3 | Card-sharing labels and BISS keys: drop (recommended) or keep | Yes/no. The designs assume drop |
| O7 | Live data source for minute, events and lineups | **Decided 2026-11-04, pending the live capture:** FilGoal main, YallaKora cross-check (system-design §3.3). Coverage varies by match, so S3's live center must cope with missing events or lineups |
| O8 | Keep Feeds in v1? | The collection is empty today |
| O9 | Interstitial placement (§5) | Confirm "on return from detail" |
| O10 | Default "My satellites" when the user skips: Nilesat + Badr (old rule) or regional by time zone | Confirm |
