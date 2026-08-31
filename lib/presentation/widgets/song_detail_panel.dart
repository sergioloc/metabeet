import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/enum/audio_format.dart';
import '../bloc/home_bloc.dart';

/// Right panel showing the details of the selected audio file.
class SongDetailPanel extends StatelessWidget {
  const SongDetailPanel({
    super.key,
    required this.status,
    required this.metadata,
    required this.onClose,
  });

  final MetadataStatus status;
  final AudioMetadataEntity? metadata;
  final VoidCallback onClose;

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
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Details',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close details',
                  color: colorScheme.onSurfaceVariant,
                ),
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
      case MetadataStatus.idle:
      case MetadataStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case MetadataStatus.ready:
        final meta = metadata;
        if (meta == null) {
          return Center(
            child: Text(
              'No metadata available',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _CoverArt(bytes: meta.coverArt, format: meta.format),
            ),
            const SizedBox(height: 16),
            Text(
              meta.title ?? meta.name.replaceFirst('.${meta.format.name}', ''),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meta.artist != null) ...[
              const SizedBox(height: 4),
              Text(
                meta.artist!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Section(title: 'File', rows: _fileRows(meta)),
            const SizedBox(height: 16),
            _Section(title: 'Metadata', rows: _metadataRows(meta)),
          ],
        );
    }
  }

  List<_DetailRow> _fileRows(AudioMetadataEntity meta) => [
        if (meta.name.isNotEmpty)
          _DetailRow(label: 'File name', value: meta.name),
        _DetailRow(label: 'Format', value: meta.format.name.toUpperCase()),
        if (meta.duration != null)
          _DetailRow(label: 'Duration', value: _formatDuration(meta.duration!)),
        if (meta.bitrate != null)
          _DetailRow(label: 'Bitrate', value: '${meta.bitrate} kbps'),
        if (meta.sampleRate != null)
          _DetailRow(label: 'Sample rate', value: '${meta.sampleRate} Hz'),
      ];

  List<_DetailRow> _metadataRows(AudioMetadataEntity meta) {
    final rows = <_DetailRow>[];
    if (meta.title != null) rows.add(_DetailRow(label: 'Title', value: meta.title!));
    if (meta.artist != null) rows.add(_DetailRow(label: 'Artist', value: meta.artist!));
    if (meta.album != null) rows.add(_DetailRow(label: 'Album', value: meta.album!));
    if (meta.genre != null) rows.add(_DetailRow(label: 'Genre', value: meta.genre!));
    if (meta.year != null) rows.add(_DetailRow(label: 'Year', value: '${meta.year}'));
    if (meta.track != null) rows.add(_DetailRow(label: 'Track', value: '${meta.track}'));
    return rows;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.bytes, required this.format});

  final Uint8List? bytes;
  final AudioFormat format;

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final colorScheme = Theme.of(context).colorScheme;

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note, size: 64, color: colorScheme.onSurfaceVariant),
    );

    final data = bytes;
    if (data == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        data,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          rows[i].label,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].value,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;
}
