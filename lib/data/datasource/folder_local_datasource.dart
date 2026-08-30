import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../util/path_utils.dart';
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
      dialogTitle: 'Select a folder',
    );
    if (path == null) return null;
    return FolderModel(name: nameFromPath(path), path: path);
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
                name: nameFromPath(entity.path),
                path: entity.path,
              ),
            );
          }
        } catch (_) {}
      }
    } catch (_) {}
    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }
}