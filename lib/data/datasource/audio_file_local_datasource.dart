import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../../domain/entities/audio_metadata_entity.dart';
import '../../domain/entities/file_rename_request.dart';
import '../../domain/entities/metadata_update_request.dart';
import '../../domain/entities/precache_progress.dart';
import '../../domain/enum/audio_format.dart';
import '../../utils/path_utils.dart';
import '../model/audio_file_model.dart';

/// Reads audio files and their cover art from disk.
abstract class AudioFileLocalDataSource {
  Future<List<AudioFileModel>> getAudioFiles(String path);

  /// Eagerly loads metadata and cover art for every audio file under [path]
  /// into memory, so later calls to [getMetadata]/[getCoverArt] are instant.
  ///
  /// Metadata tags and cover art are read in separate phases so the caller can
  /// track progress and measure where the time is spent. [onProgress] is called
  /// as work advances and the returned [PrecacheTimings] reports how long each
  /// phase took.
  Future<PrecacheTimings> precache(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  });

  Future<Uint8List?> getCoverArt(String path);

  Future<AudioMetadataEntity?> getMetadata(String path);

  Future<void> renameFiles(List<FileRenameRequest> requests);

  Future<void> updateMetadataFromFiles(List<MetadataUpdateRequest> requests);
}

/// Reads audio files and their cover art off the UI thread, caching every
/// result in memory. Once a folder has been [precache]d, reads are served
/// straight from the cache.
class AudioFileLocalDataSourceImpl implements AudioFileLocalDataSource {
  AudioFileLocalDataSourceImpl({int maxConcurrentReads = 4})
      : _maxConcurrentReads = maxConcurrentReads;

  final int _maxConcurrentReads;

