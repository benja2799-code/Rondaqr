import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'auth_repository.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._internal();

  static final SessionStore instance = SessionStore._internal();

  AuthRepository _repository = LocalAuthRepository();
  AppSession? _session;
  bool _initialized = false;
  String? _lastNotice;

  Future<void> Function(AppSession session)? onSessionCreated;
  Future<void> Function()? onSessionCleared;

  AppSession? get session => _session;
  AppUser? get currentUser => _session?.user;
  bool get initialized => _initialized;
  bool get isAuthenticated => _session?.user.isActive ?? false;
  String? get lastNotice => _lastNotice;

  bool can(AppPermission permission) {
    return currentUser?.can(permission) ?? false;
  }

  void useRepository(AuthRepository repository) {
    _repository = repository;
  }

  String? consumeNotice() {
    final String? notice = _lastNotice;
    _lastNotice = null;
    return notice;
  }

  Future<void> loadSession(AppSession? savedSession) async {
    if (savedSession == null || !savedSession.persistent) {
      _session = null;
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final AppUser? restoredUser = await _repository.restoreUser(
        savedSession.user.id,
      );
      _lastNotice = _repository.lastNotice;

      _session = restoredUser == null
          ? savedSession.user.isActive
                ? AppSession(
                    user: savedSession.user,
                    startedAt: savedSession.startedAt,
                    persistent: true,
                  )
                : null
          : AppSession(
              user: restoredUser,
              startedAt: savedSession.startedAt,
              persistent: true,
            );
    } catch (error) {
      debugPrint('No fue posible restaurar la sesión: $error');
      _lastNotice = 'Sin conexión, usando datos locales.';
      _session = savedSession.user.isActive
          ? AppSession(
              user: savedSession.user,
              startedAt: savedSession.startedAt,
              persistent: true,
            )
          : null;
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
    required bool persistent,
  }) async {
    final AppUser user = await _repository.signIn(
      email: email,
      password: password,
    );
    _lastNotice = _repository.lastNotice;

    final AppSession newSession = AppSession(
      user: user,
      startedAt: DateTime.now(),
      persistent: persistent,
    );

    if (persistent) {
      final saveFunction = onSessionCreated;

      if (saveFunction == null) {
        throw StateError('No existe una función para guardar la sesión.');
      }

      await saveFunction(newSession);
    } else {
      await onSessionCleared?.call();
    }

    _session = newSession;
    _initialized = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repository.signOut();
    await onSessionCleared?.call();

    _session = null;
    _lastNotice = null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    final AppSession? currentSession = _session;
    if (currentSession == null) {
      return;
    }

    final AppUser? restoredUser = await _repository.restoreUser(
      currentSession.user.id,
    );
    _lastNotice = _repository.lastNotice;

    if (restoredUser == null) {
      _session = currentSession.user.isActive ? currentSession : null;
      _initialized = true;
      notifyListeners();
      return;
    }

    final AppSession refreshedSession = AppSession(
      user: restoredUser,
      startedAt: currentSession.startedAt,
      persistent: currentSession.persistent,
    );

    if (refreshedSession.persistent) {
      await onSessionCreated?.call(refreshedSession);
    }

    _session = refreshedSession;
    _initialized = true;
    notifyListeners();
  }
}
