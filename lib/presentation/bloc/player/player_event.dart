part of 'player_bloc.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

/// Loads and starts playing the given track, optionally with display info.
class PlayRequested extends PlayerEvent {
  PlayRequested({
    required this.path,
    this.title,
    this.artist,
    this.coverArt,
  });

  final String path;
  final String? title;
  final String? artist;
  final Uint8List? coverArt;
}

/// Pauses playback if it is running.
class PauseRequested extends PlayerEvent {
  const PauseRequested();
}

/// Resumes playback if it is paused.
class ResumeRequested extends PlayerEvent {
  const ResumeRequested();
}

/// Toggles between playing and paused.
class TogglePlayPause extends PlayerEvent {
  const TogglePlayPause();
}

/// Seeks to the given position.
class SeekRequested extends PlayerEvent {
  SeekRequested(this.position);

  final Duration position;
}

/// Stops playback and clears the loaded track.
class StopRequested extends PlayerEvent {
  const StopRequested();
}

/// Internal: mirrors a player state change from the underlying [ap.AudioPlayer].
class _PlaybackStateChanged extends PlayerEvent {
  _PlaybackStateChanged(this.playerState);

  final ap.PlayerState playerState;
}

/// Internal: advances or updates the current playback position.
class _PositionChanged extends PlayerEvent {
  _PositionChanged(this.position);

  final Duration position;
}

/// Internal: reports the total duration of the loaded track.
class _DurationChanged extends PlayerEvent {
  _DurationChanged(this.duration);

  final Duration? duration;
}
