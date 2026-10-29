// GENERATED from design-system/tokens.json (Madar Design System). Do not edit by hand: change tokens.json and regenerate.
//
// Usage:
//   MaterialApp(theme: buildMadarTheme(Brightness.light), darkTheme: buildMadarTheme(Brightness.dark), themeMode: ThemeMode.dark)
//   final c = context.madarColors;  Container(color: c.surface1)
//   Text('8:00', style: MadarText.rowTime.copyWith(color: c.textPrimary))

import 'package:flutter/material.dart';

/// Colour tokens. One field per token in tokens.json, with the same meaning (see `usage`).
@immutable
class MadarColors extends ThemeExtension<MadarColors> {
  const MadarColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.elevated,
    required this.segmentedOn,
    required this.overlay,
    required this.divider,
    required this.dividerStrong,
    required this.focusRing,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnInverse,
    required this.accent,
    required this.accentContainer,
    required this.accentText,
    required this.onAccent,
    required this.snackbarAction,
    required this.live,
    required this.liveContainer,
    required this.halftime,
    required this.halftimeContainer,
    required this.postponed,
    required this.postponedContainer,
    required this.cancelled,
    required this.estimated,
    required this.free,
    required this.freeContainer,
    required this.encrypted,
    required this.encryptedContainer,
    required this.sports,
    required this.sportsContainer,
    required this.entertainment,
    required this.entertainmentContainer,
    required this.readoutBg,
    required this.readout,
    required this.readoutDim,
    required this.readoutLine,
    required this.changed,
    required this.changedContainer,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorContainer,
    required this.info,
  });

  /// App and page background (ink in dark, paper in light). CSS alias --bg.
  final Color bg;
  /// Cards, list groups, bottom nav, match hero, admin panels. Alias --s1.
  final Color surface1;
  /// Logo tiles, search fields, segmented track, pressed rows, expanded carriage rows. Alias --s2.
  final Color surface2;
  /// Count pills, toggle track off, avatar placeholders. Alias --s3.
  final Color surface3;
  /// Bottom sheets, dialogs, menus. Alias --el.
  final Color elevated;
  /// Selected segment of a segmented control. Alias --segon.
  final Color segmentedOn;
  /// Scrim behind sheets and dialogs. Alias --ov.
  final Color overlay;
  /// Row separators and card hairlines. Alias --dv.
  final Color divider;
  /// Chip and input outlines, unchecked controls. Alias --dv2.
  final Color dividerStrong;
  /// Visible keyboard focus outline, 2px, offset 2px (web and admin). Alias --fr.
  final Color focusRing;
  /// Main text on bg and surfaces. Alias --tx.
  final Color textPrimary;
  /// Secondary text, channel lines, metadata. Alias --tx2.
  final Color textSecondary;
  /// Captions, section labels, AM/PM marks. Passes 4.5:1 on surface-1 in both themes. Alias --tx3.
  final Color textTertiary;
  /// Disabled labels only; never body copy. Alias --txd.
  final Color textDisabled;
  /// Text on inverted fills (selected chips, snackbars, play buttons). Alias --oninv.
  final Color textOnInverse;
  /// Volt brand fill: primary buttons, selected date, toggles on, nav indicator dot. Always with on-accent text. Alias --ac.
  final Color accent;
  /// Tinted backgrounds: active nav pill, 'on my satellites' group, followed states. Alias --acc.
  final Color accentContainer;
  /// Accent used as text or icon (links, followed bell, imminent countdown). Alias --act.
  final Color accentText;
  /// Text and icons on accent fills (16:1). Alias --onac.
  final Color onAccent;
  /// Action label inside an inverted snackbar or toast. Alias --snk.
  final Color snackbarAction;
  /// LIVE ONLY: live pill, pulse dot, minute. Never for errors or decoration. Alias --live.
  final Color live;
  /// Background of the live pill. Alias --livec.
  final Color liveContainer;
  /// Halftime pill text (استراحة). Alias --ht.
  final Color halftime;
  /// Halftime pill background. Alias --htc.
  final Color halftimeContainer;
  /// Postponed status (تأجلت), warnings, 'near limit'. Alias --pp.
  final Color postponed;
  /// Postponed pill and warning banner background. Alias --ppc.
  final Color postponedContainer;
  /// Cancelled and abandoned states: muted, not alarming. Alias --cx.
  final Color cancelled;
  /// Clock-estimated live (no feed): dashed outline pill, no score. Alias --est.
  final Color estimated;
  /// Free-to-air badge text and unlock icon (مجانية). Alias --free.
  final Color free;
  /// Free badge background. Alias --freec.
  final Color freeContainer;
  /// Encrypted badge text with lock icon (مشفرة). Neutral on purpose: not an error. Alias --enc.
  final Color encrypted;
  /// Encrypted badge background. Alias --encc.
  final Color encryptedContainer;
  /// Sports category pill (رياضة) and info icons. Alias --sp.
  final Color sports;
  /// Sports pill background. Alias --spc.
  final Color sportsContainer;
  /// Entertainment category pill (ترفيه). Alias --en.
  final Color entertainment;
  /// Entertainment pill background. Alias --enc2.
  final Color entertainmentContainer;
  /// Frequency readout well. Stays dark in light mode: it is an equipment display. Alias --rdb.
  final Color readoutBg;
  /// Frequency digits and polarization letter on readout-bg. Alias --rd.
  final Color readout;
  /// Symbol rate and units inside the readout (5.7:1 on readout-bg). Alias --rd2.
  final Color readoutDim;
  /// Readout outline and polarization cell border. Alias --rdl.
  final Color readoutLine;
  /// 'Changed recently' frequency badge text. Alias --chg.
  final Color changed;
  /// 'Changed recently' badge background. Alias --chgc.
  final Color changedContainer;
  /// Healthy source, sent, saved. Alias --ok.
  final Color success;
  /// Warnings (same hue as postponed). Alias --warn.
  final Color warning;
  /// Validation errors, failed saves, destructive actions. Distinct from live. Alias --err.
  final Color error;
  /// Error banner and destructive button background. Alias --errc.
  final Color errorContainer;
  /// Neutral information icons and toasts. Alias --info.
  final Color info;

  static const dark = MadarColors(
    bg: Color(0xFF07090C),
    surface1: Color(0xFF0F1318),
    surface2: Color(0xFF161B22),
    surface3: Color(0xFF1F262F),
    elevated: Color(0xFF1A2029),
    segmentedOn: Color(0xFF2A323D),
    overlay: Color(0xAD020406),
    divider: Color(0x12FFFFFF),
    dividerStrong: Color(0x24FFFFFF),
    focusRing: Color(0xFFC8F542),
    textPrimary: Color(0xFFF1F4F7),
    textSecondary: Color(0xFFA9B2BF),
    textTertiary: Color(0xFF848E9B),
    textDisabled: Color(0xFF56606B),
    textOnInverse: Color(0xFF07090C),
    accent: Color(0xFFC8F542),
    accentContainer: Color(0x1FC8F542),
    accentText: Color(0xFFC8F542),
    onAccent: Color(0xFF0A0D0F),
    snackbarAction: Color(0xFF3F6A06),
    live: Color(0xFFFF4D5E),
    liveContainer: Color(0x26FF4D5E),
    halftime: Color(0xFFFF9E58),
    halftimeContainer: Color(0x26FF9E58),
    postponed: Color(0xFFFFB627),
    postponedContainer: Color(0x24FFB627),
    cancelled: Color(0xFF8B949F),
    estimated: Color(0xFFE58A94),
    free: Color(0xFF3EE0A1),
    freeContainer: Color(0x1F3EE0A1),
    encrypted: Color(0xFFA9B2BF),
    encryptedContainer: Color(0x12FFFFFF),
    sports: Color(0xFF7CC7FF),
    sportsContainer: Color(0x217CC7FF),
    entertainment: Color(0xFFE3A1FF),
    entertainmentContainer: Color(0x21E3A1FF),
    readoutBg: Color(0xFF020406),
    readout: Color(0xFF8FE7FF),
    readoutDim: Color(0xFF6F93A1),
    readoutLine: Color(0x2E8FE7FF),
    changed: Color(0xFFB9A2FF),
    changedContainer: Color(0x26B9A2FF),
    success: Color(0xFF3EE0A1),
    warning: Color(0xFFFFB627),
    error: Color(0xFFFF6B6B),
    errorContainer: Color(0x21FF6B6B),
    info: Color(0xFF7CC7FF),
  );

  static const light = MadarColors(
    bg: Color(0xFFF2F3EF),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFECEEE9),
    surface3: Color(0xFFE1E4DE),
    elevated: Color(0xFFFFFFFF),
    segmentedOn: Color(0xFFFFFFFF),
    overlay: Color(0x6B0A0D10),
    divider: Color(0x140C1014),
    dividerStrong: Color(0x290C1014),
    focusRing: Color(0xFF0A0D0F),
    textPrimary: Color(0xFF0B0F13),
    textSecondary: Color(0xFF475160),
    textTertiary: Color(0xFF5E6876),
    textDisabled: Color(0xFF9AA2AC),
    textOnInverse: Color(0xFFF2F3EF),
    accent: Color(0xFFC8F542),
    accentContainer: Color(0xFFEAF8C4),
    accentText: Color(0xFF3F6A06),
    onAccent: Color(0xFF0A0D0F),
    snackbarAction: Color(0xFFC8F542),
    live: Color(0xFFC81B33),
    liveContainer: Color(0xFFFDE6E9),
    halftime: Color(0xFFA64A0C),
    halftimeContainer: Color(0xFFFDEBDD),
    postponed: Color(0xFF955200),
    postponedContainer: Color(0xFFFDF0D2),
    cancelled: Color(0xFF6B7480),
    estimated: Color(0xFFB23A4A),
    free: Color(0xFF047A55),
    freeContainer: Color(0xFFDDF4EA),
    encrypted: Color(0xFF475160),
    encryptedContainer: Color(0xFFE8EAE5),
    sports: Color(0xFF0B5FAD),
    sportsContainer: Color(0xFFE2EEFA),
    entertainment: Color(0xFF8A2BB0),
    entertainmentContainer: Color(0xFFF5E6FB),
    readoutBg: Color(0xFF0B0F13),
    readout: Color(0xFF8FE7FF),
    readoutDim: Color(0xFF7FA4B2),
    readoutLine: Color(0x298FE7FF),
    changed: Color(0xFF5B3CC4),
    changedContainer: Color(0xFFECE6FF),
    success: Color(0xFF047A55),
    warning: Color(0xFF955200),
    error: Color(0xFFC62828),
    errorContainer: Color(0xFFFDE8E8),
    info: Color(0xFF0B5FAD),
  );

  @override
  MadarColors copyWith({Color? bg, Color? surface1, Color? surface2, Color? surface3, Color? elevated, Color? segmentedOn, Color? overlay, Color? divider, Color? dividerStrong, Color? focusRing, Color? textPrimary, Color? textSecondary, Color? textTertiary, Color? textDisabled, Color? textOnInverse, Color? accent, Color? accentContainer, Color? accentText, Color? onAccent, Color? snackbarAction, Color? live, Color? liveContainer, Color? halftime, Color? halftimeContainer, Color? postponed, Color? postponedContainer, Color? cancelled, Color? estimated, Color? free, Color? freeContainer, Color? encrypted, Color? encryptedContainer, Color? sports, Color? sportsContainer, Color? entertainment, Color? entertainmentContainer, Color? readoutBg, Color? readout, Color? readoutDim, Color? readoutLine, Color? changed, Color? changedContainer, Color? success, Color? warning, Color? error, Color? errorContainer, Color? info}) => MadarColors(
        bg: bg ?? this.bg,
        surface1: surface1 ?? this.surface1,
        surface2: surface2 ?? this.surface2,
        surface3: surface3 ?? this.surface3,
        elevated: elevated ?? this.elevated,
        segmentedOn: segmentedOn ?? this.segmentedOn,
        overlay: overlay ?? this.overlay,
        divider: divider ?? this.divider,
        dividerStrong: dividerStrong ?? this.dividerStrong,
        focusRing: focusRing ?? this.focusRing,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        textDisabled: textDisabled ?? this.textDisabled,
        textOnInverse: textOnInverse ?? this.textOnInverse,
        accent: accent ?? this.accent,
        accentContainer: accentContainer ?? this.accentContainer,
        accentText: accentText ?? this.accentText,
        onAccent: onAccent ?? this.onAccent,
        snackbarAction: snackbarAction ?? this.snackbarAction,
        live: live ?? this.live,
        liveContainer: liveContainer ?? this.liveContainer,
        halftime: halftime ?? this.halftime,
        halftimeContainer: halftimeContainer ?? this.halftimeContainer,
        postponed: postponed ?? this.postponed,
        postponedContainer: postponedContainer ?? this.postponedContainer,
        cancelled: cancelled ?? this.cancelled,
        estimated: estimated ?? this.estimated,
        free: free ?? this.free,
        freeContainer: freeContainer ?? this.freeContainer,
        encrypted: encrypted ?? this.encrypted,
        encryptedContainer: encryptedContainer ?? this.encryptedContainer,
        sports: sports ?? this.sports,
        sportsContainer: sportsContainer ?? this.sportsContainer,
        entertainment: entertainment ?? this.entertainment,
        entertainmentContainer: entertainmentContainer ?? this.entertainmentContainer,
        readoutBg: readoutBg ?? this.readoutBg,
        readout: readout ?? this.readout,
        readoutDim: readoutDim ?? this.readoutDim,
        readoutLine: readoutLine ?? this.readoutLine,
        changed: changed ?? this.changed,
        changedContainer: changedContainer ?? this.changedContainer,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        errorContainer: errorContainer ?? this.errorContainer,
        info: info ?? this.info,
      );

  @override
  MadarColors lerp(ThemeExtension<MadarColors>? other, double t) {
    if (other is! MadarColors) return this;
    return MadarColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      segmentedOn: Color.lerp(segmentedOn, other.segmentedOn, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnInverse: Color.lerp(textOnInverse, other.textOnInverse, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      snackbarAction: Color.lerp(snackbarAction, other.snackbarAction, t)!,
      live: Color.lerp(live, other.live, t)!,
      liveContainer: Color.lerp(liveContainer, other.liveContainer, t)!,
      halftime: Color.lerp(halftime, other.halftime, t)!,
      halftimeContainer: Color.lerp(halftimeContainer, other.halftimeContainer, t)!,
      postponed: Color.lerp(postponed, other.postponed, t)!,
      postponedContainer: Color.lerp(postponedContainer, other.postponedContainer, t)!,
      cancelled: Color.lerp(cancelled, other.cancelled, t)!,
      estimated: Color.lerp(estimated, other.estimated, t)!,
      free: Color.lerp(free, other.free, t)!,
      freeContainer: Color.lerp(freeContainer, other.freeContainer, t)!,
      encrypted: Color.lerp(encrypted, other.encrypted, t)!,
      encryptedContainer: Color.lerp(encryptedContainer, other.encryptedContainer, t)!,
      sports: Color.lerp(sports, other.sports, t)!,
      sportsContainer: Color.lerp(sportsContainer, other.sportsContainer, t)!,
      entertainment: Color.lerp(entertainment, other.entertainment, t)!,
      entertainmentContainer: Color.lerp(entertainmentContainer, other.entertainmentContainer, t)!,
      readoutBg: Color.lerp(readoutBg, other.readoutBg, t)!,
      readout: Color.lerp(readout, other.readout, t)!,
      readoutDim: Color.lerp(readoutDim, other.readoutDim, t)!,
      readoutLine: Color.lerp(readoutLine, other.readoutLine, t)!,
      changed: Color.lerp(changed, other.changed, t)!,
      changedContainer: Color.lerp(changedContainer, other.changedContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Elevation and glow tokens. `readoutGlow` is a text shadow for FrequencyReadout digits only.
@immutable
class MadarShadows extends ThemeExtension<MadarShadows> {
  const MadarShadows({required this.shadowRaised, required this.shadowSubtle, required this.readoutGlow});

  /// Sheets, dialogs, menus, toasts, floating buttons. Alias --sh.
  final List<BoxShadow> shadowRaised;
  /// Selected segment, notification previews. Alias --sh2.
  final List<BoxShadow> shadowSubtle;
  /// Text glow on readout digits only (used as text-shadow). Alias --rdg.
  final List<Shadow> readoutGlow;

  static const dark = MadarShadows(
    shadowRaised: [BoxShadow(offset: Offset(0, 18), blurRadius: 40, color: Color(0x8C000000))],
    shadowSubtle: [BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x66000000))],
    readoutGlow: [Shadow(offset: Offset(0, 0), blurRadius: 10, color: Color(0x598FE7FF))],
  );

  static const light = MadarShadows(
    shadowRaised: [BoxShadow(offset: Offset(0, 18), blurRadius: 40, color: Color(0x29101820))],
    shadowSubtle: [BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1F101820))],
    readoutGlow: [Shadow(offset: Offset(0, 0), blurRadius: 10, color: Color(0x4C8FE7FF))],
  );

  @override
  MadarShadows copyWith({List<BoxShadow>? shadowRaised, List<BoxShadow>? shadowSubtle, List<Shadow>? readoutGlow}) => MadarShadows(
        shadowRaised: shadowRaised ?? this.shadowRaised,
        shadowSubtle: shadowSubtle ?? this.shadowSubtle,
        readoutGlow: readoutGlow ?? this.readoutGlow,
      );

  @override
  MadarShadows lerp(ThemeExtension<MadarShadows>? other, double t) {
    if (other is! MadarShadows) return this;
    return MadarShadows(
      shadowRaised: BoxShadow.lerpList(shadowRaised, other.shadowRaised, t) ?? shadowRaised,
      shadowSubtle: BoxShadow.lerpList(shadowSubtle, other.shadowSubtle, t) ?? shadowSubtle,
      readoutGlow: Shadow.lerpList(readoutGlow, other.readoutGlow, t) ?? readoutGlow,
    );
  }
}

