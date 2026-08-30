import 'package:flutter/foundation.dart';

import '../../domain/entities/folder_entity.dart';

@immutable
class FolderModel {
  const FolderModel({required this.name, required this.path});

  final String name;
  final String path;

  FolderEntity toEntity() => FolderEntity(name: name, path: path);
}