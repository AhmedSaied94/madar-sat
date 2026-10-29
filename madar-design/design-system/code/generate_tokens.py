"""Regenerate tokens.css, code/flutter/madar_tokens.dart and code/react/tokens.ts from tokens.json.

Usage (from anywhere):  python3 design-system/code/generate_tokens.py
Optional:               python3 generate_tokens.py <path/to/tokens.json> <design-system output dir>
Edit tokens.json, never the generated files.
"""
import json, re, sys, os

_here = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_here, '..', 'tokens.json')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_here, '..')
T = json.load(open(SRC, encoding='utf-8'))
themes = [t['id'] for t in T['color']['themes']]
first = themes[0]
HDR = 'GENERATED from design-system/tokens.json (Madar Design System). Do not edit by hand: change tokens.json and regenerate.'

def camel(name):
    parts = re.split(r'[-_.]', name)
    s = parts[0] + ''.join(p[:1].upper() + p[1:] for p in parts[1:])
    if s[0].isdigit():
        s = 'v' + s
    return s

def per_theme(v, th):
    if isinstance(v, str):
        return v
    return v.get(th, v.get(first))

# ---------- CSS ----------
css = [f'/* {HDR} */', '']
for th in themes:
    sel = f':root, [data-theme="{th}"]' if th == first else f'[data-theme="{th}"]'
    decl = []
    for t in T['color']['tokens']:
        val = per_theme(t['value'], th)
        if th != first and val == per_theme(t['value'], first):
            continue
        decl.append(f'  --{t["name"]}: {val.lower() if val.startswith("#") else val};')
    for t in T.get('shadow', {}).get('tokens', []):
        val = per_theme(t['value'], th)
        if th != first and val == per_theme(t['value'], first):
            continue
        decl.append(f'  --{t["name"]}: {val};')
    css += [sel + ' {', f'  color-scheme: {th};'] + decl + ['}', '']
root = []
for fam in ('spacing', 'radius', 'layout'):
    for t in T.get(fam, {}).get('tokens', []):
        root.append(f'  --{t["name"]}: {t["value"]};')
for k, stack in T['type']['families'].items():
    root.append(f'  --font-{k}: {stack};')
css += [':root {'] + root + ['}', '']
def px(v):
    return v if isinstance(v, str) else f'{v}px'
for g in T['type']['groups']:
    for s in g['styles']:
        fam = s.get('family', g['family'])
        rules = [f'font-family: var(--font-{fam})', f'font-size: {px(s["fontSize"])}', f'line-height: {s["lineHeight"]}', f'font-weight: {s["fontWeight"]}']
        if 'letterSpacing' in s:
            rules.append(f'letter-spacing: {s["letterSpacing"]}')
        if g['name'] in ('Display', 'Data'):
            rules.append('font-variant-numeric: tabular-nums lining-nums')
        css.append(f'.{s["name"]} {{ ' + '; '.join(rules) + '; }' + f'  /* {s.get("usage","")} */')
open(os.path.join(OUT, 'tokens.css'), 'w', encoding='utf-8').write('\n'.join(css) + '\n')

# ---------- Dart ----------
def dart_color(v):
    v = v.strip()
    m = re.fullmatch(r'#([0-9a-fA-F]{6})', v)
    if m:
        return f'Color(0xFF{m.group(1).upper()})'
    m = re.fullmatch(r'rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)', v)
    if m:
        r, g, b = (int(m.group(i)) for i in (1, 2, 3))
        a = round(float(m.group(4) or 1) * 255)
        return f'Color(0x{a:02X}{r:02X}{g:02X}{b:02X})'
    raise ValueError(v)

def parse_shadow(v):
    # "0 18px 40px rgba(0,0,0,0.55)" -> (dx, dy, blur, color)
    m = re.fullmatch(r'\s*(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?\s+(rgba?\([^)]*\)|#[0-9a-fA-F]{6})\s*', v)
    if not m:
        raise ValueError(v)
    return float(m.group(1)), float(m.group(2)), float(m.group(3)), dart_color(m.group(4))