/// Spacing scale on a 4dp grid (space-1 = 4).
abstract final class MadarSpace {
  /// Base unit. Icon-to-label inside pills.
  static const double s1 = 4;
  /// Chip gaps, icon-text gaps.
  static const double s2 = 8;
  /// Card side margin on phone, row inner gaps.
  static const double s3 = 12;
  /// Phone gutter, card padding.
  static const double s4 = 16;
  /// Sheet padding, panel padding.
  static const double s5 = 20;
  /// Admin content padding, section breaks.
  static const double s6 = 24;
  /// Empty-state padding.
  static const double s8 = 32;
  /// Minimum touch target.
  static const double s12 = 48;
}

/// Corner radii. Use with BorderRadius.circular(MadarRadii.xl).
abstract final class MadarRadii {
  /// Polarization cell, source chips.
  static const double xs = 5;
  /// Frequency readout, badges, stage chips.
  static const double sm = 7;
  /// Inputs, small buttons, logo tiles, segments.
  static const double md = 10;
  /// Buttons, search field, commentator row, date cells.
  static const double lg = 14;
  /// Cards and list groups, admin boxes.
  static const double xl = 18;
  /// Bottom sheet top corners, dialogs.
  static const double xxl = 26;
  /// Chips, status pills, nav indicator, avatars.
  static const double pill = 999;
}

