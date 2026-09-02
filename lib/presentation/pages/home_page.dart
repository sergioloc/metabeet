import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/precache_progress.dart';
import '../bloc/home/home_bloc.dart';
import '../widgets/app_toolbar.dart';
import '../widgets/audio_files_view.dart';
import '../widgets/beet_logo.dart';
import '../widgets/folder_tree_view.dart';
import '../widgets/resizable_split.dart';
import '../widgets/song_detail_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listener: (context, state) {
        final notice = state.notice;
        if (notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice)));
          context.read<HomeBloc>().add(const NoticeShown());
        }
      },
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppToolbar(
              appName: 'Metabeet',
              onImportPressed: state.status == HomeStatus.loading ||
                      state.isSaving
                  ? null
                  : () =>
                      context.read<HomeBloc>().add(const ImportFolderPressed()),
              onSavePressed: (state.pendingRenames.isEmpty &&
                          state.pendingMetadataUpdates.isEmpty &&
                          state.pendingDeletes.isEmpty) ||
                      state.isSaving
                  ? null
                  : () =>
                      context.read<HomeBloc>().add(const SavePendingRenames()),
              saveCount: state.pendingRenames.length +
                  state.pendingMetadataUpdates.length +
                  state.pendingDeletes.length,
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state) {
    final content = switch (state.status) {
      HomeStatus.initial => const _EmptyState(),
      HomeStatus.loading => const Center(child: CircularProgressIndicator()),
      HomeStatus.error => _ErrorState(message: state.error),
      HomeStatus.ready => ResizableSplit(
          left: FolderTreeView(
            rootFolder: state.selectedFolder!,
            rootChildren: state.rootFolders,
            loadChildren: (path) =>
                context.read<HomeBloc>().loadSubfolders(path),
            selectedFolderPath: state.selectedFolder?.path,
            onFolderSelected: (folder) =>
                context.read<HomeBloc>().add(FolderSelected(folder)),
          ),
          right: _buildRightPanel(context, state),
        ),
    };

    final progress = state.precacheProgress;
    if (progress == null) return content;

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: _PrecacheOverlay(progress: progress),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context, HomeState state) {
    final right = AudioFilesView(
      folderName: state.selectedFolder?.name,
      status: state.audioStatus,
      files: state.audioFiles,
      loadCoverArt: (path) => context.read<HomeBloc>().loadCoverArt(path),
      loadMetadata: (path) => context.read<HomeBloc>().loadMetadata(path),
      pendingRenames: state.pendingRenames,
      pendingMetadataUpdates: state.pendingMetadataUpdates,
      pendingDeletes: state.pendingDeletes,
      onSwap: (path) => context.read<HomeBloc>().add(SwapRequested(path)),
      onDelete: (path) => context.read<HomeBloc>().add(DeleteRequested(path)),
      onRestore: (path) => context.read<HomeBloc>().add(RestoreRequested(path)),
      onRename: (path, newName) =>
          context.read<HomeBloc>().add(RenameFileRequested(path, newName)),
      onSyncFromName: (path) =>
          context.read<HomeBloc>().add(SyncMetadataFromName(path)),
      onFileSelected: (path) =>
          context.read<HomeBloc>().add(FileSelected(path)),
      error: state.audioError,
      onRetry: () {
        final folder = state.selectedFolder;
        if (folder != null) {
          context.read<HomeBloc>().add(FolderSelected(folder));
        }
      },
    );

    final hasSelection = state.selectedFilePath != null;

    // Keep the songs list at a stable position in the tree so its state (and
    // scroll offset) survives opening and closing the detail panel.
    return ResizableSplit(
      initialFraction: hasSelection ? 0.6 : 1.0,
      minFraction: hasSelection ? 0.3 : 0.9,
      maxFraction: hasSelection ? 0.75 : 0.98,
      left: right,
      right: hasSelection
          ? SongDetailPanel(
              status: state.metadataStatus,
              metadata: state.selectedMetadata,
              coverArt: state.selectedCoverArt,
              onClose: () =>
                  context.read<HomeBloc>().add(const FileDetailClosed()),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: const BeetLogo(size: 56),
          ),
          const SizedBox(height: 20),
          Text(
            'Click "Import" to select a folder',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your music library will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Could not import the folder',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () =>
                  context.read<HomeBloc>().add(const ImportFolderPressed()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Windows 11 style progress card shown while importing a folder.
class _PrecacheOverlay extends StatelessWidget {
  const _PrecacheOverlay({required this.progress});

  final PrecacheProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fraction = progress.fraction.clamp(0.0, 1.0);
    final detail = 'Importing ${progress.done}/${progress.total} files…';

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open_rounded,
                        size: 22, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Importing folder…',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: fraction == 0 ? null : fraction,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
