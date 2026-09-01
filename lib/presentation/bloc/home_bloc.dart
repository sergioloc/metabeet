import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/audio_file_entity.dart';
import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/entities/file_rename_request.dart';
import '../../domain/entities/folder_entity.dart';
import '../../domain/entities/metadata_update_request.dart';
import '../../domain/usecases/get_audio_files.dart';
import '../../domain/usecases/get_cover_art.dart';
import '../../domain/usecases/get_folder_subfolders.dart';
import '../../domain/usecases/get_metadata.dart';
import '../../domain/usecases/import_folder.dart';
import '../../domain/usecases/rename_files.dart';
import '../../domain/usecases/update_metadata_from_name.dart';
import '../../util/path_utils.dart';

enum HomeStatus { initial, loading, ready, error }

enum AudioStatus { idle, loading, ready, error }

enum MetadataStatus { idle, loading, ready }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.selectedFolder,
    this.rootFolders = const [],
    this.error,
    this.audioStatus = AudioStatus.idle,
    this.audioFiles = const [],
    this.audioError,
    this.pendingRenames = const {},
    this.pendingMetadataUpdates = const {},
    this.isSaving = false,
    this.notice,
    this.selectedFilePath,
    this.selectedMetadata,
    this.metadataStatus = MetadataStatus.idle,
  });

  final HomeStatus status;
  final FolderEntity? selectedFolder;
  final List<FolderEntity> rootFolders;
  final String? error;
  final AudioStatus audioStatus;
  final List<AudioFileEntity> audioFiles;
  final String? audioError;
  final Map<String, String> pendingRenames;
  final Map<String, MetadataUpdateRequest> pendingMetadataUpdates;
  final bool isSaving;
  final String? notice;
  final String? selectedFilePath;
  final AudioMetadataEntity? selectedMetadata;
  final MetadataStatus metadataStatus;

  static const Object _unset = Object();

  HomeState copyWith({
    HomeStatus? status,
    FolderEntity? selectedFolder,
    List<FolderEntity>? rootFolders,
    String? error,
    AudioStatus? audioStatus,
    List<AudioFileEntity>? audioFiles,
    String? audioError,
    Map<String, String>? pendingRenames,
    Map<String, MetadataUpdateRequest>? pendingMetadataUpdates,
    bool? isSaving,
    Object? notice = _unset,
    String? selectedFilePath,
    AudioMetadataEntity? selectedMetadata,
    MetadataStatus? metadataStatus,
    Object? clearSelection = _unset,
  }) {
    final shouldClear = identical(clearSelection, true);
    return HomeState(
      status: status ?? this.status,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      rootFolders: rootFolders ?? this.rootFolders,
      error: error ?? this.error,
      audioStatus: audioStatus ?? this.audioStatus,
      audioFiles: audioFiles ?? this.audioFiles,
      audioError: audioError ?? this.audioError,
      pendingRenames: pendingRenames ?? this.pendingRenames,
      pendingMetadataUpdates:
          pendingMetadataUpdates ?? this.pendingMetadataUpdates,
      isSaving: isSaving ?? this.isSaving,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
      selectedFilePath: shouldClear
          ? null
          : (selectedFilePath ?? this.selectedFilePath),
      selectedMetadata: shouldClear
          ? null
          : (selectedMetadata ?? this.selectedMetadata),
      metadataStatus: shouldClear
          ? MetadataStatus.idle
          : (metadataStatus ?? this.metadataStatus),
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
        pendingRenames,
        pendingMetadataUpdates,
        isSaving,
        notice,
        selectedFilePath,
        selectedMetadata,
        metadataStatus,
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

class SwapRequested extends HomeEvent {
  const SwapRequested(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class RenameFileRequested extends HomeEvent {
  const RenameFileRequested(this.path, this.newName);

  final String path;
  final String newName;

  @override
  List<Object?> get props => [path, newName];
}

class SyncMetadataFromName extends HomeEvent {
  const SyncMetadataFromName(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class SavePendingRenames extends HomeEvent {
  const SavePendingRenames();
}

class FileSelected extends HomeEvent {
  const FileSelected(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

class FileDetailClosed extends HomeEvent {
  const FileDetailClosed();
}

class NoticeShown extends HomeEvent {
  const NoticeShown();
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required this.importFolder,
    required this.getFolderSubfolders,
    required this.getAudioFiles,
    required this.getCoverArt,
    required this.renameFiles,
    required this.getMetadata,
    required this.updateMetadataFromName,
  }) : super(const HomeState()) {
    on<ImportFolderPressed>(_onImportFolderPressed);
    on<FolderSelected>(_onFolderSelected);
    on<SwapRequested>(_onSwapRequested);
    on<RenameFileRequested>(_onRenameFileRequested);
    on<SyncMetadataFromName>(_onSyncMetadataFromName);
    on<SavePendingRenames>(_onSavePendingRenames);
    on<FileSelected>(_onFileSelected);
    on<FileDetailClosed>(_onFileDetailClosed);
    on<NoticeShown>(_onNoticeShown);
  }

  final ImportFolderUseCase importFolder;
  final GetFolderSubfoldersUseCase getFolderSubfolders;
  final GetAudioFilesUseCase getAudioFiles;
  final GetCoverArtUseCase getCoverArt;
  final RenameFilesUseCase renameFiles;
  final GetMetadataUseCase getMetadata;
  final UpdateMetadataFromNameUseCase updateMetadataFromName;

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
      clearSelection: true,
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

  Future<Uint8List?> loadCoverArt(String path) => getCoverArt(path);

  void _onSwapRequested(SwapRequested event, Emitter<HomeState> emit) {
    final pending = Map<String, String>.of(state.pendingRenames);
    if (pending.remove(event.path) == null) {
      final newPath = swapNamePath(event.path);
      if (newPath != null) {
        pending[event.path] = newPath;
      }
    }
    emit(state.copyWith(pendingRenames: pending));
  }

  void _onRenameFileRequested(
    RenameFileRequested event,
    Emitter<HomeState> emit,
  ) {
    final newPath = renamePath(event.path, event.newName);
    final pending = Map<String, String>.of(state.pendingRenames);
    if (newPath == event.path) {
      pending.remove(event.path);
    } else {
      pending[event.path] = newPath;
    }
    emit(state.copyWith(pendingRenames: pending));
  }

  void _onSyncMetadataFromName(
    SyncMetadataFromName event,
    Emitter<HomeState> emit,
  ) {
    final parts = splitTitleArtist(event.path);
    if (parts == null) {
      emit(state.copyWith(notice: 'File name must follow "Title - Artist"'));
      return;
    }
    final pending = Map<String, MetadataUpdateRequest>.of(
      state.pendingMetadataUpdates,
    );
    final existing = pending[event.path];
    if (existing != null &&
        existing.title == parts.title &&
        existing.artist == parts.artist) {
      pending.remove(event.path);
    } else {
      pending[event.path] = MetadataUpdateRequest(
        path: event.path,
        title: parts.title,
        artist: parts.artist,
      );
    }
    emit(state.copyWith(pendingMetadataUpdates: pending));
  }

  Future<void> _onSavePendingRenames(
    SavePendingRenames event,
    Emitter<HomeState> emit,
  ) async {
    final pending = state.pendingRenames;
    final pendingMetadata = state.pendingMetadataUpdates;
    if ((pending.isEmpty && pendingMetadata.isEmpty) || state.isSaving) return;

    emit(state.copyWith(isSaving: true));
    try {
      if (pendingMetadata.isNotEmpty) {
        await updateMetadataFromName(pendingMetadata.values.toList());
      }
      if (pending.isNotEmpty) {
        await renameFiles([
          for (final entry in pending.entries)
            FileRenameRequest(oldPath: entry.key, newPath: entry.value),
        ]);
      }

      final folder = state.selectedFolder;
      if (folder == null) {
        emit(state.copyWith(
          pendingRenames: const {},
          pendingMetadataUpdates: const {},
          isSaving: false,
          notice: 'Changes saved',
        ));
        return;
      }

      emit(state.copyWith(
        pendingRenames: const {},
        pendingMetadataUpdates: const {},
        isSaving: false,
        audioStatus: AudioStatus.loading,
        audioFiles: const [],
      ));
      await _loadAudioFiles(folder, emit);
      if (!isClosed) {
        emit(state.copyWith(notice: 'Changes saved'));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          isSaving: false,
          notice: 'Could not save the changes',
        ));
      }
    }
  }

  void _onNoticeShown(NoticeShown event, Emitter<HomeState> emit) {
    if (state.notice != null) {
      emit(state.copyWith(notice: null));
    }
  }

  Future<void> _onFileSelected(
    FileSelected event,
    Emitter<HomeState> emit,
  ) async {
    if (state.selectedFilePath == event.path) return;
    emit(state.copyWith(
      selectedFilePath: event.path,
      selectedMetadata: null,
      metadataStatus: MetadataStatus.loading,
      clearSelection: false,
    ));
    final metadata = await loadMetadata(event.path);
    if (!isClosed && state.selectedFilePath == event.path) {
      emit(state.copyWith(
        selectedMetadata: metadata,
        metadataStatus: MetadataStatus.ready,
      ));
    }
  }

  void _onFileDetailClosed(FileDetailClosed event, Emitter<HomeState> emit) {
    if (state.selectedFilePath != null) {
      emit(state.copyWith(clearSelection: true));
    }
  }

  Future<AudioMetadataEntity?> loadMetadata(String path) =>
      getMetadata(path);
}