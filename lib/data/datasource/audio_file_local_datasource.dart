import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';

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
  /// [onProgress] is called as files are processed.
  Future<void> precache(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  });

  Future<Uint8List?> getCoverArt(String path);

  Future<AudioMetadataEntity?> getMetadata(String path);

  Future<void> renameFiles(List<FileRenameRequest> requests);

  Future<void> updateMetadataFromFiles(List<MetadataUpdateRequest> requests);

  /// Permanently deletes the audio files at [paths], removing any cached data.
  Future<void> deleteFiles(List<String> paths);
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
      debugPrint('[getAudioFiles] scanning $path');
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
    } catch (e) {
      debugPrint('[getAudioFiles] error scanning $path: $e');
    }
    debugPrint('[getAudioFiles] found ${files.length} files under $path');
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  @override
  Future<void> precache(
    String path, {
    void Function(PrecacheProgress progress)? onProgress,
  }) async {
    final files = await getAudioFiles(path);
    final paths = files.map((f) => f.path).toList();
    final total = paths.length;
    var done = 0;

    Future<void> processBatch(List<String> batch) async {
      debugPrint('[precache] reading batch of ${batch.length}, '
          'first=${batch.first.trim()}');
      final results = await _runBatchInIsolate(batch);
      for (final r in results) {
        final path = r['path']! as String;
        final metadata = r['metadata'] as AudioMetadataEntity?;
        _metadataCache[path] = metadata;
        _coverArtCache[path] = metadata?.coverArt;
      }
      done += batch.length;
      onProgress?.call(PrecacheProgress(done: done, total: total));
    }

    // Process files in batches; each batch is read in a dedicated isolate, and
    // several batches run concurrently to keep all cores busy.
    const batchSize = 12;
    final batches = <List<String>>[];
    for (var i = 0; i < paths.length; i += batchSize) {
      final end =
          (i + batchSize) > paths.length ? paths.length : (i + batchSize);
      batches.add(paths.sublist(i, end));
    }

    await _runBounded(batches, processBatch);
  }

  Future<void> _runBounded<T>(
    List<T> items,
    Future<void> Function(T item) task,
  ) async {
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final current = index++;
        if (current >= items.length) return;
        await task(items[current]);
      }
    }

    final count =
        _maxConcurrentReads < items.length ? _maxConcurrentReads : items.length;
    await Future.wait([for (var i = 0; i < count; i++) worker()]);
  }

  Future<List<Map<String, Object?>>> _runBatchInIsolate(
    List<String> batch,
  ) async {
    final resultsPort = ReceivePort();
    final errorPort = ReceivePort();
    late final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _batchEntrypoint,
        (batch, resultsPort.sendPort, errorPort.sendPort),
        onError: errorPort.sendPort,
        errorsAreFatal: true,
      );
    } catch (e) {
      resultsPort.close();
      errorPort.close();
      debugPrint('[precache] isolate spawn failed: $e');
      rethrow;
    }

    final completer = Completer<List<Map<String, Object?>>>();
    errorPort.listen((message) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Isolate error: $message'));
      }
    });
    resultsPort.listen((message) {
      if (!completer.isCompleted) {
        completer.complete((message as List).cast<Map<String, Object?>>());
      }
    });

    try {
      return await completer.future;
    } finally {
      resultsPort.close();
      errorPort.close();
      isolate.kill(priority: Isolate.immediate);
    }
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
      if (result != null) _coverArtCache[path] = result.coverArt;
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
        final metadata = readMetadata(File(path), getImage: true);
        final artist = _hasCustomArtist(format)
            ? _resolveArtist(path, format, metadata.artist)
            : metadata.artist;
        final duration = metadata.duration;
        final pictures = metadata.pictures;
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
          coverArt: pictures.isEmpty ? null : pictures.first.bytes,
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
        if (format == AudioFormat.wav) {
          _writeWavMetadata(
            File(request.path),
            title: request.title,
            artist: request.artist,
          );
          continue;
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

  @override
  Future<void> deleteFiles(List<String> paths) async {
    final existing = <String>[];
    for (final path in paths) {
      if (File(path).existsSync()) existing.add(path);
    }
    for (final path in existing) {
      File(path).deleteSync();
      _metadataCache.remove(path);
      _coverArtCache.remove(path);
    }
  }
}

