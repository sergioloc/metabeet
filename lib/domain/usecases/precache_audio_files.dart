import '../entities/precache_progress.dart';
import '../repositories/audio_file_repository.dart';

/// Eagerly loads metadata and cover art for every audio file under a folder
/// so later reads are served straight from memory.
class PrecacheAudioFilesUseCase {
  const PrecacheAudioFilesUseCase(this.repository);

  final AudioFileRepository repository;

  Future<void> execute(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  }) =>
      repository.precache(path, onProgress: onProgress);
}
