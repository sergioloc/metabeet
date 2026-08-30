import 'dart:typed_data';

import '../entities/audio_file_entity.dart';

abstract class AudioFileRepository {
  /// Devuelve todos los archivos de audio contenidos en la ruta indicada,
  /// incluidos los de sus subcarpetas.
  Future<List<AudioFileEntity>> getAudioFiles(String path);

  /// Devuelve la carátula embebida del archivo, o `null` si no tiene.
  Future<Uint8List?> getCoverArt(String path);
}