import 'package:equatable/equatable.dart';

class FolderEntity extends Equatable {
  const FolderEntity({required this.name, required this.path});

  final String name;
  final String path;

  @override
  List<Object?> get props => [name, path];
}