def num(v):
    if isinstance(v, (int, float)):
        f = float(v)
    else:
        f = float(re.sub(r'px$', '', v))
    return ('%g' % f) if f != int(f) else f'{int(f)}'

ctoks = T['color']['tokens']
fields = [(camel(t['name']), t) for t in ctoks]
d = [f'// {HDR}', '//', '// Usage:', '//   MaterialApp(theme: buildMadarTheme(Brightness.light), darkTheme: buildMadarTheme(Brightness.dark), themeMode: ThemeMode.dark)',
     '//   final c = context.madarColors;  Container(color: c.surface1)', '//   Text(\'8:00\', style: MadarText.rowTime.copyWith(color: c.textPrimary))', '',
     "import 'package:flutter/material.dart';", '']
d += ['/// Colour tokens. One field per token in tokens.json, with the same meaning (see `usage`).', '@immutable',
      'class MadarColors extends ThemeExtension<MadarColors> {', '  const MadarColors({']
d += [f'    required this.{f},' for f, _ in fields]
d += ['  });', '']
for f, t in fields:
    d.append(f'  /// {t["usage"]}')
    d.append(f'  final Color {f};')
d.append('')
for th in themes:
    d.append(f'  static const {th} = MadarColors(')
    for f, t in fields:
        d.append(f'    {f}: {dart_color(per_theme(t["value"], th))},')
    d.append('  );')
    d.append('')
d.append('  @override')
d.append('  MadarColors copyWith({' + ', '.join(f'Color? {f}' for f, _ in fields) + '}) => MadarColors(')
d += [f'        {f}: {f} ?? this.{f},' for f, _ in fields]
d += ['      );', '', '  @override', '  MadarColors lerp(ThemeExtension<MadarColors>? other, double t) {', '    if (other is! MadarColors) return this;', '    return MadarColors(']
d += [f'      {f}: Color.lerp({f}, other.{f}, t)!,' for f, _ in fields]
d += ['    );', '  }', '}', '']

# shadows
sh = T.get('shadow', {}).get('tokens', [])
d += ['/// Elevation and glow tokens. `readoutGlow` is a text shadow for FrequencyReadout digits only.', '@immutable', 'class MadarShadows extends ThemeExtension<MadarShadows> {',
      '  const MadarShadows({' + ', '.join(f'required this.{camel(t["name"])}' for t in sh) + '});', '']
def is_text(t):
    return 'glow' in t['name']
for t in sh:
    typ = 'List<Shadow>' if is_text(t) else 'List<BoxShadow>'
    d.append(f'  /// {t["usage"]}')
    d.append(f'  final {typ} {camel(t["name"])};')
d.append('')
for th in themes:
    d.append(f'  static const {th} = MadarShadows(')
    for t in sh:
        dx, dy, blur, col = parse_shadow(per_theme(t['value'], th))
        if is_text(t):
            d.append(f'    {camel(t["name"])}: [Shadow(offset: Offset({num(dx)}, {num(dy)}), blurRadius: {num(blur)}, color: {col})],')
        else:
            d.append(f'    {camel(t["name"])}: [BoxShadow(offset: Offset({num(dx)}, {num(dy)}), blurRadius: {num(blur)}, color: {col})],')
    d.append('  );')
    d.append('')
d.append('  @override')
d.append('  MadarShadows copyWith({' + ', '.join(f'{"List<Shadow>" if is_text(t) else "List<BoxShadow>"}? {camel(t["name"])}' for t in sh) + '}) => MadarShadows(')
d += [f'        {camel(t["name"])}: {camel(t["name"])} ?? this.{camel(t["name"])},' for t in sh]
d += ['      );', '', '  @override', '  MadarShadows lerp(ThemeExtension<MadarShadows>? other, double t) {', '    if (other is! MadarShadows) return this;', '    return MadarShadows(']
for t in sh:
    n = camel(t['name'])
    fn = 'Shadow.lerpList' if is_text(t) else 'BoxShadow.lerpList'
    d.append(f'      {n}: {fn}({n}, other.{n}, t) ?? {n},')
