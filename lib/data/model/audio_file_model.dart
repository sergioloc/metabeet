import 'package:flutter/foundation.dart';

import '../../domain/enum/audio_format.dart';
import '../../domain/entities/audio_file_entity.dart';

@immutable
class AudioFileModel {
  const AudioFileModel({
    required this.name,
    required this.path,
    required this.format,
  });

  final String name;
  final String path;
  final AudioFormat format;

  AudioFileEntity toEntity() =>
      AudioFileEntity(name: name, path: path, format: format);
}