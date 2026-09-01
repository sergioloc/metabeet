/// The phase of the folder precache currently running.
enum PrecachePhase {
  /// Reading each file's metadata tags (title, artist, album, ...).
  metadata,

  /// Reading each file's embedded cover art.
  cover,
}

/// Snapshot of the current precache progress.
class PrecacheProgress {
  const PrecacheProgress({
    required this.phase,
    required this.done,
    required this.total,
  });

  final PrecachePhase phase;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

/// Wall-clock measurement of how long each precache phase took.
class PrecacheTimings {
  const PrecacheTimings({required this.metadataMs, required this.coverMs});

  final int metadataMs;
  final int coverMs;

  int get totalMs => metadataMs + coverMs;
}
