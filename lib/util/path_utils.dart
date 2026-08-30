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

/// Swaps the two parts of a file name around its single hyphen,
/// returning the new full path. Returns null when the name does not
/// contain exactly one hyphen.
String? swapNamePath(String path) {
  final name = nameWithoutExtension(path);
  final firstIndex = name.indexOf('-');
  if (firstIndex == -1 || name.indexOf('-', firstIndex + 1) != -1) {
    return null;
  }
  final first = name.substring(0, firstIndex).trim();
  final second = name.substring(firstIndex + 1).trim();
  final extension = extensionFromPath(path);
  final dir = path.substring(0, path.length - nameFromPath(path).length);
  final swapped = '$second - $first';
  return '$dir$swapped${extension.isEmpty ? '' : '.$extension'}';
}