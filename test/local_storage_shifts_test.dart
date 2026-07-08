import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/local_storage.dart';
import 'package:rondaqr/user_accounts.dart';
import 'package:rondaqr/work_shifts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Usuarios, turnos y turno activo conservan sus datos', () async {
    SharedPreferences.setMockInitialValues({});
    final LocalStorage storage = LocalStorage.instance;
    final accounts = UserAccountStore.defaultAccounts(
      installationName: 'Instalación de prueba',
      company: 'Empresa de prueba',
    );
    final ShiftDefinition dayShift = WorkShiftStore.defaultDefinitions.first;
    final guard = accounts
        .firstWhere((account) => account.user.shiftId == dayShift.id)
        .user;
    final WorkShiftRecord active = WorkShiftRecord(
      id: 'active_test',
      userId: guard.id,
      guardName: guard.displayName,
      role: guard.role.label,
      installation: guard.installationName,
      shiftId: dayShift.id,
      shiftName: dayShift.name,
      scheduledStart: dayShift.scheduledStart,
      scheduledEnd: dayShift.scheduledEnd,
      actualStartedAt: DateTime(2026, 7, 6, 8, 2),
      actualEndedAt: null,
      isActive: true,
    );

    await storage.saveUsers(accounts);
    await storage.saveShiftDefinitions([dayShift]);
    await storage.saveActiveShift(active);

    final restoredAccounts = await storage.loadUsers();
    final restoredShifts = await storage.loadShiftDefinitions();
    final restoredActive = await storage.loadActiveShift();

    expect(restoredAccounts, hasLength(3));
    expect(restoredShifts?.single.name, 'Turno Día');
    expect(restoredActive?.userId, guard.id);
    expect(restoredActive?.actualStartedAt, active.actualStartedAt);
  });

  test('El historial antiguo sigue cargando sin metadatos de turno', () async {
    SharedPreferences.setMockInitialValues({
      'rondaqr_history_v1': jsonEncode([
        {
          'id': 'legacy_round',
          'guardName': 'Guardia anterior',
          'installation': 'Instalación anterior',
          'startedAt': '2026-07-01T08:00:00.000',
          'finishedAt': '2026-07-01T08:20:00.000',
          'totalPoints': 1,
          'completedPoints': 1,
          'noveltyCount': 0,
          'points': <Map<String, dynamic>>[],
        },
      ]),
    });

    final rounds = await LocalStorage.instance.loadHistory();

    expect(rounds, hasLength(1));
    expect(rounds.single.guardName, 'Guardia anterior');
    expect(rounds.single.shiftId, isEmpty);
    expect(rounds.single.shiftDisplay, 'Turno no registrado');
  });
}
