class ApiError implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  const ApiError({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message'] ?? 'Unknown error',
      statusCode: json['statusCode'],
      data: json['data'],
    );
  }
}