d += ['    );', '  }', '}', '']

def const_class(cls, fam, doc, strip):
    out = [f'/// {doc}', f'abstract final class {cls} {{']
    for t in T.get(fam, {}).get('tokens', []):
        n = t['name']
        for p in strip:
            if n.startswith(p):
                n = n[len(p):]
        out.append(f'  /// {t["usage"]}')
        if n[0].isdigit():
            ident = ('x' * (int(n[0]) - 1) + n[1:]) if fam == 'radius' else 's' + n.replace('-', '_')
        else:
            ident = camel(n)
        out.append(f'  static const double {ident} = {num(t["value"])};')
    out.append('}')
    return out
d += const_class('MadarSpace', 'spacing', 'Spacing scale on a 4dp grid (space-1 = 4).', ['space-'])
d.append('')
d += const_class('MadarRadii', 'radius', 'Corner radii. Use with BorderRadius.circular(MadarRadii.xl).', ['radius-'])
d.append('')
d += const_class('MadarLayout', 'layout', 'Layout constants for the phone, desktop web and admin shells.', [])
d.append('')

fams = T['type']['families']
famname = {k: v.split(',')[0].strip().strip('"') for k, v in fams.items()}
d += ['/// Font families. Bundle the TTFs from design-system/fonts and declare them in pubspec.yaml under these names.', 'abstract final class MadarFonts {']
for k, n in famname.items():
    d.append(f"  static const String {camel(k)} = '{n}';")
d += ['}', '']
wmap = {100: 'w100', 200: 'w200', 300: 'w300', 400: 'w400', 500: 'w500', 600: 'w600', 700: 'w700', 800: 'w800', 900: 'w900'}
d += ['/// Text styles from the type scale. Colour is not set: apply a MadarColors token with copyWith(color: ...).', 'abstract final class MadarText {']
for g in T['type']['groups']:
    d.append(f'  // {g["name"]}')
    for s in g['styles']:
        fam = s.get('family', g['family'])
        fs = float(num(s['fontSize']))
        lh = s['lineHeight']
        parts = [f'fontFamily: MadarFonts.{camel(fam)}', f'fontSize: {num(s["fontSize"])}', f'height: {lh}', f'fontWeight: FontWeight.{wmap[int(s["fontWeight"])]}']
        if 'letterSpacing' in s:
            ls = s['letterSpacing']
            if isinstance(ls, str) and ls.endswith('em'):
                parts.append(f'letterSpacing: {round(float(ls[:-2]) * fs, 2)}')
            else:
                parts.append(f'letterSpacing: {num(ls)}')
        if g['name'] in ('Display', 'Data'):
            parts.append('fontFeatures: [FontFeature.tabularFigures()]')
        d.append(f'  /// {s.get("usage", "")}')
        d.append(f'  static const TextStyle {camel(s["name"])} = TextStyle({", ".join(parts)});')
d += ['}', '']

