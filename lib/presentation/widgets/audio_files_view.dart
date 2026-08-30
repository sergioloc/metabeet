import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/enum/audio_format.dart';
import '../../domain/entities/audio_file_entity.dart';
import '../../util/app_colors.dart';
import '../../util/path_utils.dart';
import '../bloc/home_bloc.dart';

/// Right panel: shows the audio files of the selected folder, with search.
class AudioFilesView extends StatefulWidget {
  const AudioFilesView({
    super.key,
    required this.folderName,
    required this.status,
    required this.files,
    required this.loadCoverArt,
    required this.pendingRenames,
    required this.onSwap,
    this.error,
    this.onRetry,
  });

  final String? folderName;
  final AudioStatus status;
  final List<AudioFileEntity> files;
  final Future<Uint8List?> Function(String path) loadCoverArt;
  final Map<String, String> pendingRenames;
  final void Function(String path) onSwap;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<AudioFilesView> createState() => _AudioFilesViewState();
}

class _AudioFilesViewState extends State<AudioFilesView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void didUpdateWidget(AudioFilesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderName != widget.folderName) {
      _searchController.clear();
      _query = '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AudioFileEntity> get _displayFiles {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.files;
    return widget.files.where((file) {
      return nameWithoutExtension(file.path).toLowerCase().contains(q) ||
          extensionFromPath(file.path).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayFiles = _displayFiles;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.library_music_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Songs',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.folderName ?? '',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.status == AudioStatus.ready) ...[
                  const SizedBox(width: 8),
                  Text(
                    _fileCountLabel(displayFiles.length),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.status == AudioStatus.ready)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _buildContent(context, displayFiles)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<AudioFileEntity> files) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (widget.status) {
      case AudioStatus.loading || AudioStatus.idle:
        return const Center(child: CircularProgressIndicator());
      case AudioStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Could not load the audio files',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall,
                ),
                if (widget.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case AudioStatus.ready:
        if (widget.files.isEmpty) {
          return Center(
            child: Text(
              'No audio files in this folder',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        if (files.isEmpty) {
          return Center(
            child: Text(
              'No results found',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: files.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
itemBuilder: (context, index) {
            final file = files[index];
            final displayName =
                nameWithoutExtension(widget.pendingRenames[file.path] ?? file.path);
            final hasSingleDash = displayName.split('-').length - 1 == 1;
            final isPendingSwap = widget.pendingRenames.containsKey(file.path);
            return ListTile(
              dense: true,
              leading: _TrackArtwork(
                path: file.path,
                loadCoverArt: widget.loadCoverArt,
              ),
              title: Row(
                children: [
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 20,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _chipColor(file.format).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _chipColor(file.format).withValues(
                            alpha: 0.35,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        extensionFromPath(file.path),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: textTheme.labelSmall?.copyWith(
                          color: _extensionTextColor(context, file.format),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isPendingSwap
                          ? TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                          : null,
                    ),
                  ),
                  if (hasSingleDash)
                    IconButton(
                      onPressed: () => widget.onSwap(file.path),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      tooltip: isPendingSwap ? 'Undo' : 'Swap',
                      color: isPendingSwap
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 24,
                      ),
                    ),
                ],
              ),
            );
          },
        );
    }
  }

  String _fileCountLabel(int count) =>
      count == 1 ? '1 file' : '$count files';
}

/// Shows the track's embedded cover art, or a music icon as fallback.
class _TrackArtwork extends StatefulWidget {
  const _TrackArtwork({required this.path, required this.loadCoverArt});

  final String path;
  final Future<Uint8List?> Function(String path) loadCoverArt;

  @override
  State<_TrackArtwork> createState() => _TrackArtworkState();
}

class _TrackArtworkState extends State<_TrackArtwork> {
  static const double _size = 36;

  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Uint8List? bytes;
    try {
      bytes = await widget.loadCoverArt(widget.path);
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant),
    );

    if (_loading) {
      return const SizedBox(
        width: _size,
        height: _size,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(
        bytes,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        cacheWidth: 72,
        cacheHeight: 72,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

MaterialColor _extensionColor(AudioFormat format) {
  switch (format) {
    case AudioFormat.mp3:
      return AppColors.mp3;
    case AudioFormat.flac:
      return AppColors.flac;
    case AudioFormat.wav:
      return AppColors.wav;
    case AudioFormat.ogg:
      return AppColors.ogg;
    case AudioFormat.aac:
      return AppColors.aac;
    case AudioFormat.m4a:
      return AppColors.m4a;
    case AudioFormat.wma:
      return AppColors.wma;
    case AudioFormat.aiff:
      return AppColors.aiff;
  }
}

Color _chipColor(AudioFormat format) {
  final hsl = HSLColor.fromColor(_extensionColor(format).shade600);
  return hsl.withSaturation(hsl.saturation * 0.35).toColor();
}

Color _extensionTextColor(BuildContext context, AudioFormat format) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Color.lerp(
    _chipColor(format),
    scheme.onSurface,
    isDark ? 0.25 : 0.45,
  )!;
}