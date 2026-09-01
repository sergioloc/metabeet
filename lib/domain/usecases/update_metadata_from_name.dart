import '../entities/metadata_update_request.dart';
import '../repositories/audio_file_repository.dart';

class UpdateMetadataFromNameUseCase {
  const UpdateMetadataFromNameUseCase(this.repository);

  final AudioFileRepository repository;

  Future<void> execute(List<MetadataUpdateRequest> requests) =>
      repository.updateMetadataFromFiles(requests);
}
