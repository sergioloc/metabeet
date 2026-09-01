import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../enum/audio_format.dart';

class AudioMetadataEntity extends Equatable {
  const AudioMetadataEntity({
    required this.path,
    required this.name,
    required this.format,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.track,
    this.duration,
    this.bitrate,
    this.sampleRate,
    this.coverArt,
  });

  final String path;
  final String name;
  final AudioFormat format;
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? track;
  final Duration? duration;
  final int? bitrate;
  final int? sampleRate;
  final Uint8List? coverArt;

  @override
  List<Object?> get props => [path];
}
