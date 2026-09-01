import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/datasource/audio_file_local_datasource.dart';
import '../../../data/datasource/folder_local_datasource.dart';
import '../../../data/repositories/audio_file_repository_impl.dart';
import '../../../data/repositories/folder_repository_impl.dart';
import '../../../domain/entities/audio_file_entity.dart';
import '../../../domain/entities/audio_metadata_entity.dart';
import '../../../domain/entities/file_rename_request.dart';
import '../../../domain/entities/folder_entity.dart';
import '../../../domain/entities/metadata_update_request.dart';
import '../../../domain/repositories/audio_file_repository.dart';
import '../../../domain/repositories/folder_repository.dart';
import '../../../domain/usecases/get_audio_files.dart';
import '../../../domain/usecases/get_cover_art.dart';
import '../../../domain/usecases/get_folder_subfolders.dart';
import '../../../domain/usecases/get_metadata.dart';
import '../../../domain/usecases/import_folder.dart';
import '../../../domain/usecases/rename_files.dart';
import '../../../domain/usecases/update_metadata_from_name.dart';
import '../../../utils/path_utils.dart';
import 'home_error.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Orchestrates the home screen state.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState()) {
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

  final FolderRepository _folderRepository = FolderRepositoryImpl(
    const FolderLocalDataSourceImpl(),
  );
  final AudioFileRepository _audioFileRepository = AudioFileRepositoryImpl(
    AudioFileLocalDataSourceImpl(),
  );

  late final ImportFolderUseCase _importFolder =
      ImportFolderUseCase(_folderRepository);
  late final GetFolderSubfoldersUseCase _getFolderSubfolders =
      GetFolderSubfoldersUseCase(_folderRepository);
  late final GetAudioFilesUseCase _getAudioFiles =
      GetAudioFilesUseCase(_audioFileRepository);
  late final GetCoverArtUseCase _getCoverArt =
      GetCoverArtUseCase(_audioFileRepository);
  late final RenameFilesUseCase _renameFiles =
      RenameFilesUseCase(_audioFileRepository);
  late final GetMetadataUseCase _getMetadata =
      GetMetadataUseCase(_audioFileRepository);
  late final UpdateMetadataFromNameUseCase _updateMetadataFromName =
      UpdateMetadataFromNameUseCase(_audioFileRepository);

  HomeError _mapError(Object error) {
    return HomeError.ERROR;
  }

  Future<void> _onImportFolderPressed(
    ImportFolderPressed event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeState(status: HomeStatus.loading));
    try {
      final folder = await _importFolder.execute();
      if (folder == null) {
        emit(const HomeState());
        return;
      }
      emit(HomeState(
        status: HomeStatus.ready,
        rootFolder: folder,
        selectedFolder: folder,
        audioStatus: AudioStatus.loading,
      ));

      final (subfolders, files) = await (
        _getFolderSubfolders.execute(folder.path),
        _getAudioFiles.execute(folder.path),
      ).wait;

      if (!isClosed && state.selectedFolder?.path == folder.path) {
        emit(state.copyWith(
          rootFolders: subfolders,
          audioFiles: files,
          audioStatus: AudioStatus.ready,
        ));
      }
    } catch (error) {
      emit(
          HomeState(status: HomeStatus.error, error: _mapError(error).message));
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
      final files = await _getAudioFiles.execute(folder.path);
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
          audioError: _mapError(error).message,
        ));
      }
    }
  }

  Future<List<FolderEntity>> loadSubfolders(String path) =>
      _getFolderSubfolders.execute(path);

  Future<Uint8List?> loadCoverArt(String path) => _getCoverArt.execute(path);

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
        await _updateMetadataFromName.execute(pendingMetadata.values.toList());
      }
      if (pending.isNotEmpty) {
        await _renameFiles.execute([
          for (final entry in pending.entries)
            FileRenameRequest(oldPath: entry.key, newPath: entry.value),
        ]);
      }

      final folder = state.rootFolder ?? state.selectedFolder;
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
        selectedFolder: folder,
        pendingRenames: const {},
        pendingMetadataUpdates: const {},
        isSaving: false,
        audioStatus: AudioStatus.loading,
        audioFiles: const [],
        clearSelection: true,
      ));
      final (subfolders, files) = await (
        _getFolderSubfolders.execute(folder.path),
        _getAudioFiles.execute(folder.path),
      ).wait;
      if (!isClosed && state.rootFolder?.path == folder.path) {
        emit(state.copyWith(
          rootFolders: subfolders,
          audioFiles: files,
          audioStatus: AudioStatus.ready,
        ));
      }
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
    final metadata = await _getMetadata.execute(event.path);
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
      _getMetadata.execute(path);
}
