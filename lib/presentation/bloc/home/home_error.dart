// ignore_for_file: constant_identifier_names

/// User-facing errors raised by the home feature.
enum HomeError {
  /// An unexpected error happened while processing the request.
  ERROR;

  String get message => switch (this) {
        HomeError.ERROR => 'An unexpected error occurred',
      };
}
