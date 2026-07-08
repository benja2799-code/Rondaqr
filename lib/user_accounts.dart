import 'package:flutter/foundation.dart';

import 'auth_models.dart';

class UserAccountStore extends ChangeNotifier {
  UserAccountStore._internal();

  static final UserAccountStore instance = UserAccountStore._internal();

  final List<LocalUserAccount> _accounts = [];
  bool _initialized = false;

  Future<void> Function(List<LocalUserAccount> accounts)? onAccountsChanged;

  bool get initialized => _initialized;

  List<LocalUserAccount> get accounts {
    final List<LocalUserAccount> result = List.from(_accounts);
    result.sort((a, b) {
      final int roleComparison = a.user.role.index.compareTo(b.user.role.index);
      return roleComparison != 0
          ? roleComparison
          : a.user.displayName.compareTo(b.user.displayName);
    });
    return List.unmodifiable(result);
  }

  List<AppUser> get activeGuards {
    return accounts
        .map((account) => account.user)
        .where((user) => user.role == AppRole.guard && user.isActive)
        .toList(growable: false);
  }

  bool loadAccounts(
    List<LocalUserAccount>? savedAccounts, {
    required String installationName,
    required String company,
  }) {
    final List<LocalUserAccount> validAccounts = (savedAccounts ?? [])
        .where((account) => account.password.isNotEmpty)
        .toList();
    final bool seeded = validAccounts.isEmpty;

    _accounts
      ..clear()
      ..addAll(
        seeded
            ? defaultAccounts(
                installationName: installationName,
                company: company,
              )
            : validAccounts,
      );

    _initialized = true;
    notifyListeners();
    return seeded;
  }

  static List<LocalUserAccount> defaultAccounts({
    required String installationName,
    required String company,
  }) {
    return [
      LocalUserAccount(
        user: AppUser(
          id: 'demo_admin',
          email: 'admin@rondaqr.cl',
          displayName: 'Benjamin Jacob',
          identifier: 'ADMIN-001',
          jobTitle: 'Administrador',
          installationId: 'inst_local',
          installationName: installationName,
          company: company,
          shift: 'Administración',
          role: AppRole.administrator,
        ),
        password: 'Admin123*',
      ),
      LocalUserAccount(
        user: AppUser(
          id: 'demo_guardia',
          email: 'guardia.dia@rondaqr.cl',
          displayName: 'Guardia Día',
          identifier: 'GUARD-DIA-001',
          jobTitle: 'Guardia de seguridad',
          installationId: 'inst_local',
          installationName: installationName,
          company: company,
          shiftId: 'shift_day',
          shift: 'Turno Día · 08:00 - 20:00',
          role: AppRole.guard,
        ),
        password: 'GuardiaDia123*',
      ),
      LocalUserAccount(
        user: AppUser(
          id: 'demo_guardia_noche',
          email: 'guardia.noche@rondaqr.cl',
          displayName: 'Guardia Noche',
          identifier: 'GUARD-NOCHE-001',
          jobTitle: 'Guardia de seguridad',
          installationId: 'inst_local',
          installationName: installationName,
          company: company,
          shiftId: 'shift_night',
          shift: 'Turno Noche · 20:00 - 08:00',
          role: AppRole.guard,
        ),
        password: 'GuardiaNoche123*',
      ),
    ];
  }

  LocalUserAccount? accountById(String userId) {
    for (final LocalUserAccount account in _accounts) {
      if (account.user.id == userId) {
        return account;
      }
    }
    return null;
  }

  LocalUserAccount? accountByEmail(String email) {
    final String normalized = email.trim().toLowerCase();

    for (final LocalUserAccount account in _accounts) {
      if (account.user.email.trim().toLowerCase() == normalized) {
        return account;
      }
    }
    return null;
  }

  Future<void> saveAccount(LocalUserAccount account) async {
    final String normalizedEmail = account.user.email.trim().toLowerCase();
    final bool duplicatedEmail = _accounts.any(
      (item) =>
          item.user.id != account.user.id &&
          item.user.email.trim().toLowerCase() == normalizedEmail,
    );

    if (duplicatedEmail) {
      throw StateError('Ya existe un usuario con ese correo o acceso.');
    }

    final List<LocalUserAccount> updated = List.from(_accounts);
    final int index = updated.indexWhere(
      (item) => item.user.id == account.user.id,
    );

    if (index == -1) {
      updated.add(account);
    } else {
      updated[index] = account;
    }

    await _persist(updated);
  }

  Future<void> updateInstallation({
    required String installationName,
    required String company,
  }) async {
    final List<LocalUserAccount> updated = _accounts.map((account) {
      return account.copyWith(
        user: account.user.copyWith(
          installationName: installationName,
          company: company,
        ),
      );
    }).toList();

    await _persist(updated);
  }

  Future<void> assignShift({
    required String userId,
    required String shiftId,
    required String shiftDisplay,
  }) async {
    final List<LocalUserAccount> updated = _accounts.map((account) {
      if (account.user.id != userId) {
        return account;
      }

      return account.copyWith(
        user: account.user.copyWith(shiftId: shiftId, shift: shiftDisplay),
      );
    }).toList();

    await _persist(updated);
  }

  Future<void> clearShiftForUsers(
    Iterable<String> userIds, {
    String exceptUserId = '',
  }) async {
    final Set<String> ids = userIds.toSet();
    final List<LocalUserAccount> updated = _accounts.map((account) {
      if (!ids.contains(account.user.id) || account.user.id == exceptUserId) {
        return account;
      }

      return account.copyWith(
        user: account.user.copyWith(shiftId: '', shift: ''),
      );
    }).toList();

    await _persist(updated);
  }

  Future<void> _persist(List<LocalUserAccount> accounts) async {
    final saveFunction = onAccountsChanged;

    if (saveFunction == null) {
      throw StateError('No existe una función para guardar los usuarios.');
    }

    await saveFunction(List.unmodifiable(accounts));

    _accounts
      ..clear()
      ..addAll(accounts);
    _initialized = true;
    notifyListeners();
  }
}
