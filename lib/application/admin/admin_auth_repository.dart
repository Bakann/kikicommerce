abstract interface class AdminAuthRepository {
  Future<String> authenticateUser({
    required String email,
    required String password,
  });
}
