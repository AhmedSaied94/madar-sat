import 'package:flutter/material.dart';

import '../theme/madar_tokens.dart';

/// Wraps a Unicode LTR isolate (LRI … PDI) so a frequency or a Latin name never
/// reorders inside Arabic text (constitution III).
String isolateLtr(String text) => '\u2066$text\u2069';

/// Renders [text] as an isolated left-to-right island.
///
/// Frequencies, Latin channel and satellite names, orbital positions and source codes
/// use this; a long island truncates at its own end.
class LtrIsland extends StatelessWidget {
  const LtrIsland(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: TextAlign.start,
      ),
    );
  }
}

/// A score built from two isolated numbers, each beside its own team.
///
/// A raw `1 - 0` string never enters RTL text (constitution III). In an RTL parent the
/// home number sits on the right, next to the home team.
class ScoreParts extends StatelessWidget {
  const ScoreParts({
    super.key,
    required this.home,
    required this.away,
    required this.separator,
    this.style,
    this.separatorStyle,
  });

  final String home;
  final String away;
  final String separator;
  final TextStyle? style;
  final TextStyle? separatorStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LtrIsland(home, style: style),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s1),
          child: Text(separator, style: separatorStyle ?? style),
        ),
        LtrIsland(away, style: style),
      ],
    );
  }
}
