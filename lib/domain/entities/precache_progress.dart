/// Snapshot of the current folder precache progress.
class PrecacheProgress {
  const PrecacheProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}
