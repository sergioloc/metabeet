import 'package:equatable/equatable.dart';

import '../enum/audio_format.dart';

class AudioFileEntity extends Equatable {
  const AudioFileEntity({
    required this.name,
    required this.path,
    required this.format,
  });

  final String name;
  final String path;
  final AudioFormat format;

  @override
  List<Object?> get props => [name, path, format];
}
