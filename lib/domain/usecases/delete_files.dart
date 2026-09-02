import '../repositories/audio_file_repository.dart';

class DeleteFilesUseCase {
  const DeleteFilesUseCase(this.repository);

  final AudioFileRepository repository;

  Future<void> execute(List<String> paths) => repository.deleteFiles(paths);
}
