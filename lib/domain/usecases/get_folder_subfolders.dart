import '../entities/folder_entity.dart';
import '../repositories/folder_repository.dart';

class GetFolderSubfoldersUseCase {
  const GetFolderSubfoldersUseCase(this.repository);

  final FolderRepository repository;

  Future<List<FolderEntity>> call(String path) =>
      repository.getDirectSubfolders(path);
}