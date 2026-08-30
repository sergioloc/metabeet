import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/usecases/get_audio_files.dart';
import '../../domain/usecases/get_folder_subfolders.dart';
import '../../domain/usecases/import_folder.dart';

enum HomeStatus { initial, loading, ready, error }

enum AudioStatus { idle, loading, ready, error }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.selectedFolder,
    this.rootFolders = const [],
    this.error,
    this.audioStatus = AudioStatus.idle,
    this.audioFiles = const [],
    this.audioError,
  });

  final HomeStatus status;
  final FolderEntity? selectedFolder;
  final List<FolderEntity> rootFolders;
  final String? error;
  final AudioStatus audioStatus;
  final List<AudioFileEntity> audioFiles;
  final String? audioError;

  HomeState copyWith({
    HomeStatus? status,
    FolderEntity? selectedFolder,
    List<FolderEntity>? rootFolders,
    String? error,
    AudioStatus? audioStatus,
    List<AudioFileEntity>? audioFiles,
    String? audioError,
  }) {
    return HomeState(
      status: status ?? this.status,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      rootFolders: rootFolders ?? this.rootFolders,
      error: error ?? this.error,
      audioStatus: audioStatus ?? this.audioStatus,
      audioFiles: audioFiles ?? this.audioFiles,
      audioError: audioError ?? this.audioError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedFolder,
        rootFolders,
        error,
        audioStatus,
        audioFiles,
        audioError,
      ];
}

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class ImportFolderPressed extends HomeEvent {
  const ImportFolderPressed();
}

class FolderSelected extends HomeEvent {
  const FolderSelected(this.folder);

  final FolderEntity folder;

  @override
  List<Object?> get props => [folder];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required this.importFolder,
    required this.getFolderSubfolders,
    required this.getAudioFiles,
  }) : super(const HomeState()) {
    on<ImportFolderPressed>(_onImportFolderPressed);
    on<FolderSelected>(_onFolderSelected);
  }

  final ImportFolderUseCase importFolder;
  final GetFolderSubfoldersUseCase getFolderSubfolders;
  final GetAudioFilesUseCase getAudioFiles;

  Future<void> _onImportFolderPressed(
    ImportFolderPressed event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeState(status: HomeStatus.loading));
    try {
      final folder = await importFolder();
      if (folder == null) {
        emit(const HomeState());
        return;
      }
      emit(HomeState(
        status: HomeStatus.ready,
        selectedFolder: folder,
        audioStatus: AudioStatus.loading,
      ));

      final (subfolders, files) = await (
        getFolderSubfolders(folder.path),
        getAudioFiles(folder.path),
      ).wait;

      if (!isClosed && state.selectedFolder?.path == folder.path) {
        emit(state.copyWith(
          rootFolders: subfolders,
          audioFiles: files,
          audioStatus: AudioStatus.ready,
        ));
      }
    } catch (error) {
      emit(HomeState(status: HomeStatus.error, error: error.toString()));
    }
  }

  Future<void> _onFolderSelected(
    FolderSelected event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(
      status: HomeStatus.ready,
      selectedFolder: event.folder,
      audioStatus: AudioStatus.loading,
      audioFiles: const [],
      audioError: null,
    ));
    await _loadAudioFiles(event.folder, emit);
  }

  Future<void> _loadAudioFiles(
    FolderEntity folder,
    Emitter<HomeState> emit,
  ) async {
    try {
      final files = await getAudioFiles(folder.path);
      if (!isClosed && state.selectedFolder?.path == folder.path) {
        emit(state.copyWith(
          audioStatus: AudioStatus.ready,
          audioFiles: files,
          audioError: null,
        ));
      }
    } catch (error) {
      if (!isClosed && state.selectedFolder?.path == folder.path) {
        emit(state.copyWith(
          audioStatus: AudioStatus.error,
          audioError: error.toString(),
        ));
      }
    }
  }

  Future<List<FolderEntity>> loadSubfolders(String path) =>
      getFolderSubfolders(path);
}