sealed class AppException implements Exception {
  const AppException(this.message, {this.technicalDetail});

  final String message;
  final String? technicalDetail;

  @override
  String toString() => message;
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.technicalDetail});
}

final class BackupException extends AppException {
  const BackupException(super.message, {super.technicalDetail});
}
