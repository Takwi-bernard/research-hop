/// An error whose [message] is already written for the person to read.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
