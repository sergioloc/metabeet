import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/precache_progress.dart';
import '../bloc/home/home_bloc.dart';
import '../widgets/app_toolbar.dart';
import '../widgets/audio_files_view.dart';
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
                          state.pendingMetadataUpdates.isEmpty) ||
                      state.isSaving
                  ? null
                  : () =>
                      context.read<HomeBloc>().add(const SavePendingRenames()),
              saveCount: state.pendingRenames.length +
                  state.pendingMetadataUpdates.length,
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
          child: _PrecacheOverlay(
            progress: progress,
            timings: state.precacheTimings,
          ),
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
      onSwap: (path) => context.read<HomeBloc>().add(SwapRequested(path)),
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

    if (state.selectedFilePath == null) return right;

    return ResizableSplit(
      initialFraction: 0.6,
      minFraction: 0.3,
      maxFraction: 0.75,
      left: right,
      right: SongDetailPanel(
        status: state.metadataStatus,
        metadata: state.selectedMetadata,
        coverArt: state.selectedCoverArt,
        onClose: () => context.read<HomeBloc>().add(const FileDetailClosed()),
      ),
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
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Click "Import" to select a folder',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not import the folder',
              style: Theme.of(context).textTheme.titleMedium,
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  context.read<HomeBloc>().add(const ImportFolderPressed()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen banner showing the folder precache progress.
class _PrecacheOverlay extends StatelessWidget {
  const _PrecacheOverlay({required this.progress, this.timings});

  final PrecacheProgress progress;
  final PrecacheTimings? timings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fraction = progress.fraction.clamp(0.0, 1.0);

    final timings = this.timings;
    final isComplete = progress.done >= progress.total && progress.total > 0;

    String detail;
    if (isComplete) {
      detail = 'Completed ${progress.total} files';
    } else {
      switch (progress.phase) {
        case PrecachePhase.metadata:
          detail = 'Reading metadata ${progress.done}/${progress.total}';
        case PrecachePhase.cover:
          if (timings != null && timings.metadataMs > 0) {
            detail =
                'Reading covers ${progress.done}/${progress.total} · metadata took ${timings.metadataMs} ms';
          } else {
            detail = 'Reading covers ${progress.done}/${progress.total}';
          }
      }
    }

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.92),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_outline
                      : Icons.folder_open_outlined,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isComplete ? 'Import complete' : 'Importing folder…',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: fraction == 0 ? null : fraction,
                  ),
                ),
                if (fraction >= 1.0) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        context.read<HomeBloc>().add(const PrecacheDismissed()),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ] else ...[
                  if (timings != null &&
                      timings.metadataMs > 0 &&
                      timings.coverMs > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'metadata ${timings.metadataMs} ms · cover ${timings.coverMs} ms',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
