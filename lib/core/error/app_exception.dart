sealed class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode});
}

class ApiException extends AppException {
  final Object? data;

  const ApiException(super.message, {super.statusCode, this.data});

  String? get code {
    final data = this.data;
    if (data is! Map<Object?, Object?>) {
      return null;
    }

    final direct = data['code'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }

    final nested = data['data'];
    if (nested is Map<Object?, Object?>) {
      final nestedCode = nested['code'];
      if (nestedCode is String && nestedCode.isNotEmpty) {
        return nestedCode;
      }
    }

    return null;
  }
}