/// Whether [format] supports writing metadata via `updateMetadata`.
bool _isWritable(AudioFormat format) =>
    format == AudioFormat.mp3 ||
    format == AudioFormat.flac ||
    format == AudioFormat.wav ||
    format == AudioFormat.m4a;

/// Rewrites a WAV file's metadata, storing [title] and [artist] in an
/// `LIST/INFO` chunk (INAM/IART).
///
/// The upstream `RiffWriter` mishandles large `data` chunks (it builds a full
/// in-memory copy of the file and can throw on big WAVs). This implementation
/// streams chunk-by-chunk with a bounded buffer and writes to a temporary file
/// that atomically replaces the original, so a large WAV neither crashes the
/// app nor risks being left corrupted.
void _writeWavMetadata(
  File file, {
  required String? title,
  required String? artist,
}) {
  final infoData = BytesBuilder();
  if (title != null && title.trim().isNotEmpty) {
    _writeWavInfoSubchunk(infoData, 'INAM', title);
  }
  if (artist != null && artist.trim().isNotEmpty) {
    _writeWavInfoSubchunk(infoData, 'IART', artist);
  }
  final infoBytes = infoData.takeBytes();
  if (infoBytes.isEmpty) return;

  final tmp = File('${file.path}.metabeet.tmp');
  final input = file.openSync();
  final output = tmp.openSync(mode: FileMode.write);
  var outputOpen = true;

  // ISO-8859-1 is what WAV INFO chunks use for human-readable text.
  const latin1 = AsciiCodec(allowInvalid: true);
  final infoChunk = infoBytes;
  final chunkHeader = Uint8List(8);
  var bodyBytes = 0; // bytes written after the 12-byte RIFF header
  var infoWritten = false;

  try {
    final headerBuf = Uint8List(12);
    final headerRead = input.readIntoSync(headerBuf);
    if (headerRead < 12 ||
        latin1.decode(headerBuf.sublist(0, 4)) != 'RIFF' ||
        latin1.decode(headerBuf.sublist(8, 12)) != 'WAVE') {
      throw StateError('Not a RIFF/WAVE file: ${file.path}');
    }

    // Write the header now; the RIFF size field is patched at the end once the
    // total body length is known.
    output.writeFromSync(headerBuf);

    while (true) {
      final read = input.readIntoSync(chunkHeader);
      if (read == 0) break;
      if (read < 8) {
        output.writeFromSync(chunkHeader, 0, read);
        bodyBytes += read;
        break;
      }
      final id = latin1.decode(chunkHeader.sublist(0, 4));
      final size = _readUint32LE(chunkHeader, 4);

      if (id == 'LIST') {
        if (!infoWritten) {
          // Replace the first LIST with our fresh INFO list and skip the old
          // payload (including any trailing LIST/INFO the source may have).
          final payload = BytesBuilder()
            ..add(ascii.encode('INFO'))
            ..add(infoChunk);
          final chunkSize = payload.length;
          output.writeFromSync(ascii.encode('LIST'));
          output.writeFromSync(_uint32LE(chunkSize));
          output.writeFromSync(payload.takeBytes());
          bodyBytes += 8 + chunkSize;
          if (chunkSize.isOdd) {
            output.writeByteSync(0);
            bodyBytes += 1;
          }
          if (size >= 4) {
            _skipWavInput(input, size - 4);
            if ((size - 4).isOdd) {
              _skipWavInput(input, 1); // padding byte
            }
          }
          infoWritten = true;
        } else {
          // Duplicate LIST in the source: skip it verbatim.
          _skipWavInput(input, size);
          if (size.isOdd) _skipWavInput(input, 1);
        }
      } else {
        output.writeFromSync(chunkHeader);
        bodyBytes += 8;
        bodyBytes += _copyWavPayload(input, output, size);
      }
    }

    // No LIST was found: append our INFO list at the end.
    if (!infoWritten) {
      final payload = BytesBuilder()
        ..add(ascii.encode('INFO'))
        ..add(infoChunk);
      final chunkSize = payload.length;
      output.writeFromSync(ascii.encode('LIST'));
      output.writeFromSync(_uint32LE(chunkSize));
      output.writeFromSync(payload.takeBytes());
      bodyBytes += 8 + chunkSize;
      if (chunkSize.isOdd) {
        output.writeByteSync(0);
      }
    }

    // Patch RIFF chunk size = file size - 8 = bodyBytes + 4.
    output.setPositionSync(4);
    output.writeFromSync(_uint32LE(bodyBytes + 4));
    output.flushSync();
  } finally {
    input.closeSync();
    if (outputOpen) {
      outputOpen = false;
      output.closeSync();
    }
  }

  tmp.renameSync(file.path);
}

