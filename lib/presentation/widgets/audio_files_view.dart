import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/enum/audio_format.dart';
import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/entities/metadata_update_request.dart';
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
    required this.loadMetadata,
    required this.pendingRenames,
    required this.pendingMetadataUpdates,
    required this.onSwap,
    this.onRename,
    this.onSyncFromName,
    this.onFileSelected,
    this.error,
    this.onRetry,
  });

  final String? folderName;
  final AudioStatus status;
  final List<AudioFileEntity> files;
  final Future<Uint8List?> Function(String path) loadCoverArt;
  final Future<AudioMetadataEntity?> Function(String path) loadMetadata;
  final Map<String, String> pendingRenames;
  final Map<String, MetadataUpdateRequest> pendingMetadataUpdates;
  final void Function(String path) onSwap;
  final void Function(String path, String newName)? onRename;
  final void Function(String path)? onSyncFromName;
  final void Function(String path)? onFileSelected;
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
            final isPendingSync =
                widget.pendingMetadataUpdates.containsKey(file.path);
            return GestureDetector(
              onSecondaryTapDown: (details) {
                _showContextMenu(
                  context,
                  details,
                  file.path,
                  nameWithoutExtension(file.path),
                );
              },
              child: ListTile(
                dense: true,
                onTap: widget.onFileSelected == null
                    ? null
                    : () => widget.onFileSelected!(file.path),
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
                    _SyncBadge(
                      filePath: file.path,
                      loadMetadata: widget.loadMetadata,
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
                      if (widget.onSyncFromName != null && hasSingleDash)
                        IconButton(
                          onPressed: widget.onSyncFromName == null
                              ? null
                              : () => widget.onSyncFromName!(file.path),
                          icon: const Icon(Icons.sync, size: 18),
                          tooltip: isPendingSync
                              ? 'Undo metadata update'
                              : 'Update metadata from file name',
                          color: isPendingSync
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
              ),
            );
          },
        );
    }
  }

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    String path,
    String currentName,
  ) {
    if (widget.onRename == null) return;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 12),
              Text('Rename'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename' && context.mounted) {
        _showRenameDialog(context, path, currentName);
      }
    });
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String path,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final extension = extensionFromPath(path);
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'File name',
            suffixText: extension.isEmpty ? null : '.$extension',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (submitted == null || !context.mounted) return;
    final newName = submitted.trim();
    if (newName.isEmpty || newName == currentName) return;
    widget.onRename!(path, newName);
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
  bool _loaded = false;

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
      _loaded = true;
    });
  }

  Widget _placeholder(BuildContext context, {bool showNote = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: showNote
          ? Icon(Icons.music_note, size: 20, color: colorScheme.onSurfaceVariant)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          cacheWidth: 72,
          cacheHeight: 72,
          errorBuilder: (context, error, stackTrace) =>
              _placeholder(context, showNote: true),
        ),
      );
    }
    // While loading: plain gray box. Once confirmed there is no cover art,
    // show the music note.
    return _placeholder(context, showNote: _loaded);
  }
}

/// Shows whether the file's metadata title and artist match the
/// "Title - Artist" file name. Loads metadata lazily.
class _SyncBadge extends StatefulWidget {
  const _SyncBadge({
    required this.filePath,
    required this.loadMetadata,
  });

  final String filePath;
  final Future<AudioMetadataEntity?> Function(String path) loadMetadata;

  @override
  State<_SyncBadge> createState() => _SyncBadgeState();
}

enum _SyncState { pending, synced, mismatch, noPattern }

class _SyncBadgeState extends State<_SyncBadge> {
  _SyncState _state = _SyncState.pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AudioMetadataEntity? metadata;
    try {
      metadata = await widget.loadMetadata(widget.filePath);
    } catch (_) {
      metadata = null;
    }
    if (!mounted) return;
    setState(() {
      _state = _computeSync(widget.filePath, metadata);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_state) {
      case _SyncState.pending:
        return Icon(
          Icons.circle,
          size: 16,
          color: colorScheme.outlineVariant,
        );
      case _SyncState.synced:
        return Tooltip(
          message: 'Title and artist match the file name',
          child: Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green.shade600,
          ),
        );
      case _SyncState.mismatch:
        return Tooltip(
          message: 'Title or artist does not match the file name',
          child: Icon(
            Icons.error_outline,
            size: 16,
            color: colorScheme.error,
          ),
        );
      case _SyncState.noPattern:
        return Tooltip(
          message: 'File name does not follow "Title - Artist"',
          child: Icon(
            Icons.help_outline,
            size: 16,
            color: colorScheme.outline,
          ),
        );
    }
  }
}

_SyncState _computeSync(
  String filePath,
  AudioMetadataEntity? metadata,
) {
  final parts = splitTitleArtist(filePath);
  if (parts == null || metadata == null) {
    return _SyncState.noPattern;
  }
  final title = metadata.title?.trim().toLowerCase();
  final artist = metadata.artist?.trim().toLowerCase();
  if (title == null || artist == null) {
    return _SyncState.mismatch;
  }
  if (title == parts.title.toLowerCase() &&
      artist == parts.artist.toLowerCase()) {
    return _SyncState.synced;
  }
  return _SyncState.mismatch;
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