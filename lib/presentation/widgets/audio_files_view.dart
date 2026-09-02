import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/enum/audio_format.dart';
import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/entities/metadata_update_request.dart';
import '../../utils/app_colors.dart';
import '../../utils/path_utils.dart';
import '../bloc/home/home_bloc.dart';

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
    required this.pendingDeletes,
    required this.onSwap,
    this.onDelete,
    this.onRestore,
    this.onRename,
    this.onSyncFromName,
    this.onFileSelected,
    this.selectedFilePath,
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
  final Set<String> pendingDeletes;
  final void Function(String path) onSwap;
  final void Function(String path)? onDelete;
  final void Function(String path)? onRestore;
  final void Function(String path, String newName)? onRename;
  final void Function(String path)? onSyncFromName;
  final void Function(String path)? onFileSelected;
  final String? selectedFilePath;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<AudioFilesView> createState() => _AudioFilesViewState();
}

enum _Filter { all, mismatch, noPattern }

class _AudioFilesViewState extends State<AudioFilesView> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, _SyncState> _syncStates = {};
  String _query = '';
  _Filter _selectedFilter = _Filter.all;
  int _syncLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
    _loadSyncStates();
  }

  Future<void> _loadSyncStates() async {
    final generation = ++_syncLoadGeneration;
    final files = widget.files;
    _syncStates
      ..clear()
      ..addEntries(files.map((f) => MapEntry(f.path, _SyncState.pending)));
    if (mounted) setState(() {});

    const limit = 32;
    var index = 0;
    Future<void> worker() async {
      while (mounted && generation == _syncLoadGeneration) {
        final current = index++;
        if (current >= files.length) return;
        final file = files[current];
        AudioMetadataEntity? metadata;
        try {
          metadata = await widget.loadMetadata(file.path);
        } catch (_) {
          metadata = null;
        }
        if (!mounted || generation != _syncLoadGeneration) return;
        _syncStates[file.path] = _computeSync(file.path, metadata);
        setState(() {});
      }
    }

    await Future.wait([
      for (var i = 0; i < limit && i < files.length; i++) worker(),
    ]);
  }

  @override
  void didUpdateWidget(AudioFilesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files != widget.files) {
      _searchController.clear();
      _query = '';
      _selectedFilter = _Filter.all;
      _loadSyncStates();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AudioFileEntity> get _displayFiles {
    final q = _query.trim().toLowerCase();
    final bySearch = q.isEmpty
        ? widget.files
        : widget.files.where((file) {
            return nameWithoutExtension(file.path).toLowerCase().contains(q) ||
                extensionFromPath(file.path).toLowerCase().contains(q);
          }).toList();

    switch (_selectedFilter) {
      case _Filter.all:
        return bySearch;
      case _Filter.mismatch:
        return bySearch
            .where((f) => _syncStates[f.path] == _SyncState.mismatch)
            .toList();
      case _Filter.noPattern:
        return bySearch
            .where((f) => _syncStates[f.path] == _SyncState.noPattern)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayFiles = _displayFiles;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Songs',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
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
                  _FileCountBadge(count: _displayFiles.length),
                ],
              ],
            ),
          ),
          if (widget.status == AudioStatus.ready) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs…',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _FilterBar(
                selected: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
            ),
            const Divider(),
          ],
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
          return _EmptyListMessage(
            icon: Icons.library_music_outlined,
            message: 'No audio files in this folder',
          );
        }
        if (files.isEmpty) {
          return _EmptyListMessage(
            icon: Icons.search_off_rounded,
            message: 'No results found',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _TrackTile(
              file: file,
              isPendingDelete: widget.pendingDeletes.contains(file.path),
              isSelected: widget.selectedFilePath == file.path,
              displayName: nameWithoutExtension(
                  widget.pendingRenames[file.path] ?? file.path),
              syncState: _syncStates[file.path] ?? _SyncState.pending,
              isPendingSwap: widget.pendingRenames.containsKey(file.path),
              isPendingSync:
                  widget.pendingMetadataUpdates.containsKey(file.path),
              loadCoverArt: widget.loadCoverArt,
              onTapReplace: widget.onFileSelected == null
                  ? null
                  : () => widget.onFileSelected!(file.path),
              onSecondaryTap: (details) => _showContextMenu(
                context,
                details,
                file.path,
                nameWithoutExtension(file.path),
              ),
              onSync: widget.onSyncFromName != null &&
                      (_syncStates[file.path] == _SyncState.mismatch)
                  ? () => widget.onSyncFromName!(file.path)
                  : null,
              onSwap: () => widget.onSwap(file.path),
              onDelete: widget.onDelete == null
                  ? null
                  : () => widget.onDelete!(file.path),
              onRestore: widget.onRestore == null
                  ? null
                  : () => widget.onRestore!(file.path),
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
}

class _FileCountBadge extends StatelessWidget {
  const _FileCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = count == 1 ? '1 file' : '$count files';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Windows 11 style filter: segmented pills inside a rounded container.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _Filter.values.length; i++)
            _FilterPill(
              label: _label(_Filter.values[i]),
              selected: selected == _Filter.values[i],
              margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
              onTap: () => onSelected(_Filter.values[i]),
            ),
        ],
      ),
    );
  }

  String _label(_Filter filter) {
    switch (filter) {
      case _Filter.all:
        return 'All';
      case _Filter.mismatch:
        return 'Mismatches';
      case _Filter.noPattern:
        return 'Wrong format';
    }
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.margin,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surfaceContainerLow : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: selected
              ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                )
              : null,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// A single track row with cover art, format chip, sync badge and actions.
