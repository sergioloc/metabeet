import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metabeet/domain/enum/audio_format.dart';
import 'package:metabeet/domain/entities/audio_file_entity.dart';
import 'package:metabeet/domain/entities/file_rename_request.dart';
import 'package:metabeet/domain/entities/folder_entity.dart';
import 'package:metabeet/domain/repositories/audio_file_repository.dart';
import 'package:metabeet/domain/repositories/folder_repository.dart';
import 'package:metabeet/domain/usecases/get_audio_files.dart';
import 'package:metabeet/domain/usecases/get_cover_art.dart';
import 'package:metabeet/domain/usecases/get_folder_subfolders.dart';
import 'package:metabeet/domain/usecases/import_folder.dart';
import 'package:metabeet/domain/usecases/rename_files.dart';
import 'package:metabeet/main.dart';
import 'package:metabeet/presentation/bloc/home_bloc.dart';

class _FakeFolderRepository implements FolderRepository {
  _FakeFolderRepository(this.tree);

  final Map<String, List<FolderEntity>> tree;

  @override
  Future<FolderEntity?> pickFolder() async =>
      const FolderEntity(name: 'Music', path: '/music');

  @override
  Future<List<FolderEntity>> getDirectSubfolders(String path) async =>
      tree[path] ?? const [];
}

class _FakeAudioFileRepository implements AudioFileRepository {
  _FakeAudioFileRepository({this.coverBytes});

  final Uint8List? coverBytes;

  @override
  Future<List<AudioFileEntity>> getAudioFiles(String path) async => const [
        AudioFileEntity(
          name: 'song.mp3',
          path: '/music/rock/song.mp3',
          format: AudioFormat.mp3,
        ),
      ];

  @override
  Future<Uint8List?> getCoverArt(String path) async {
    final cover = coverBytes;
    return cover == null ? null : Uint8List.fromList(cover);
  }

  @override
  Future<void> renameFiles(List<FileRenameRequest> requests) async {}
}

/// PNG transparente de 1x1.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('muestra el nombre y el botón de importar', (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    expect(find.text('Metabeet'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });

  testWidgets('al importar una carpeta muestra su árbol y sus canciones',
      (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Music'), findsWidgets);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('song'), findsOneWidget);
    expect(find.text('mp3'), findsOneWidget);
  });

  testWidgets('seleccionar una subcarpeta carga sus canciones', (tester) async {
    final bloc = _buildBloc({
      '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
    });
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Import'));
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

    await tester.tap(find.text('Import'));
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

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('sin carátula se muestra el icono musical', (tester) async {
    final bloc = _buildBloc(
      {
        '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
      },
      coverBytes: null,
    );
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con carátula se muestra la imagen en lugar del icono',
      (tester) async {
    final bloc = _buildBloc(
      {
        '/music': const [FolderEntity(name: 'Rock', path: '/music/rock')],
      },
      coverBytes: _tinyPng,
    );
    await tester.pumpWidget(MetabeetApp(bloc: bloc));

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack), findsNothing);
  });
}

HomeBloc _buildBloc(
  Map<String, List<FolderEntity>> tree, {
  Uint8List? coverBytes,
}) {
  final folderRepository = _FakeFolderRepository(tree);
  final audioFileRepository = _FakeAudioFileRepository(coverBytes: coverBytes);
  return HomeBloc(
    importFolder: ImportFolderUseCase(folderRepository),
    getFolderSubfolders: GetFolderSubfoldersUseCase(folderRepository),
    getAudioFiles: GetAudioFilesUseCase(audioFileRepository),
    getCoverArt: GetCoverArtUseCase(audioFileRepository),
    renameFiles: RenameFilesUseCase(audioFileRepository),
  );
}