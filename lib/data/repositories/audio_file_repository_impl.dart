import 'dart:typed_data';

import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/file_rename_request.dart';
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
  Future<Uint8List?> getCoverArt(String path) =>
      localDataSource.getCoverArt(path);

  @override
  Future<void> renameFiles(List<FileRenameRequest> requests) =>
      localDataSource.renameFiles(requests);
}