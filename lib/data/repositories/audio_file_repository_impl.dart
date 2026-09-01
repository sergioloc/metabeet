import 'dart:typed_data';

import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/entities/file_rename_request.dart';
import '../../domain/entities/metadata_update_request.dart';
import '../../domain/repositories/audio_file_repository.dart';
import '../datasource/audio_file_local_datasource.dart';

class AudioFileRepositoryImpl implements AudioFileRepository {
  const AudioFileRepositoryImpl(this.localDataSource);

  final AudioFileLocalDataSource localDataSource;

  @override
  Future<List<AudioFileEntity>> getAudioFiles(String path) async {
    final models = await localDataSource.getAudioFiles(path);
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> precache(String path) => localDataSource.precache(path);

  @override
  Future<Uint8List?> getCoverArt(String path) =>
      localDataSource.getCoverArt(path);

  @override
  Future<AudioMetadataEntity?> getMetadata(String path) =>
      localDataSource.getMetadata(path);

  @override
  Future<void> renameFiles(List<FileRenameRequest> requests) =>
      localDataSource.renameFiles(requests);

  @override
  Future<void> updateMetadataFromFiles(List<MetadataUpdateRequest> requests) =>
      localDataSource.updateMetadataFromFiles(requests);
}
