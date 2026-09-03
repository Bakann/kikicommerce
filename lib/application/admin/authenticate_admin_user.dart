import 'admin_auth_repository.dart';

class AuthenticateAdminUser {
  final AdminAuthRepository repository;

  const AuthenticateAdminUser(this.repository);

  Future<String> call({required String email, required String password}) {
    return repository.authenticateUser(email: email, password: password);
  }
}
