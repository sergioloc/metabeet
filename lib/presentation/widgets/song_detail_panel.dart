import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/enum/audio_format.dart';
import '../bloc/home/home_bloc.dart';

/// Right panel showing the details of the selected audio file.
class SongDetailPanel extends StatelessWidget {
  const SongDetailPanel({
    super.key,
    required this.status,
    required this.metadata,
    required this.onClose,
    this.coverArt,
  });

  final MetadataStatus status;
  final AudioMetadataEntity? metadata;
  final VoidCallback onClose;
  final Uint8List? coverArt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 17, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Details',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close details',
                  visualDensity: VisualDensity.compact,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const Divider(),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off_outlined,
                    size: 40, color: colorScheme.outlineVariant),
                const SizedBox(height: 10),
                Text(
                  'No metadata available',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: _CoverArt(
                bytes: coverArt ?? meta.coverArt,
                format: meta.format,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              meta.title ?? meta.name.replaceFirst('.${meta.format.name}', ''),
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 20),
            _Section(title: 'File', rows: _fileRows(meta)),
            const SizedBox(height: 14),
            _Section(title: 'Metadata', rows: _metadataRows(meta)),
          ],
        );
    }
  }

  List<_DetailRow> _fileRows(AudioMetadataEntity meta) => [
        _DetailRow(label: 'File name', value: meta.name),
        _DetailRow(label: 'Format', value: meta.format.name.toUpperCase()),
        _DetailRow(
          label: 'Duration',
          value: meta.duration == null
              ? _emptyValue
              : _formatDuration(meta.duration!),
        ),
        _DetailRow(
          label: 'Bitrate',
          value: meta.bitrate == null ? _emptyValue : '${meta.bitrate} kbps',
        ),
        _DetailRow(
          label: 'Sample rate',
          value:
              meta.sampleRate == null ? _emptyValue : '${meta.sampleRate} Hz',
        ),
      ];

  static const String _emptyValue = '—';

  List<_DetailRow> _metadataRows(AudioMetadataEntity meta) => [
        _DetailRow(label: 'Title', value: meta.title ?? _emptyValue),
        _DetailRow(label: 'Artist', value: meta.artist ?? _emptyValue),
        _DetailRow(label: 'Album', value: meta.album ?? _emptyValue),
        _DetailRow(label: 'Genre', value: meta.genre ?? _emptyValue),
        _DetailRow(
          label: 'Year',
          value: meta.year == null ? _emptyValue : '${meta.year}',
        ),
        _DetailRow(
          label: 'Track',
          value: meta.track == null ? _emptyValue : '${meta.track}',
        ),
      ];

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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildInner(context),
    );
  }

  Widget _buildInner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = bytes;
    if (data == null) {
      return Icon(
        Icons.music_note_rounded,
        size: 72,
        color: colorScheme.onSurfaceVariant,
      );
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.music_note_rounded,
        size: 72,
        color: colorScheme.onSurfaceVariant,
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
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
