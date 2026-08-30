import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/folder_entity.dart';
import '../../domain/usecases/get_folder_subfolders.dart';
import '../../domain/usecases/import_folder.dart';

enum HomeStatus { initial, loading, ready, error }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.selectedFolder,
    this.rootFolders = const [],
    this.error,
  });

  final HomeStatus status;
  final FolderEntity? selectedFolder;
  final List<FolderEntity> rootFolders;
  final String? error;

  @override
  List<Object?> get props => [status, selectedFolder, rootFolders, error];
}

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class ImportFolderPressed extends HomeEvent {
  const ImportFolderPressed();
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required this.importFolder,
    required this.getFolderSubfolders,
  }) : super(const HomeState()) {
    on<ImportFolderPressed>(_onImportFolderPressed);
  }

  final ImportFolderUseCase importFolder;
  final GetFolderSubfoldersUseCase getFolderSubfolders;

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
      final subfolders = await getFolderSubfolders(folder.path);
      emit(HomeState(
        status: HomeStatus.ready,
        selectedFolder: folder,
        rootFolders: subfolders,
      ));
    } catch (error) {
      emit(HomeState(status: HomeStatus.error, error: error.toString()));
    }
  }

  Future<List<FolderEntity>> loadSubfolders(String path) =>
      getFolderSubfolders(path);
}