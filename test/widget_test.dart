import 'package:flutter_test/flutter_test.dart';
import 'package:metabeet/domain/entities/folder_entity.dart';
import 'package:metabeet/domain/repositories/folder_repository.dart';
import 'package:metabeet/domain/usecases/get_folder_subfolders.dart';
import 'package:metabeet/domain/usecases/import_folder.dart';
import 'package:metabeet/main.dart';
import 'package:metabeet/presentation/bloc/home_bloc.dart';

class _FakeFolderRepository implements FolderRepository {
  @override
  Future<FolderEntity?> pickFolder() async =>
      const FolderEntity(name: 'Music', path: '/music');

  @override
  Future<List<FolderEntity>> getDirectSubfolders(String path) async =>
      const [FolderEntity(name: 'Rock', path: '/music/rock')];
}

void main() {
  testWidgets('muestra el nombre y el botón de importar', (tester) async {
    final bloc = _buildBloc();
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    expect(find.text('Metabeet'), findsOneWidget);
    expect(find.text('Importar'), findsOneWidget);
  });

  testWidgets('al importar una carpeta muestra su árbol', (tester) async {
    final bloc = _buildBloc();
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
  });
}

HomeBloc _buildBloc() {
  final repository = _FakeFolderRepository();
  return HomeBloc(
    importFolder: ImportFolderUseCase(repository),
    getFolderSubfolders: GetFolderSubfoldersUseCase(repository),
  );
}