import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/user_accounts.dart';
import 'package:rondaqr/work_shifts.dart';

void main() {
  test('Los datos iniciales incluyen administrador y dos guardias', () {
    final List<LocalUserAccount> accounts = UserAccountStore.defaultAccounts(
      installationName: 'Instalación de prueba',
      company: 'Empresa de prueba',
    );

    expect(accounts.length, 3);
    expect(
      accounts.where((account) => account.user.role == AppRole.guard).length,
      2,
    );
    expect(
      accounts.any((account) => account.user.shiftId == 'shift_day'),
      isTrue,
    );
    expect(
      accounts.any((account) => account.user.shiftId == 'shift_night'),
      isTrue,
    );
  });

  test('Iniciar y cerrar turno conserva ingreso, salida y guardia', () async {
    final WorkShiftStore store = WorkShiftStore.instance;
    store.loadDefinitions(null);
    store.loadHistory([]);
    store.loadActiveShift(null);

    WorkShiftRecord? persistedActive;
    List<WorkShiftRecord> persistedHistory = [];
    store.onActiveShiftChanged = (shift) async {
      persistedActive = shift;
    };
    store.onHistoryChanged = (history) async {
      persistedHistory = List<WorkShiftRecord>.from(history);
    };

    final AppUser guard = UserAccountStore.defaultAccounts(
      installationName: 'Instalación de prueba',
      company: 'Empresa de prueba',
    ).firstWhere((account) => account.user.shiftId == 'shift_day').user;

    final WorkShiftRecord active = await store.startShift(guard);

    expect(active.isActive, isTrue);
    expect(active.userId, guard.id);
    expect(active.shiftName, 'Turno Día');
    expect(persistedActive?.id, active.id);

    final WorkShiftRecord closed = await store.closeShift(guard.id);

    expect(closed.isActive, isFalse);
    expect(closed.actualEndedAt, isNotNull);
    expect(persistedActive, isNull);
    expect(persistedHistory.single.id, active.id);
  });
}
