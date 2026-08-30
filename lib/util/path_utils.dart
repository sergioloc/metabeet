String nameFromPath(String path) {
  final segments = path
      .split(RegExp(r'[\\/]'))
      .where((segment) => segment.isNotEmpty)
      .toList();
  return segments.isEmpty ? path : segments.last;
}

String nameWithoutExtension(String path) {
  final name = nameFromPath(path);
  final index = name.lastIndexOf('.');
  return index <= 0 ? name : name.substring(0, index);
}

String extensionFromPath(String path) {
  final name = nameFromPath(path);
  final index = name.lastIndexOf('.');
  return index <= 0 ? '' : name.substring(index + 1);
}