class CryptoException implements Exception {
  final String message;
  final dynamic originalError;

  const CryptoException(this.message, [this.originalError]);

  @override
  String toString() => 'CryptoException: $message';
}