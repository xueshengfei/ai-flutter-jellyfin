/// Base exception for all Jellyfin SDK errors
class JellyfinException implements Exception {
  /// Error message
  final String message;

  /// Original error (if any)
  final Object? cause;

  /// Stack trace (if available)
  final StackTrace? stackTrace;

  const JellyfinException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('JellyfinException: $message');
    if (cause != null) {
      buffer.writeln('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
