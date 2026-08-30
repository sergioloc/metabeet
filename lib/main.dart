import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/datasource/audio_file_local_datasource.dart';
import 'data/datasource/folder_local_datasource.dart';
import 'data/repositories/audio_file_repository_impl.dart';
import 'data/repositories/folder_repository_impl.dart';
import 'domain/repositories/audio_file_repository.dart';
import 'domain/repositories/folder_repository.dart';
import 'domain/usecases/get_audio_files.dart';
import 'domain/usecases/get_cover_art.dart';
import 'domain/usecases/get_folder_subfolders.dart';
import 'domain/usecases/import_folder.dart';
import 'presentation/bloc/home_bloc.dart';
import 'presentation/pages/home_page.dart';

void main() {
  final FolderRepository folderRepository = FolderRepositoryImpl(
    const FolderLocalDataSourceImpl(),
  );
  final AudioFileRepository audioFileRepository = AudioFileRepositoryImpl(
    AudioFileLocalDataSourceImpl(),
  );
  final homeBloc = HomeBloc(
    importFolder: ImportFolderUseCase(folderRepository),
    getFolderSubfolders: GetFolderSubfoldersUseCase(folderRepository),
    getAudioFiles: GetAudioFilesUseCase(audioFileRepository),
    getCoverArt: GetCoverArtUseCase(audioFileRepository),
  );

  runApp(MetabeetApp(bloc: homeBloc));
}

class MetabeetApp extends StatelessWidget {
  const MetabeetApp({super.key, required this.bloc});

  final HomeBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>.value(
      value: bloc,
      child: MaterialApp(
        title: 'Metabeet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}