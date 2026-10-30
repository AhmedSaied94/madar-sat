import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/clip_controller.dart';
import '../../core/network/generated/models/commentator_ref.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'badges.dart';
import 'logo.dart';

/// The commentator for a broadcast, with an optional short voice sample (CommentatorRow
/// README). It reads the app's one shared player, so starting this clip stops any other,
/// and playback only starts from the tap.
///
/// [sampleUrl] defaults to the commentator's own `audio`; with neither, the row shows the
/// name only.
class CommentatorRow extends ConsumerWidget {
  const CommentatorRow({super.key, required this.commentator, this.sampleUrl});

  final CommentatorRef commentator;
  final String? sampleUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = sampleUrl ?? commentator.audio;
    // This row's own phase and progress only: the progress ticks about every 200 ms, and a
    // row that does not hold the clip has nothing to redraw.
    final (phase, progress) = ref.watch(
      clipControllerProvider.select((clip) {
        final phase = url == null ? ClipPhase.idle : clip.phaseOf(url);
        return (phase, phase == ClipPhase.playing ? clip.progress : 0.0);
      }),
    );
    return CommentatorRowView(
      name: commentator.name,
      hasSample: url != null,
      avatar: commentator.image == null ? null : CachedNetworkImageProvider(commentator.image!),
      phase: phase,
      progress: progress,
      onTap: url == null ? null : () => ref.read(clipControllerProvider.notifier).toggle(url),
    );
  }
}

/// The row drawn for a given [phase]; [CommentatorRow] feeds it from the shared player and
/// the goldens draw each state directly.
class CommentatorRowView extends StatelessWidget {
  const CommentatorRowView({
    super.key,
    required this.name,
    this.phase = ClipPhase.idle,
    this.progress = 0,
    this.hasSample = true,
    this.avatar,
    this.onTap,
  });

  final String name;

  /// The commentator's photo; the neutral tile with a person glyph when null.
  final ImageProvider? avatar;
  final ClipPhase phase;

  /// 0…1, drawn under the name while playing.
  final double progress;

  /// False draws the name only, with no play button.
  final bool hasSample;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final stateText = switch (phase) {
      ClipPhase.idle => null,
      ClipPhase.loading => l.commentatorLoading,
      ClipPhase.playing => l.commentatorPlaying,
      ClipPhase.error => l.commentatorError,
    };
    final label = [l.commentator, name, ?stateText].join(l.listSeparator);

    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s2,
          vertical: MadarSpace.s2,
        ),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(MadarRadii.xl),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: LogoTile(
                kind: LogoTileKind.commentator,
                logo: avatar,
                fallbackText: name,
                size: MadarSpace.s5 * 2,
              ),
            ),
            const SizedBox(width: MadarSpace.s3),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: MadarText.textMicro.fontSize,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: MadarSpace.s1),
                        Text(
                          l.commentator,
                          style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                    EntityName(name),
                    if (stateText != null)
                      Row(
                        children: [
                          if (phase == ClipPhase.playing) ...[
                            const _Equalizer(),
                            const SizedBox(width: MadarSpace.s1),
                          ],
                          Flexible(
                            child: Text(
                              stateText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MadarText.textMicro.copyWith(
                                color: phase == ClipPhase.error ? colors.error : colors.accentText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (phase == ClipPhase.playing) ...[
                      const SizedBox(height: MadarSpace.s1),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(MadarRadii.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: _hair,
                          backgroundColor: colors.dividerStrong,
                          color: colors.accentText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasSample) ...[
              const SizedBox(width: MadarSpace.s2),
              _PlayButton(phase: phase, name: name, onTap: onTap),
            ],
          ],
        ),
      ),
    );
  }
}

/// The thin rule widths of this row (a progress bar, a spinner ring, an equalizer gap): the
/// scale has no step below `s1`.
const double _hair = MadarSpace.s1 / 2;

/// A 40 dp control inside a 48 dp target (CommentatorRow README).
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.phase, required this.name, required this.onTap});

  final ClipPhase phase;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const side = MadarSpace.s5 * 2;

    final (Color? background, Widget glyph, String tooltip) = switch (phase) {
      ClipPhase.idle => (
          colors.textPrimary,
          Icon(Icons.play_arrow, color: colors.textOnInverse),
          l.commentatorPlay(name),
        ),
      ClipPhase.loading => (
          null,
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  // A fixed arc when the OS asks for reduced motion; a spinner otherwise.
                  value: reduced ? 0.25 : null,
                  strokeWidth: _hair,
                  color: colors.accentText,
                  backgroundColor: colors.dividerStrong,
                ),
              ),
              Icon(Icons.play_arrow, color: colors.textSecondary),
            ],
          ),
          l.commentatorLoading,
        ),
      ClipPhase.playing => (
          colors.accent,
          Icon(Icons.pause, color: colors.onAccent),
          l.commentatorPause,
        ),
      ClipPhase.error => (
          colors.errorContainer,
          Icon(Icons.refresh, color: colors.error),
          l.retry,
        ),
    };

    return IconButton(
      onPressed: phase == ClipPhase.loading ? null : onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(
        minWidth: MadarLayout.touchMin,
        minHeight: MadarLayout.touchMin,
      ),
      padding: EdgeInsets.zero,
      icon: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: glyph,
      ),
    );
  }
}

/// Four bars that move while a clip plays; still when the OS asks for reduced motion.
class _Equalizer extends StatefulWidget {
  const _Equalizer();

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with SingleTickerProviderStateMixin {
  static const List<double> _rest = [0.5, 1, 0.7, 0.9];
  static const double _barWidth = _hair + _hair / 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.madarColors.accentText;
    return SizedBox(
      height: MadarText.textMicro.fontSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _rest.length; i++) ...[
              if (i > 0) const SizedBox(width: _hair),
              FractionallySizedBox(
                heightFactor: _controller.isAnimating
                    ? _rest[i] + (1 - _rest[i]) * (i.isEven ? _controller.value : 1 - _controller.value)
                    : _rest[i],
                child: Container(
                  width: _barWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(MadarRadii.xs),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