c = {f: f for f, _ in fields}
d += ['/// A ThemeData wired to the tokens. Components should read MadarColors / MadarText directly;',
      '/// the Material colour scheme is mapped only so stock widgets look right.',
      'ThemeData buildMadarTheme(Brightness brightness) {',
      '  final dark = brightness == Brightness.dark;',
      '  final c = dark ? MadarColors.dark : MadarColors.light;',
      '  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(',
      '    primary: c.accent,',
      '    onPrimary: c.onAccent,',
      '    primaryContainer: c.accentContainer,',
      '    secondary: c.accentText,',
      '    surface: c.surface1,',
      '    onSurface: c.textPrimary,',
      '    onSurfaceVariant: c.textSecondary,',
      '    surfaceContainerHighest: c.surface3,',
      '    outline: c.dividerStrong,',
      '    outlineVariant: c.divider,',
      '    error: c.error,',
      '    errorContainer: c.errorContainer,',
      '    scrim: c.overlay,',
      '  );',
      '  return ThemeData(',
      '    useMaterial3: true,',
      '    brightness: brightness,',
      '    colorScheme: scheme,',
      '    scaffoldBackgroundColor: c.bg,',
      '    fontFamily: MadarFonts.sans,',
      '    dividerColor: c.divider,',
      '    focusColor: c.focusRing,',
      '    extensions: <ThemeExtension<dynamic>>[c, dark ? MadarShadows.dark : MadarShadows.light],',
      '  );',
      '}', '',
      'extension MadarThemeContext on BuildContext {',
      '  MadarColors get madarColors => Theme.of(this).extension<MadarColors>()!;',
      '  MadarShadows get madarShadows => Theme.of(this).extension<MadarShadows>()!;',
      '}', '']
os.makedirs(os.path.join(OUT, 'code', 'flutter'), exist_ok=True)
open(os.path.join(OUT, 'code', 'flutter', 'madar_tokens.dart'), 'w', encoding='utf-8').write('\n'.join(d))

# ---------- TS ----------
ts = [f'// {HDR}', '// The admin uses CSS custom properties (tokens.css). This module gives typed names and raw values', '// for places that need them in JS (charts, canvas, inline styles).', '']
ts.append('export const themes = ' + json.dumps(themes) + ' as const;')
ts.append('export type ThemeId = (typeof themes)[number];')
ts.append('')
ts.append('export const colors = {')
for th in themes:
    ts.append(f'  {th}: {{')
    for t in ctoks:
        ts.append(f'    {json.dumps(t["name"])}: {json.dumps(per_theme(t["value"], th))},')
    ts.append('  },')
ts.append('} as const;')
ts.append('export type ColorToken = keyof (typeof colors)["dark"];')
ts.append('')
for fam in ('spacing', 'radius', 'layout'):
    ts.append(f'export const {fam} = {{')
    for t in T[fam]['tokens']:
        ts.append(f'  {json.dumps(t["name"])}: {json.dumps(t["value"])},')
    ts.append('} as const;')
ts.append('')
ts.append('export const shadows = {')
for th in themes:
    ts.append(f'  {th}: {{' + ', '.join(f'{json.dumps(t["name"])}: {json.dumps(per_theme(t["value"], th))}' for t in sh) + '},')
ts.append('} as const;')
ts.append('')
ts.append('export const fontFamilies = ' + json.dumps(fams, ensure_ascii=False, indent=2) + ' as const;')
ts.append('')
ts.append('export const textStyles = {')
for g in T['type']['groups']:
    for s in g['styles']:
        o = {'fontFamily': f'var(--font-{s.get("family", g["family"])})', 'fontSize': px(s['fontSize']), 'lineHeight': s['lineHeight'], 'fontWeight': s['fontWeight']}
        if 'letterSpacing' in s:
            o['letterSpacing'] = s['letterSpacing']
        if g['name'] in ('Display', 'Data'):
            o['fontVariantNumeric'] = 'tabular-nums lining-nums'
        ts.append(f'  {json.dumps(s["name"])}: {json.dumps(o)},')
ts.append('} as const;')
ts.append('')
ts.append('/** CSS variable reference for any token: cssVar("surface-1") -> "var(--surface-1)". */')
ts.append('export const cssVar = (name: ColorToken | keyof typeof spacing | keyof typeof radius | keyof typeof layout | string) => `var(--${name})`;')
os.makedirs(os.path.join(OUT, 'code', 'react'), exist_ok=True)
open(os.path.join(OUT, 'code', 'react', 'tokens.ts'), 'w', encoding='utf-8').write('\n'.join(ts) + '\n')
print('ok', len(ctoks), 'colors')
