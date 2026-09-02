part of 'player_bloc.dart';

/// Represents the playback state of the audio player.
class PlayerState extends Equatable {
  const PlayerState({
    this.currentPath,
    this.title,
    this.artist,
    this.coverArt,
    this.position = Duration.zero,
    this.duration,
    this.isPlaying = false,
  });

  /// Absolute path of the currently loaded track, or null if none.
  final String? currentPath;

  /// Display title of the loaded track.
  final String? title;

  /// Display artist of the loaded track.
  final String? artist;

  /// Cover art bytes of the loaded track.
  final Uint8List? coverArt;

  /// Current playback position.
  final Duration position;

  /// Total duration of the loaded track, or null while unknown/loading.
  final Duration? duration;

  /// Whether audio is currently playing.
  final bool isPlaying;

  /// True when a track is loaded (the bottom bar should be visible).
  bool get hasSong => currentPath != null;

  PlayerState copyWith({
    String? currentPath,
    String? title,
    String? artist,
    Uint8List? coverArt,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
  }) {
    return PlayerState(
      currentPath: currentPath ?? this.currentPath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverArt: coverArt ?? this.coverArt,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  List<Object?> get props => [
        currentPath,
        title,
        artist,
        coverArt,
        position,
        duration,
        isPlaying,
      ];
}
