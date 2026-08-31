import 'dart:typed_data';

import '../entities/audio_file_entity.dart';
import '../entities/audio_metadata_entity.dart';
import '../entities/file_rename_request.dart';

abstract class AudioFileRepository {
  Future<List<AudioFileEntity>> getAudioFiles(String path);

  Future<Uint8List?> getCoverArt(String path);

  Future<AudioMetadataEntity?> getMetadata(String path);

  Future<void> renameFiles(List<FileRenameRequest> requests);
}