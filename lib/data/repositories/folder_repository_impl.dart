import '../../domain/entities/folder_entity.dart';
import '../../domain/repositories/folder_repository.dart';
import '../datasource/folder_local_datasource.dart';

class FolderRepositoryImpl implements FolderRepository {
  const FolderRepositoryImpl(this.localDataSource);

  final FolderLocalDataSource localDataSource;

  @override
  Future<FolderEntity?> pickFolder() async {
    final model = await localDataSource.pickFolder();
    return model?.toEntity();
  }

  @override
  Future<List<FolderEntity>> getDirectSubfolders(String path) async {
    final models = await localDataSource.getDirectSubfolders(path);
    return models.map((model) => model.toEntity()).toList();
  }
}
