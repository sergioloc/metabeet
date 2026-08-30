import '../entities/file_rename_request.dart';
import '../repositories/audio_file_repository.dart';

class RenameFilesUseCase {
  const RenameFilesUseCase(this.repository);

  final AudioFileRepository repository;

  Future<void> call(List<FileRenameRequest> requests) =>
      repository.renameFiles(requests);
}