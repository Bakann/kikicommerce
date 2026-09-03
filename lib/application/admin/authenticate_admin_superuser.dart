import 'admin_backoffice_repository.dart';

class AuthenticateAdminSuperuser {
  final AdminBackofficeRepository repository;

  const AuthenticateAdminSuperuser(this.repository);

  Future<String> call({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    return repository.authenticateSuperuser(
      baseUrl: baseUrl,
      email: email,
      password: password,
    );
  }
}
