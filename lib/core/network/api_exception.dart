class ApiException implements Exception {
  const ApiException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => message;
}
