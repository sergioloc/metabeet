import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metabeet/domain/enum/audio_format.dart';
import 'package:metabeet/domain/entities/audio_file_entity.dart';
import 'package:metabeet/domain/entities/folder_entity.dart';
import 'package:metabeet/domain/repositories/audio_file_repository.dart';
import 'package:metabeet/domain/repositories/folder_repository.dart';
import 'package:metabeet/domain/usecases/get_audio_files.dart';
import 'package:metabeet/domain/usecases/get_folder_subfolders.dart';
import 'package:metabeet/domain/usecases/import_folder.dart';
import 'package:metabeet/main.dart';
import 'package:metabeet/presentation/bloc/home_bloc.dart';

class _FakeFolderRepository implements FolderRepository {
  _FakeFolderRepository(this.tree);

  /// Ruta -> subcarpetas directas.
  final Map<String, List<FolderEntity>> tree;

  @override
  Future<FolderEntity?> pickFolder() async =>
      const FolderEntity(name: 'Music', path: '/music');

  @override
  Future<List<FolderEntity>> getDirectSubfolders(String path) async =>
      tree[path] ?? const [];
}

class _FakeAudioFileRepository implements AudioFileRepository {
  @override
  Future<List<AudioFileEntity>> getAudioFiles(String path) async => const [
        AudioFileEntity(
          name: 'song.mp3',
          path: '/music/rock/song.mp3',
          format: AudioFormat.mp3,
        ),
      ];
}

void main() {
  testWidgets('muestra el nombre y el botón de importar', (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    expect(find.text('Metabeet'), findsOneWidget);
    expect(find.text('Importar'), findsOneWidget);
  });

  testWidgets('al importar una carpeta muestra su árbol y sus canciones',
      (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsWidgets);
    expect(find.text('Canciones'), findsOneWidget);
    expect(find.text('song'), findsOneWidget);
    expect(find.text('mp3'), findsOneWidget);
  });

  testWidgets('seleccionar una subcarpeta carga sus canciones', (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();

    expect(find.text('Rock'), findsWidgets);
    expect(find.text('song'), findsOneWidget);
    expect(find.text('mp3'), findsOneWidget);
  });

  testWidgets('sin subcarpetas no muestra la flecha de expansión',
      (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
      '/music/rock': const [],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('con subcarpetas sí muestra la flecha de expansión',
      (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
      '/music/rock': const [
        FolderEntity(name: 'Albums', path: '/music/rock/albums'),
      ],
      '/music/rock/albums': const [],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}

HomeBloc _buildBloc(Map<String, List<FolderEntity>> tree) {
  final folderRepository = _FakeFolderRepository(tree);
  final audioFileRepository = _FakeAudioFileRepository();
  return HomeBloc(
    importFolder: ImportFolderUseCase(folderRepository),
    getFolderSubfolders: GetFolderSubfoldersUseCase(folderRepository),
    getAudioFiles: GetAudioFilesUseCase(audioFileRepository),
  );
}