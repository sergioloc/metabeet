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
import 'domain/usecases/get_metadata.dart';
import 'domain/usecases/import_folder.dart';
import 'domain/usecases/rename_files.dart';
import 'presentation/bloc/home_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'util/app_colors.dart';

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
    renameFiles: RenameFilesUseCase(audioFileRepository),
    getMetadata: GetMetadataUseCase(audioFileRepository),
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
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}

/// Dark gray theme with a beet accent used only on accent roles.
ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(
    surfaceTint: Colors.transparent,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
    onSurfaceVariant: isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant,
    surfaceContainerLowest: isDark
        ? AppColors.darkSurfaceContainerLowest
        : AppColors.lightSurfaceContainerLowest,
    surfaceContainerLow: isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainerLow,
    surfaceContainer: isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer,
    surfaceContainerHigh: isDark
        ? AppColors.darkSurfaceContainerHigh
        : AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: isDark
        ? AppColors.darkSurfaceContainerHighest
        : AppColors.lightSurfaceContainerHighest,
    surfaceDim: isDark ? AppColors.darkSurfaceDim : AppColors.lightSurfaceDim,
    surfaceBright: isDark
        ? AppColors.darkSurfaceBright
        : AppColors.lightSurfaceBright,
    outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    outlineVariant: isDark
        ? AppColors.darkOutlineVariant
        : AppColors.lightOutlineVariant,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor:
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
  );
}