/// Layout constants for the phone, desktop web and admin shells.
abstract final class MadarLayout {
  /// Design baseline; check at 412px and font scale 1.3.
  static const double phoneWidth = 360;
  /// Minimum hit area for any control.
  static const double touchMin = 48;
  /// Bottom navigation bar, above the system gesture area.
  static const double bottomNavHeight = 66;
  /// Android AdMob banner slot above the bottom nav; reserved only after an ad loads.
  static const double adSlotHeight = 58;
  /// Desktop navigation rail (right side, RTL).
  static const double navRailWidth = 92;
  /// Desktop list pane beside the detail pane.
  static const double listPaneWidth = 420;
  /// Admin sidebar (right side, RTL).
  static const double adminSidebarWidth = 248;
}

/// Font families. Bundle the TTFs from design-system/fonts and declare them in pubspec.yaml under these names.
abstract final class MadarFonts {
  static const String display = 'Changa';
  static const String sans = 'IBM Plex Sans Arabic';
  static const String mono = 'IBM Plex Mono';
}

/// Text styles from the type scale. Colour is not set: apply a MadarColors token with copyWith(color: ...).
abstract final class MadarText {
  // Display
  /// Match hero score. Tabular figures; each number sits beside its own team.
  static const TextStyle score = TextStyle(fontFamily: MadarFonts.display, fontSize: 46, height: 1, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  /// Kickoff time in the match hero before the match.
  static const TextStyle kickoff = TextStyle(fontFamily: MadarFonts.display, fontSize: 34, height: 1, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Screen and page titles (24–28px).
  static const TextStyle heading1 = TextStyle(fontFamily: MadarFonts.display, fontSize: 28, height: 1.2, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  /// Section headers, sheet titles, team names in the hero (15–18px).
  static const TextStyle heading2 = TextStyle(fontFamily: MadarFonts.display, fontSize: 18, height: 1.3, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Kickoff time in a match row; ص/م follows in text-caption.
  static const TextStyle rowTime = TextStyle(fontFamily: MadarFonts.display, fontSize: 19, height: 1, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Live or final score in a match row.
  static const TextStyle rowScore = TextStyle(fontFamily: MadarFonts.display, fontSize: 22, height: 1, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]);
  // Text
  /// Body copy and descriptions.
  static const TextStyle textBody = TextStyle(fontFamily: MadarFonts.sans, fontSize: 14, height: 1.6, fontWeight: FontWeight.w400);
  /// Channel names, list titles.
  static const TextStyle textStrong = TextStyle(fontFamily: MadarFonts.sans, fontSize: 14, height: 1.45, fontWeight: FontWeight.w600);
  /// Team names in rows (two lines allowed), chips, buttons-small.
  static const TextStyle textLabel = TextStyle(fontFamily: MadarFonts.sans, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500);
  /// Metadata, hints, stale hints.
  static const TextStyle textCaption = TextStyle(fontFamily: MadarFonts.sans, fontSize: 12, height: 1.4, fontWeight: FontWeight.w400);
  /// Badges, pills, nav labels, counts. Minimum size.
  static const TextStyle textMicro = TextStyle(fontFamily: MadarFonts.sans, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600);
  // Data
  /// Frequency readout in rows. Always LTR, tabular.
  static const TextStyle readout = TextStyle(fontFamily: MadarFonts.mono, fontSize: 13, height: 1, fontWeight: FontWeight.w600, letterSpacing: 0.26, fontFeatures: [FontFeature.tabularFigures()]);
  /// Channel sheet and satellite header readouts.
  static const TextStyle readoutLg = TextStyle(fontFamily: MadarFonts.mono, fontSize: 19, height: 1, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Desktop channel pane, satellite finder values.
  static const TextStyle readoutXl = TextStyle(fontFamily: MadarFonts.mono, fontSize: 26, height: 1, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
  /// Admin logs, field diffs, source IDs.
  static const TextStyle monoCode = TextStyle(fontFamily: MadarFonts.mono, fontSize: 12.5, height: 1.75, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]);
}

/// A ThemeData wired to the tokens. Components should read MadarColors / MadarText directly;
/// the Material colour scheme is mapped only so stock widgets look right.
ThemeData buildMadarTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? MadarColors.dark : MadarColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: c.accentContainer,
    secondary: c.accentText,
    surface: c.surface1,
    onSurface: c.textPrimary,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerHighest: c.surface3,
    outline: c.dividerStrong,
    outlineVariant: c.divider,
    error: c.error,
    errorContainer: c.errorContainer,
    scrim: c.overlay,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: MadarFonts.sans,
    dividerColor: c.divider,
    focusColor: c.focusRing,
    extensions: <ThemeExtension<dynamic>>[c, dark ? MadarShadows.dark : MadarShadows.light],
  );
}

extension MadarThemeContext on BuildContext {
  MadarColors get madarColors => Theme.of(this).extension<MadarColors>()!;
  MadarShadows get madarShadows => Theme.of(this).extension<MadarShadows>()!;
}