class _TrackTile extends StatefulWidget {
  const _TrackTile({
    required this.file,
    required this.displayName,
    required this.syncState,
    required this.isPendingSwap,
    required this.isPendingSync,
    required this.isPendingDelete,
    this.isSelected = false,
    required this.loadCoverArt,
    required this.onTapReplace,
    required this.onSecondaryTap,
    required this.onSync,
    required this.onSwap,
    this.onDelete,
    this.onRestore,
  });

  final AudioFileEntity file;
  final String displayName;
  final _SyncState syncState;
  final bool isPendingSwap;
  final bool isPendingSync;
  final bool isPendingDelete;
  final bool isSelected;
  final Future<Uint8List?> Function(String path) loadCoverArt;
  final VoidCallback? onTapReplace;
  final void Function(TapDownDetails details) onSecondaryTap;
  final VoidCallback? onSync;
  final VoidCallback onSwap;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  State<_TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<_TrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final file = widget.file;
    final isPendingDelete = widget.isPendingDelete;
    final hasSingleDash = widget.displayName.split(' - ').length - 1 == 1;

    final Color rowColor = _hovered
        ? colorScheme.onSurface.withValues(alpha: 0.045)
        : Colors.transparent;

    final bool showSelection = widget.isSelected && !isPendingDelete;
    final Color selectionColor =
        showSelection ? colorScheme.primary.withValues(alpha: 0.14) : rowColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: GestureDetector(
          onTap: isPendingDelete ? null : widget.onTapReplace,
          onSecondaryTapDown: isPendingDelete ? null : widget.onSecondaryTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isPendingDelete
                  ? colorScheme.errorContainer.withValues(alpha: 0.25)
                  : selectionColor,
              borderRadius: BorderRadius.circular(6),
              border: isPendingDelete
                  ? Border.all(
                      color: colorScheme.error.withValues(alpha: 0.35),
                    )
                  : showSelection
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                        )
                      : null,
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: isPendingDelete ? 0.45 : 1,
                  child: _TrackArtwork(
                    path: file.path,
                    loadCoverArt: widget.loadCoverArt,
                  ),
                ),
                const SizedBox(width: 12),
                Opacity(
                  opacity: isPendingDelete ? 0.45 : 1,
                  child: _FormatChip(
                    format: file.format,
                    extension: extensionFromPath(file.path),
                  ),
                ),
                const SizedBox(width: 10),
                Opacity(
                  opacity: isPendingDelete ? 0.45 : 1,
                  child: _SyncBadge(state: widget.syncState),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: isPendingDelete ? 0.55 : 1,
                    child: Text(
                      widget.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: widget.isPendingSwap
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: widget.isPendingSwap
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        decoration:
                            isPendingDelete ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                if (isPendingDelete) ...[
                  _TrackAction(
                    icon: Icons.restore_rounded,
                    tooltip: 'Restore',
                    color: colorScheme.onSurfaceVariant,
                    onPressed: widget.onRestore,
                  ),
                ] else ...[
                  if (widget.onSync != null || widget.isPendingSync)
                    _TrackAction(
                      icon: Icons.sync_rounded,
                      tooltip: widget.isPendingSync
                          ? 'Undo metadata update'
                          : 'Update metadata from file name',
                      color: widget.isPendingSync
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: widget.onSync,
                    ),
                  if (hasSingleDash)
                    _TrackAction(
                      icon: Icons.swap_horiz_rounded,
                      tooltip: widget.isPendingSwap ? 'Undo' : 'Swap',
                      color: widget.isPendingSwap
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: widget.onSwap,
                    ),
                  _TrackAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Delete',
                    color: colorScheme.onSurfaceVariant,
                    onPressed: widget.onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.format, required this.extension});

  final AudioFormat format;
  final String extension;

  @override
  Widget build(BuildContext context) {
    final accent = _chipColor(format);
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        extension.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _extensionTextColor(context, format),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _TrackAction extends StatelessWidget {
  const _TrackAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
    );
  }
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
          ? Icon(Icons.music_note,
              size: 20, color: colorScheme.onSurfaceVariant)
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

enum _SyncState { pending, synced, mismatch, noPattern }

_SyncState _computeSync(String filePath, AudioMetadataEntity? metadata) {
  final parts = splitTitleArtist(filePath);
  if (parts == null || metadata == null) return _SyncState.noPattern;
  final title = metadata.title?.trim().toLowerCase();
  final artist = metadata.artist?.trim().toLowerCase();
  if (title == null || artist == null) return _SyncState.mismatch;
  if (title == parts.title.toLowerCase() &&
      artist == parts.artist.toLowerCase()) {
    return _SyncState.synced;
  }
  return _SyncState.mismatch;
}

/// Shows whether the file's metadata title and artist match the
/// "Title - Artist" file name. Loads metadata lazily.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.state});

  final _SyncState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (state) {
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

Color _extensionColor(AudioFormat format) {
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
  final hsl = HSLColor.fromColor(_extensionColor(format));
  return hsl.withSaturation(hsl.saturation * 0.75).toColor();
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
