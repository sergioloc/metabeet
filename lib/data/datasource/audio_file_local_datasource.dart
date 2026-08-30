import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../domain/enum/audio_format.dart';
import '../../util/path_utils.dart';
import '../model/audio_file_model.dart';

/// Reads audio files and their cover art from disk.
abstract class AudioFileLocalDataSource {
  Future<List<AudioFileModel>> getAudioFiles(String path);

  Future<Uint8List?> getCoverArt(String path);
}

/// Reads cover art off the UI thread and caches recent results.
class AudioFileLocalDataSourceImpl implements AudioFileLocalDataSource {
  AudioFileLocalDataSourceImpl({int maxConcurrentReads = 4})
      : _maxConcurrentReads = maxConcurrentReads;

  final int _maxConcurrentReads;

  final Map<String, Future<Uint8List?>> _cache = <String, Future<Uint8List?>>{};
  final List<Future<void> Function()> _queue = [];
  int _activeReads = 0;

  static const int _maxCacheEntries = 300;

  @override
  Future<List<AudioFileModel>> getAudioFiles(String path) async {
    final files = <AudioFileModel>[];
    try {
      final entities =
          Directory(path).listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final format = AudioFormat.fromPath(entity.path);
          if (format != null) {
            files.add(AudioFileModel(
              name: nameFromPath(entity.path),
              path: entity.path,
              format: format,
            ));
          }
        }
      }
    } catch (_) {}
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  @override
  Future<Uint8List?> getCoverArt(String path) {
    final cached = _cache.remove(path);
    if (cached != null) {
      _cache[path] = cached;
      return cached;
    }

    final future = _enqueueRead(path);
    _cache[path] = future;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _enqueueRead(String path) {
    final completer = Completer<Uint8List?>();
    _queue.add(() {
      return _readCoverArtInIsolate(path).then(
        (bytes) => completer.complete(bytes),
        onError: (_) => completer.complete(null),
      );
    });
    _pumpQueue();
    return completer.future;
  }

  void _pumpQueue() {
    while (_activeReads < _maxConcurrentReads && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _activeReads++;
      task().whenComplete(() {
        _activeReads--;
        _pumpQueue();
      });
    }
  }

  Future<Uint8List?> _readCoverArtInIsolate(String path) {
    return Isolate.run(() {
      try {
        final metadata = readMetadata(File(path), getImage: true);
        final pictures = metadata.pictures;
        return pictures.isEmpty ? null : pictures.first.bytes;
      } catch (_) {
        return null;
      }
    });
  }
}