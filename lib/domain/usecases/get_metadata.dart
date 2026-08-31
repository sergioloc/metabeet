import '../entities/audio_metadata_entity.dart';
import '../repositories/audio_file_repository.dart';

class GetMetadataUseCase {
  const GetMetadataUseCase(this.repository);

  final AudioFileRepository repository;

  Future<AudioMetadataEntity?> call(String path) =>
      repository.getMetadata(path);
}
