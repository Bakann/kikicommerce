import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Shared HTTP client provider. Lives in `core/network` (infrastructure), not in
/// the app composition root (`lib/app`), so feature modules can depend on it
/// without reaching into `lib/app`.
final httpClientProvider = Provider<http.Client>((ref) => http.Client());
