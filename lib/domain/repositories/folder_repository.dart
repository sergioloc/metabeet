import '../entities/folder_entity.dart';

abstract class FolderRepository {
  Future<FolderEntity?> pickFolder();

  Future<List<FolderEntity>> getDirectSubfolders(String path);
}