import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../model/folder_model.dart';

abstract class FolderLocalDataSource {
  Future<FolderModel?> pickFolder();
  Future<List<FolderModel>> getDirectSubfolders(String path);
}

class FolderLocalDataSourceImpl implements FolderLocalDataSource {
  const FolderLocalDataSourceImpl();

  @override
  Future<FolderModel?> pickFolder() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Selecciona una carpeta',
    );
    if (path == null) return null;
    return FolderModel(name: _folderNameFromPath(path), path: path);
  }

  @override
  Future<List<FolderModel>> getDirectSubfolders(String path) async {
    final folders = <FolderModel>[];
    try {
      final entities = Directory(path).listSync(followLinks: true);
      for (final entity in entities) {
        try {
          if (entity is Directory) {
            folders.add(
              FolderModel(
                name: _folderNameFromPath(entity.path),
                path: entity.path,
              ),
            );
          }
        } catch (_) {
          // Ignora entradas individuales que no se puedan inspeccionar.
        }
      }
    } catch (_) {
      // Ruta inaccesible: devuelve una lista vacía.
    }
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  String _folderNameFromPath(String path) {
    final segments = path
        .split(RegExp(r'[\\/]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? path : segments.last;
  }
}