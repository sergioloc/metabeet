import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_bloc.dart';
import '../widgets/app_toolbar.dart';
import '../widgets/audio_files_view.dart';
import '../widgets/folder_tree_view.dart';
import '../widgets/resizable_split.dart';

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
                  : () => context
                      .read<HomeBloc>()
                      .add(const ImportFolderPressed()),
              onSavePressed: state.pendingRenames.isEmpty || state.isSaving
                  ? null
                  : () => context
                      .read<HomeBloc>()
                      .add(const SavePendingRenames()),
              saveCount: state.pendingRenames.length,
            ),
            body: switch (state.status) {
              HomeStatus.initial => const _EmptyState(),
              HomeStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              HomeStatus.error => _ErrorState(message: state.error),
              HomeStatus.ready => ResizableSplit(
                  left: FolderTreeView(
                    rootFolder: state.selectedFolder!,
                    rootChildren: state.rootFolders,
                    loadChildren: (path) =>
                        context.read<HomeBloc>().loadSubfolders(path),
                    selectedFolderPath: state.selectedFolder?.path,
                    onFolderSelected: (folder) => context
                        .read<HomeBloc>()
                        .add(FolderSelected(folder)),
                  ),
                  right: AudioFilesView(
                    folderName: state.selectedFolder?.name,
                    status: state.audioStatus,
                    files: state.audioFiles,
                    loadCoverArt: (path) =>
                        context.read<HomeBloc>().loadCoverArt(path),
                    pendingRenames: state.pendingRenames,
                    onSwap: (path) => context
                        .read<HomeBloc>()
                        .add(SwapRequested(path)),
                    error: state.audioError,
                    onRetry: () {
                      final folder = state.selectedFolder;
                      if (folder != null) {
                        context
                            .read<HomeBloc>()
                            .add(FolderSelected(folder));
                      }
                    },
                  ),
                ),
            },
          );
        },
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
              onPressed: () => context
                  .read<HomeBloc>()
                  .add(const ImportFolderPressed()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}