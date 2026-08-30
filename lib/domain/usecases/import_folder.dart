import '../entities/folder_entity.dart';
import '../repositories/folder_repository.dart';

class ImportFolderUseCase {
  const ImportFolderUseCase(this.repository);

  final FolderRepository repository;

  Future<FolderEntity?> call() => repository.pickFolder();
}