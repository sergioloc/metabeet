class MetadataUpdateRequest {
  const MetadataUpdateRequest({
    required this.path,
    required this.title,
    required this.artist,
  });

  final String path;
  final String title;
  final String artist;
}