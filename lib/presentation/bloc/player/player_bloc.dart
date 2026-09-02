import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'player_event.dart';
part 'player_state.dart';

/// Owns a single [ap.AudioPlayer] and exposes playback state to the UI.
///
/// Display info (title/artist/cover art) is passed in with [PlayRequested]
/// because the player does not perform metadata reads itself; the caller
/// (the widget layer) already has access to that via the home bloc.
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  PlayerBloc() : super(const PlayerState()) {
    on<PlayRequested>(_onPlayRequested);
    on<PauseRequested>(_onPauseRequested);
    on<ResumeRequested>(_onResumeRequested);
    on<TogglePlayPause>(_onTogglePlayPause);
    on<SeekRequested>(_onSeekRequested);
    on<StopRequested>(_onStopRequested);
    on<_PlaybackStateChanged>(_onPlaybackStateChanged);
    on<_PositionChanged>(_onPositionChanged);
    on<_DurationChanged>(_onDurationChanged);
    _initPlayerListeners();
  }

  final ap.AudioPlayer _player = ap.AudioPlayer();

  /// Drives smooth position updates while playing.
  Timer? _ticker;
  Duration _tickPosition = Duration.zero;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _tickPosition += const Duration(milliseconds: 250);
      if (!isClosed) {
        add(_PositionChanged(_tickPosition));
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _initPlayerListeners() {
    _player.onPlayerStateChanged
        .listen((playerState) => add(_PlaybackStateChanged(playerState)));
    _player.onPositionChanged.listen((position) {
      if (!isClosed) _tickPosition = position;
    });
    _player.onDurationChanged
        .listen((duration) => add(_DurationChanged(duration)));
  }

  void _onPlaybackStateChanged(
    _PlaybackStateChanged event,
    Emitter<PlayerState> emit,
  ) {
    switch (event.playerState) {
      case ap.PlayerState.playing:
        _startTicker();
        emit(state.copyWith(isPlaying: true));
      case ap.PlayerState.paused:
      case ap.PlayerState.stopped:
        _stopTicker();
        emit(state.copyWith(isPlaying: false));
      case ap.PlayerState.completed:
        _stopTicker();
        _tickPosition = Duration.zero;
        emit(state.copyWith(isPlaying: false, position: Duration.zero));
      case ap.PlayerState.disposed:
        break;
    }
  }

  void _onPositionChanged(
    _PositionChanged event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(position: event.position));
  }

  void _onDurationChanged(
    _DurationChanged event,
    Emitter<PlayerState> emit,
  ) {
    if (event.duration != null) {
      emit(state.copyWith(duration: event.duration));
    }
  }

  Future<void> _onPlayRequested(
    PlayRequested event,
    Emitter<PlayerState> emit,
  ) async {
    // If the same track is requested, just resume playing.
    if (state.currentPath == event.path) {
      await _player.resume();
      emit(state.copyWith(isPlaying: true));
      return;
    }

    emit(PlayerState(
      currentPath: event.path,
      title: event.title,
      artist: event.artist,
      coverArt: event.coverArt,
      position: Duration.zero,
      duration: null,
      isPlaying: false,
    ));
    _tickPosition = Duration.zero;
    try {
      await _player.stop();
      await _player.setSource(ap.DeviceFileSource(event.path));
      await _player.resume();
    } catch (error) {
      debugPrint('[PlayerBloc] error playing ${event.path}: $error');
      _stopTicker();
      if (!isClosed) {
        emit(PlayerState());
      }
    }
  }

  Future<void> _onPauseRequested(
    PauseRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasSong) return;
    await _player.pause();
    _stopTicker();
    emit(state.copyWith(isPlaying: false));
  }

  Future<void> _onResumeRequested(
    ResumeRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasSong) return;
    await _player.resume();
    _startTicker();
    emit(state.copyWith(isPlaying: true));
  }

  Future<void> _onTogglePlayPause(
    TogglePlayPause event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasSong) return;
    if (state.isPlaying) {
      await _player.pause();
      _stopTicker();
      emit(state.copyWith(isPlaying: false));
    } else {
      // Restart from the top if the previous playback completed.
      if (state.position >= (state.duration ?? Duration.zero) &&
          (state.duration ?? Duration.zero) > Duration.zero) {
        _tickPosition = Duration.zero;
        emit(state.copyWith(position: Duration.zero));
        await _player.seek(Duration.zero);
      }
      await _player.resume();
      _startTicker();
      emit(state.copyWith(isPlaying: true));
    }
  }

  Future<void> _onSeekRequested(
    SeekRequested event,
    Emitter<PlayerState> emit,
  ) async {
    if (!state.hasSong) return;
    final target = event.position;
    _tickPosition = target;
    emit(state.copyWith(position: target));
    await _player.seek(target);
  }

  Future<void> _onStopRequested(
    StopRequested event,
    Emitter<PlayerState> emit,
  ) async {
    await _player.stop();
    _stopTicker();
    _tickPosition = Duration.zero;
    emit(const PlayerState());
  }

  @override
  Future<void> close() async {
    _stopTicker();
    await _player.dispose();
    await super.close();
  }
}
