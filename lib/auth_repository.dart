import 'auth_models.dart';
import 'user_accounts.dart';

abstract interface class AuthRepository {
  String? get lastNotice;

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser?> restoreUser(String userId);

  Future<void> signOut();
}

class AuthenticationException implements Exception {
  final String message;

  const AuthenticationException(this.message);

  @override
  String toString() => message;
}

class LocalAuthRepository implements AuthRepository {
  final UserAccountStore accountStore;

  LocalAuthRepository({UserAccountStore? accountStore})
    : accountStore = accountStore ?? UserAccountStore.instance;

  @override
  String? get lastNotice => null;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();

    for (final LocalUserAccount account in accountStore.accounts) {
      if (account.user.email.toLowerCase() == normalizedEmail &&
          account.password == password) {
        if (!account.user.isActive) {
          throw const AuthenticationException(
            'La cuenta se encuentra desactivada.',
          );
        }

        return account.user;
      }
    }

    throw const AuthenticationException('Correo o contraseña incorrectos.');
  }

  @override
  Future<AppUser?> restoreUser(String userId) async {
    for (final LocalUserAccount account in accountStore.accounts) {
      if (account.user.id == userId && account.user.isActive) {
        return account.user;
      }
    }

    return null;
  }

  @override
  Future<void> signOut() async {}
}
