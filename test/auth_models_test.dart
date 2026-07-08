import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/auth_models.dart';

void main() {
  group('Permisos por rol', () {
    test('Guardia puede ejecutar rondas pero no ver reportes', () {
      expect(AppRole.guard.can(AppPermission.manageRounds), isTrue);
      expect(AppRole.guard.can(AppPermission.scanQr), isTrue);
      expect(AppRole.guard.can(AppPermission.viewReports), isFalse);
      expect(AppRole.guard.can(AppPermission.manageUsers), isFalse);
    });

    test('Administrador conserva acceso total', () {
      for (final AppPermission permission in AppPermission.values) {
        expect(AppRole.administrator.can(permission), isTrue);
      }
    });
  });

  test('La sesión conserva todos los datos al serializarse', () {
    const AppUser user = AppUser(
      id: 'test_user',
      email: 'test@rondaqr.cl',
      displayName: 'Usuario de prueba',
      identifier: 'TEST-001',
      jobTitle: 'Guardia',
      installationId: 'installation_1',
      installationName: 'Instalación de prueba',
      company: 'RondaQR',
      shiftId: 'shift_day',
      shift: '08:00 - 20:00',
      role: AppRole.guard,
    );
    final AppSession original = AppSession(
      user: user,
      startedAt: DateTime(2026, 7, 6, 8, 30),
      persistent: true,
    );

    final AppSession? restored = AppSession.fromJson(original.toJson());

    expect(restored, isNotNull);
    expect(restored!.user.id, original.user.id);
    expect(restored.user.role, AppRole.guard);
    expect(restored.user.shiftId, 'shift_day');
    expect(restored.startedAt, original.startedAt);
    expect(restored.persistent, isTrue);
  });
}
