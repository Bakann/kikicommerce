import '../../application/admin/admin_auth_repository.dart';
import '../admin_client.dart';

class PocketBaseAdminAuthRepository implements AdminAuthRepository {
  final String baseUrl;

  const PocketBaseAdminAuthRepository({required this.baseUrl});

  @override
  Future<String> authenticateUser({
    required String email,
    required String password,
  }) {
    final client = PocketBaseAdminClient(baseUrl: baseUrl);
    return client.authenticateUser(email: email, password: password);
  }
}
