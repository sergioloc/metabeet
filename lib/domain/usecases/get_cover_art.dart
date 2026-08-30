import 'dart:typed_data';

import '../repositories/audio_file_repository.dart';

class GetCoverArtUseCase {
  const GetCoverArtUseCase(this.repository);

  final AudioFileRepository repository;

  Future<Uint8List?> call(String path) => repository.getCoverArt(path);
}