  final Map<String, AudioMetadataEntity?> _metadataCache = {};
  final Map<String, Uint8List?> _coverArtCache = {};
  final Map<String, Future<AudioMetadataEntity?>> _metadataInFlight = {};
  final Map<String, Future<Uint8List?>> _coverArtInFlight = {};

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
  Future<PrecacheTimings> precache(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  }) async {
    final files = await getAudioFiles(path);
    final paths = files.map((f) => f.path).toList();
    final total = paths.length;

    final metadataWatch = Stopwatch()..start();
    var metadataDone = 0;
    await _runBounded(paths, (p) async {
      await getMetadata(p);
      metadataDone++;
      onProgress?.call(PrecacheProgress(
        phase: PrecachePhase.metadata,
        done: metadataDone,
        total: total,
      ));
    });
    metadataWatch.stop();

    onProgress?.call(PrecacheProgress(
      phase: PrecachePhase.cover,
      done: 0,
      total: total,
    ));
    final coverWatch = Stopwatch()..start();
    var coverDone = 0;
    await _runBounded(paths, (p) async {
      await getCoverArt(p);
      coverDone++;
      onProgress?.call(PrecacheProgress(
        phase: PrecachePhase.cover,
        done: coverDone,
        total: total,
      ));
    });
    coverWatch.stop();

    return PrecacheTimings(
      metadataMs: metadataWatch.elapsedMilliseconds,
      coverMs: coverWatch.elapsedMilliseconds,
    );
  }

  Future<void> _runBounded(
    List<String> paths,
    Future<void> Function(String path) task,
  ) async {
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final current = index++;
        if (current >= paths.length) return;
        await task(paths[current]);
      }
    }

    final count =
        _maxConcurrentReads < paths.length ? _maxConcurrentReads : paths.length;
    await Future.wait([for (var i = 0; i < count; i++) worker()]);
  }

  @override
  Future<Uint8List?> getCoverArt(String path) async {
    if (_coverArtCache.containsKey(path)) {
      return _coverArtCache[path];
    }

    final inFlight = _coverArtInFlight[path];
    if (inFlight != null) return inFlight;

    final future = _enqueueCoverRead(path);
    _coverArtInFlight[path] = future;
    try {
      final bytes = await future;
      _coverArtCache[path] = bytes;
      return bytes;
    } finally {
      _coverArtInFlight.remove(path);
    }
  }

  Future<Uint8List?> _enqueueCoverRead(String path) {
    final completer = Completer<Uint8List?>();
    _enqueueRead(() => _readCoverArtInIsolate(path).then(
          (bytes) => completer.complete(bytes),
          onError: (_) => completer.complete(null),
        ));
    return completer.future;
  }

  void _enqueueRead(Future<void> Function() task) {
    _pendingReads.add(task);
    _pumpQueue();
  }

  final List<Future<void> Function()> _pendingReads = [];
  int _activeReads = 0;

  void _pumpQueue() {
    while (_activeReads < _maxConcurrentReads && _pendingReads.isNotEmpty) {
      final task = _pendingReads.removeAt(0);
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

  @override
  Future<AudioMetadataEntity?> getMetadata(String path) async {
    if (_metadataCache.containsKey(path)) return _metadataCache[path];

    final inFlight = _metadataInFlight[path];
    if (inFlight != null) return inFlight;

    final future = _readMetadata(path);
    _metadataInFlight[path] = future;
    try {
      final result = await future;
      _metadataCache[path] = result;
      return result;
    } finally {
      _metadataInFlight.remove(path);
    }
  }

  Future<AudioMetadataEntity?> _readMetadata(String path) {
    final format = AudioFormat.fromPath(path);
    if (format == null) return Future.value(null);
    return Isolate.run(() {
      try {
        final metadata = readMetadata(File(path), getImage: false);
        final artist = _hasCustomArtist(format)
            ? _resolveArtist(path, format)
            : metadata.artist;
        final duration = metadata.duration;
        return AudioMetadataEntity(
          path: path,
          name: nameFromPath(path),
          format: format,
          title: metadata.title,
          artist: artist,
          album: metadata.album,
          genre: metadata.genres.isEmpty ? null : metadata.genres.first,
          year: metadata.year?.year,
          track: metadata.trackNumber,
          duration:
              duration != null && duration > Duration.zero ? duration : null,
          bitrate: metadata.bitrate,
          sampleRate: metadata.sampleRate,
          coverArt: null,
        );
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<void> renameFiles(List<FileRenameRequest> requests) async {
    final sources = {for (final r in requests) r.oldPath};
    final targets = <String>{};
    for (final r in requests) {
      if (r.oldPath == r.newPath) continue;
      if (!targets.add(r.newPath)) {
        throw StateError('Duplicate target path: ${r.newPath}');
      }
      if (File(r.newPath).existsSync() && !sources.contains(r.newPath)) {
        throw StateError('Target already exists: ${r.newPath}');
      }
    }

    final renames = <({String oldPath, String tempPath, String newPath})>[];
    for (var i = 0; i < requests.length; i++) {
      final r = requests[i];
      if (r.oldPath == r.newPath) continue;
      renames.add((
        oldPath: r.oldPath,
        tempPath: '${r.oldPath}.swap.tmp.$i',
        newPath: r.newPath,
      ));
    }

    final done = <({String oldPath, String tempPath, String newPath})>[];
    try {
      for (final r in renames) {
        if (!File(r.oldPath).existsSync()) {
          throw StateError('Source not found: ${r.oldPath}');
        }
        File(r.oldPath).renameSync(r.tempPath);
        done.add(r);
      }
      for (final r in done) {
        File(r.tempPath).renameSync(r.newPath);
      }
    } catch (error) {
      for (final r in done) {
        final tempFile = File(r.tempPath);
        if (tempFile.existsSync()) {
          tempFile.renameSync(r.oldPath);
        }
      }
      rethrow;
    }

    for (final r in done) {
      _metadataCache.remove(r.oldPath);
      _metadataCache.remove(r.newPath);
      _coverArtCache.remove(r.oldPath);
      _coverArtCache.remove(r.newPath);
    }
  }

  @override
  Future<void> updateMetadataFromFiles(
    List<MetadataUpdateRequest> requests,
  ) async {
    await Isolate.run(() {
      for (final request in requests) {
        final format = AudioFormat.fromPath(request.path);
        if (format == null || !_isWritable(format)) {
          throw StateError(
            'Metadata writing is not supported for ${request.path}',
          );
        }
        updateMetadata(File(request.path), (metadata) {
          metadata
            ..setTitle(request.title)
            ..setArtist(request.artist);
        });
      }
    });

    for (final request in requests) {
      _metadataCache.remove(request.path);
      _coverArtCache.remove(request.path);
    }
  }
}

/// Whether [format] supports writing metadata via `updateMetadata`.
bool _isWritable(AudioFormat format) =>
    format == AudioFormat.mp3 ||
    format == AudioFormat.flac ||
    format == AudioFormat.wav ||
    format == AudioFormat.m4a;

/// Resolves the artist to use for a file.
///
/// For MP3 the track artist (TPE1) is used, both for display and for the sync
/// check. For FLAC/OGG the album artist tag is preferred, but `readMetadata`
/// merges `ARTIST` and `ALBUMARTIST` into a single list so the raw Vorbis
/// comments are read to isolate the album artist. The value is trimmed, and an
/// empty value resolves to null. Returns null when the format has no dedicated
/// artist tag.
String? _resolveArtist(String path, AudioFormat format) {
  switch (format) {
    case AudioFormat.mp3:
      try {
        final tag = readAllMetadata(File(path));
        if (tag is Mp3Metadata) {
          final artist = tag.leadPerformer;
          final trimmed = artist?.trim();
          return trimmed == null || trimmed.isEmpty ? null : trimmed;
        }
      } catch (_) {}
      return null;
    case AudioFormat.flac:
    case AudioFormat.ogg:
      return _vorbisAlbumArtist(path);
    default:
      return null;
  }
}

/// Whether this format has dedicated artist handling in [_resolveArtist].
bool _hasCustomArtist(AudioFormat format) =>
    format == AudioFormat.mp3 ||
    format == AudioFormat.flac ||
    format == AudioFormat.ogg;

String? _decodeUtf8Bytes(List<int> bytes) {
  try {
    final decoded = utf8.decode(bytes, allowMalformed: true);
    return decoded == '' ? null : decoded;
  } catch (_) {
    return null;
  }
}

int _readUint32LE(List<int> bytes, int offset) {
  if (offset + 4 > bytes.length) return -1;
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

/// Reads the value of the first Vorbis comment whose key matches [targets],
/// searching a bounded leading region of the file.
String? _vorbisCommentValue(String path, List<String> targets) {
  try {
    final file = File(path);
    // Vorbis comments live near the start of FLAC/OGG files. A generous
    // bounded read covers them without loading the whole (possibly large)
    // audio file.
    final length = file.lengthSync();
    final readLength = length < 1 << 18 ? length : 1 << 18;
    final raf = file.openSync();
    final bytes = raf.readSync(readLength);
    raf.closeSync();
    final lower = utf8.decode(bytes, allowMalformed: true).toLowerCase();
    for (final target in targets) {
      final keyIndex = lower.indexOf(target);
      if (keyIndex == -1) continue;
      // Vorbis comments store each entry as a 4-byte little-endian length
      // followed by the whole "KEY=value" bytes. Recover the value length by
      // subtracting the key (including the '=') from the entry length.
      final lengthOffset = keyIndex - 4;
      final entryLength = _readUint32LE(bytes, lengthOffset);
      final valueLength = entryLength - target.length;
      if (entryLength <= 0 || valueLength <= 0) continue;
      final valueOffset = keyIndex + target.length;
      final valueBytes = bytes.sublist(valueOffset, valueOffset + valueLength);
      final value = _decodeUtf8Bytes(valueBytes);
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
  } catch (_) {}
  return null;
}

String? _vorbisAlbumArtist(String path) => _vorbisCommentValue(
    path, ['albumartist=', 'album_artist=', 'album artist=']);
