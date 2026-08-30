import '../entities/folder_entity.dart';

abstract class FolderRepository {
  /// Abre el selector de carpetas del sistema.
  ///
  /// Devuelve `null` si el usuario cancela la selección.
  Future<FolderEntity?> pickFolder();

  /// Devuelve las subcarpetas directas de la ruta indicada.
  Future<List<FolderEntity>> getDirectSubfolders(String path);
}