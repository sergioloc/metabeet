import '../entities/audio_file_entity.dart';
import '../repositories/audio_file_repository.dart';

class GetAudioFilesUseCase {
  const GetAudioFilesUseCase(this.repository);

  final AudioFileRepository repository;

  Future<List<AudioFileEntity>> execute(String path) =>
      repository.getAudioFiles(path);
}
