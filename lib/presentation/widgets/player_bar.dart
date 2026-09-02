import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/player/player_bloc.dart';

/// Full-width bottom panel with playback controls for the current track.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<PlayerBloc, PlayerState>(
      buildWhen: (prev, next) =>
          prev.hasSong != next.hasSong ||
          prev.title != next.title ||
          prev.artist != next.artist ||
          prev.coverArt != next.coverArt ||
          prev.isPlaying != next.isPlaying ||
          prev.position != next.position ||
          prev.duration != next.duration,
      builder: (context, state) {
        if (!state.hasSong) {
          return const SizedBox.shrink();
        }

        final duration = state.duration ?? Duration.zero;
        final position = state.position > duration ? duration : state.position;
        final sliderValue = duration.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds
                .toDouble()
                .clamp(0.0, duration.inMilliseconds.toDouble());

        return Material(
          color: colorScheme.surfaceContainerHigh,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timeline slider.
                  Row(
                    children: [
                      _TimeLabel(text: _format(position)),
                      Expanded(
                        child: _SeekSlider(
                          value: sliderValue,
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1.0,
                          onSeek: (milliseconds) => context
                              .read<PlayerBloc>()
                              .add(SeekRequested(
                                  Duration(milliseconds: milliseconds))),
                        ),
                      ),
                      _TimeLabel(text: _format(duration)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Track info + transport controls.
                  Row(
                    children: [
                      _MiniCover(bytes: state.coverArt),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.title ?? _nameFromPath(state.currentPath!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (state.artist != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                state.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => context
                            .read<PlayerBloc>()
                            .add(const TogglePlayPause()),
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 30,
                        ),
                        tooltip: state.isPlaying ? 'Pause' : 'Play',
                        color: colorScheme.onSurface,
                      ),
                      IconButton(
                        onPressed: () => context
                            .read<PlayerBloc>()
                            .add(const StopRequested()),
                        icon: const Icon(Icons.stop_rounded, size: 24),
                        tooltip: 'Stop',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _nameFromPath(String path) {
    final slash =
        path.contains('\\') ? path.lastIndexOf('\\') : path.lastIndexOf('/');
    final name = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _format(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              cacheWidth: 80,
              cacheHeight: 80,
              errorBuilder: (context, error, stackTrace) =>
                  _fallbackIcon(colorScheme),
            )
          : _fallbackIcon(colorScheme),
    );
  }

  Widget _fallbackIcon(ColorScheme colorScheme) {
    return Icon(
      Icons.music_note_rounded,
      size: 22,
      color: colorScheme.onSurfaceVariant,
    );
  }
}

/// A seekable timeline slider. While the user drags the thumb it holds the
/// local position so the track keeps updating, and only seeks on release.
class _SeekSlider extends StatefulWidget {
  const _SeekSlider({
    required this.value,
    required this.max,
    required this.onSeek,
  });

  final double value;
  final double max;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
      child: Slider(
        value: _dragValue ?? widget.value.clamp(0.0, widget.max),
        max: widget.max,
        onChanged: (value) => setState(() => _dragValue = value),
        onChangeEnd: (value) {
          setState(() => _dragValue = null);
          widget.onSeek(value.round());
        },
      ),
    );
  }
}
