import 'package:flutter/material.dart';

import '../../domain/entities/audio_file_entity.dart';
import '../../util/path_utils.dart';
import '../bloc/home_bloc.dart';

/// Panel derecho: muestra los archivos de audio de la carpeta seleccionada.
class AudioFilesView extends StatelessWidget {
  const AudioFilesView({
    super.key,
    required this.folderName,
    required this.status,
    required this.files,
    this.error,
    this.onRetry,
  });

  final String? folderName;
  final AudioStatus status;
  final List<AudioFileEntity> files;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                        'Canciones',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        folderName ?? '',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (status == AudioStatus.ready) ...[
                  const SizedBox(width: 8),
                  Text(
                    _fileCountLabel(files.length),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (status) {
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
                  'No se pudieron cargar los archivos de audio',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      case AudioStatus.ready:
        if (files.isEmpty) {
          return Center(
            child: Text(
              'No hay archivos de audio en esta carpeta',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: files.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            indent: 56,
          ),
          itemBuilder: (context, index) {
            final file = files[index];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.audiotrack,
                color: colorScheme.primary,
              ),
              title: Text(
                nameWithoutExtension(file.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Chip(
                label: Text(
                  extensionFromPath(file.path),
                  style: textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        );
    }
  }

  String _fileCountLabel(int count) =>
      count == 1 ? '1 archivo' : '$count archivos';
}