/// Appends an INFO subchunk (id, size, data, padding) to [builder].
void _writeWavInfoSubchunk(BytesBuilder builder, String id, String text) {
  final value = const AsciiCodec(allowInvalid: true).encode(text);
  builder.add(ascii.encode(id));
  builder.add(_uint32LE(value.length));
  builder.add(value);
  if (value.length.isOdd) {
    builder.addByte(0);
  }
}

/// Streams [size] bytes from [input] to [output] in bounded reads, returning
/// the number of body bytes written (payload + padding byte when odd).
int _copyWavPayload(RandomAccessFile input, RandomAccessFile output, int size) {
  final buffer = Uint8List(65536);
  var remaining = size;
  var written = 0;
  while (remaining > 0) {
    final chunk = remaining < buffer.length ? remaining : buffer.length;
    final read = input.readIntoSync(buffer, 0, chunk);
    if (read == 0) break; // truncated file
    output.writeFromSync(buffer, 0, read);
    written += read;
    remaining -= read;
    if (remaining == 0 && size.isOdd) {
      output.writeByteSync(0);
      written += 1;
    }
  }
  return written;
}

void _skipWavInput(RandomAccessFile input, int bytes) {
  if (bytes <= 0) return;
  final buffer = Uint8List(65536);
  var remaining = bytes;
  while (remaining > 0) {
    final chunk = remaining < buffer.length ? remaining : buffer.length;
    final read = input.readIntoSync(buffer, 0, chunk);
    if (read == 0) break;
    remaining -= read;
  }
}

Uint8List _uint32LE(int value) {
  return Uint8List.fromList([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

/// Resolves the artist to use for a file.
///
/// For MP3 the track artist (TPE1) is used, both for display and for the sync
/// check. For FLAC/OGG the album artist tag is preferred (as `readMetadata`
/// merges `ARTIST` and `ALBUMARTIST` into a single list, the raw Vorbis
/// comments are read to isolate the album artist); when no album artist tag is
/// present the track artist read by [fallbackArtist] is used instead. The value
/// is trimmed, and an empty value resolves to null. Returns null when the
/// format has no dedicated artist tag.
String? _resolveArtist(
  String path,
  AudioFormat format,
  String? fallbackArtist,
) {
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
      final albumArtist = _vorbisAlbumArtist(path);
      if (albumArtist != null && albumArtist.isNotEmpty) return albumArtist;
      final fallback = fallbackArtist?.trim();
      return fallback == null || fallback.isEmpty ? null : fallback;
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

/// Entrypoint for an isolate that reads a batch of audio files and replies
/// with their metadata. Everything here is top-level so no unsendable state is
/// captured across the isolate boundary.
void _batchEntrypoint(
  (List<String>, SendPort, SendPort) args,
) {
  final (paths, resultsPort, _) = args;
  final results = _readBatch(paths);
  resultsPort.send(results);
}

/// Reads a batch of audio files off the main isolate, returning their
/// metadata (with embedded cover art). Each file touches the disk once. Values
/// cross the isolate boundary either as primitives or via [Uint8List], which
/// Dart's isolate library can transfer.
List<Map<String, Object?>> _readBatch(List<String> paths) {
  final results = <Map<String, Object?>>[];
  for (final path in paths) {
    final format = AudioFormat.fromPath(path);
    if (format == null) {
      results.add({'path': path, 'metadata': null});
      continue;
    }
    try {
      final metadata = readMetadata(File(path), getImage: true);
      final artist = _hasCustomArtist(format)
          ? _resolveArtist(path, format, metadata.artist)
          : metadata.artist;
      final duration = metadata.duration;
      final pictures = metadata.pictures;
      results.add({
        'path': path,
        'metadata': AudioMetadataEntity(
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
          coverArt: pictures.isEmpty ? null : pictures.first.bytes,
        ),
      });
    } catch (_) {
      results.add({'path': path, 'metadata': null});
    }
  }
  return results;
}
