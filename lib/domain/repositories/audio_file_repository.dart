import 'dart:typed_data';

import '../entities/audio_file_entity.dart';
import '../entities/audio_metadata_entity.dart';
import '../entities/file_rename_request.dart';
import '../entities/metadata_update_request.dart';
import '../entities/precache_progress.dart';

abstract class AudioFileRepository {
  Future<List<AudioFileEntity>> getAudioFiles(String path);

  /// Eagerly loads metadata and cover art for every audio file under [path]
  /// into memory, so later reads are served from the cache.
  Future<PrecacheTimings> precache(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  });

  Future<Uint8List?> getCoverArt(String path);

  Future<AudioMetadataEntity?> getMetadata(String path);

  Future<void> renameFiles(List<FileRenameRequest> requests);

  Future<void> updateMetadataFromFiles(List<MetadataUpdateRequest> requests);
}
