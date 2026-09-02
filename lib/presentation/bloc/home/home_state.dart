part of 'home_bloc.dart';

enum HomeStatus { initial, loading, ready, error }

enum AudioStatus { idle, loading, ready, error }

enum MetadataStatus { idle, loading, ready }

/// The presentation state of the home screen.
class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.rootFolder,
    this.selectedFolder,
    this.rootFolders = const [],
    this.error,
    this.audioStatus = AudioStatus.idle,
    this.audioFiles = const [],
    this.audioError,
    this.pendingRenames = const {},
    this.pendingMetadataUpdates = const {},
    this.pendingDeletes = const {},
    this.isSaving = false,
    this.notice,
    this.selectedFilePath,
    this.selectedMetadata,
    this.metadataStatus = MetadataStatus.idle,
    this.precacheProgress,
    this.selectedCoverArt,
  });

  final HomeStatus status;
  final FolderEntity? rootFolder;
  final FolderEntity? selectedFolder;
  final List<FolderEntity> rootFolders;
  final String? error;
  final AudioStatus audioStatus;
  final List<AudioFileEntity> audioFiles;
  final String? audioError;
  final Map<String, String> pendingRenames;
  final Map<String, MetadataUpdateRequest> pendingMetadataUpdates;
  final Set<String> pendingDeletes;
  final bool isSaving;
  final String? notice;
  final String? selectedFilePath;
  final AudioMetadataEntity? selectedMetadata;
  final MetadataStatus metadataStatus;
  final PrecacheProgress? precacheProgress;
  final Uint8List? selectedCoverArt;

  static const Object _unset = Object();

  HomeState copyWith({
    HomeStatus? status,
    FolderEntity? rootFolder,
    FolderEntity? selectedFolder,
    List<FolderEntity>? rootFolders,
    String? error,
    AudioStatus? audioStatus,
    List<AudioFileEntity>? audioFiles,
    String? audioError,
    Map<String, String>? pendingRenames,
    Map<String, MetadataUpdateRequest>? pendingMetadataUpdates,
    Set<String>? pendingDeletes,
    bool? isSaving,
    Object? notice = _unset,
    String? selectedFilePath,
    AudioMetadataEntity? selectedMetadata,
    MetadataStatus? metadataStatus,
    Object? precacheProgress = _unset,
    Uint8List? selectedCoverArt,
    Object? clearSelection = _unset,
  }) {
    final shouldClear = identical(clearSelection, true);
    return HomeState(
      status: status ?? this.status,
      rootFolder: rootFolder ?? this.rootFolder,
      selectedFolder: selectedFolder ?? this.selectedFolder,
      rootFolders: rootFolders ?? this.rootFolders,
      error: error ?? this.error,
      audioStatus: audioStatus ?? this.audioStatus,
      audioFiles: audioFiles ?? this.audioFiles,
      audioError: audioError ?? this.audioError,
      pendingRenames: pendingRenames ?? this.pendingRenames,
      pendingMetadataUpdates:
          pendingMetadataUpdates ?? this.pendingMetadataUpdates,
      pendingDeletes: pendingDeletes ?? this.pendingDeletes,
      isSaving: isSaving ?? this.isSaving,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
      selectedFilePath:
          shouldClear ? null : (selectedFilePath ?? this.selectedFilePath),
      selectedMetadata:
          shouldClear ? null : (selectedMetadata ?? this.selectedMetadata),
      metadataStatus: shouldClear
          ? MetadataStatus.idle
          : (metadataStatus ?? this.metadataStatus),
      precacheProgress: identical(precacheProgress, _unset)
          ? this.precacheProgress
          : precacheProgress as PrecacheProgress?,
      selectedCoverArt:
          shouldClear ? null : (selectedCoverArt ?? this.selectedCoverArt),
    );
  }

  @override
  List<Object?> get props => [
        status,
        rootFolder,
        selectedFolder,
        rootFolders,
        error,
        audioStatus,
        audioFiles,
        audioError,
        pendingRenames,
        pendingMetadataUpdates,
        pendingDeletes,
        isSaving,
        notice,
        selectedFilePath,
        selectedMetadata,
        metadataStatus,
        precacheProgress,
        selectedCoverArt,
      ];
}
