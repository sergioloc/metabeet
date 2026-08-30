import 'dart:io';

import '../../domain/enum/audio_format.dart';
import '../../util/path_utils.dart';
import '../model/audio_file_model.dart';

abstract class AudioFileLocalDataSource {
  Future<List<AudioFileModel>> getAudioFiles(String path);
}

class AudioFileLocalDataSourceImpl implements AudioFileLocalDataSource {
  const AudioFileLocalDataSourceImpl();

  @override
  Future<List<AudioFileModel>> getAudioFiles(String path) async {
    final files = <AudioFileModel>[];
    try {
      final entities =
          Directory(path).listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final format = AudioFormat.fromPath(entity.path);
          if (format != null) {
            files.add(AudioFileModel(
              name: nameFromPath(entity.path),
              path: entity.path,
              format: format,
            ));
          }
        }
      }
    } catch (_) {
      // Ruta inaccesible: devuelve una lista vacía.
    }
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }
}