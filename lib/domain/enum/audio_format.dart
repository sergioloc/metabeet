enum AudioFormat {
  mp3,
  flac,
  wav,
  ogg,
  aac,
  m4a,
  wma,
  aiff;

  static AudioFormat? fromPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp3':
        return AudioFormat.mp3;
      case 'flac':
        return AudioFormat.flac;
      case 'wav':
        return AudioFormat.wav;
      case 'ogg':
        return AudioFormat.ogg;
      case 'aac':
        return AudioFormat.aac;
      case 'm4a':
        return AudioFormat.m4a;
      case 'wma':
        return AudioFormat.wma;
      case 'aif' || 'aiff':
        return AudioFormat.aiff;
      default:
        return null;
    }
  }
}
