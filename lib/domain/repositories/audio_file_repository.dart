import 'dart:typed_data';

import '../entities/audio_file_entity.dart';

abstract class AudioFileRepository {
  Future<List<AudioFileEntity>> getAudioFiles(String path);

  Future<Uint8List?> getCoverArt(String path);
}