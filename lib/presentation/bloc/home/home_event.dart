part of 'home_bloc.dart';

/// Events that drive the [HomeBloc].
sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// The user wants to import/select a folder.
class ImportFolderPressed extends HomeEvent {
  const ImportFolderPressed();
}

/// A folder in the tree was selected.
class FolderSelected extends HomeEvent {
  const FolderSelected(this.folder);

  final FolderEntity folder;

  @override
  List<Object?> get props => [folder];
}

/// The user wants to swap the title and artist of a file.
class SwapRequested extends HomeEvent {
  const SwapRequested(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// The user wants to rename a file.
class RenameFileRequested extends HomeEvent {
  const RenameFileRequested(this.path, this.newName);

  final String path;
  final String newName;

  @override
  List<Object?> get props => [path, newName];
}

/// Sync metadata from the "Title - Artist" file name.
class SyncMetadataFromName extends HomeEvent {
  const SyncMetadataFromName(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Mark a file for deletion (applied on save).
class DeleteRequested extends HomeEvent {
  const DeleteRequested(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Remove a file from the pending deletions.
class RestoreRequested extends HomeEvent {
  const RestoreRequested(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Apply all pending renames and metadata updates.
class SavePendingRenames extends HomeEvent {
  const SavePendingRenames();
}

/// A song was selected to show its details.
class FileSelected extends HomeEvent {
  const FileSelected(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// The details panel was closed.
class FileDetailClosed extends HomeEvent {
  const FileDetailClosed();
}

/// A transient notice has been presented.
class NoticeShown extends HomeEvent {
  const NoticeShown();
}
