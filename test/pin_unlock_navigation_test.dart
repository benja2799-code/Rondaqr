import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/main.dart';
import 'package:rondaqr/screens/pin_unlock_screen.dart';
import 'package:rondaqr/services/pin_auth_service.dart';
import 'package:rondaqr/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const AppUser nightGuard = AppUser(
    id: 'night-guard-test-id',
    email: 'guardia.noche@ronda.cl',
    displayName: 'Guardia Noche',
    identifier: 'night-guard-test-id',
    jobTitle: 'Guardia',
    installationId: 'installation-test-id',
    installationName: 'Instalación de prueba',
    company: 'RondaQR',
    shiftId: 'shift_night',
    shift: 'Turno Noche · 20:00 - 08:00',
    role: AppRole.guard,
    isActive: true,
  );

  Future<void> preparePinSession() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await SessionStore.instance.loadSession(
      AppSession(
        user: nightGuard,
        startedAt: DateTime(2026, 7, 14),
        persistent: true,
      ),
    );
    await PinAuthService.instance.createOrUpdatePin(
      userId: nightGuard.id,
      pin: '2468',
    );
    PinAuthService.instance.clearUnlock();
    await PinAuthService.instance.prepareForUser(nightGuard.id);
  }

  testWidgets('PIN de guardia noche abre Home sin error de widgets', (
    WidgetTester tester,
  ) async {
    await preparePinSession();

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RondaQRApp(initialization: Future<void>.value()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Guardia Noche'), findsOneWidget);

    for (final String digit in <String>['2', '4', '6', '8']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido, Guardia Noche'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN compacto no desborda en una pantalla baja', (
    WidgetTester tester,
  ) async {
    await preparePinSession();
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(RondaQRApp(initialization: Future<void>.value()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Guardia Noche'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN incorrecto muestra un mensaje claro', (
    WidgetTester tester,
  ) async {
    await preparePinSession();
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PinUnlockScreen()));
    await tester.pumpAndSettle();

    for (final String digit in <String>['1', '1', '1', '1']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('PIN incorrecto.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Olvidé mi PIN vuelve al Login con mensaje', (
    WidgetTester tester,
  ) async {
    await preparePinSession();
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: PinUnlockScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olvidé mi PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
    expect(
      find.text('Inicia sesión nuevamente para crear un nuevo PIN.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
