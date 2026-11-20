/// Thrown when a file upload fails. [message] is already friendly.
class UploadException implements Exception {
  const UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
