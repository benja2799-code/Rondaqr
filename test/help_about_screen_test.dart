import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/screens/about_screen.dart';
import 'package:rondaqr/screens/help_screen.dart';
import 'package:rondaqr/screens/login_screen.dart';

void main() {
  test('El texto de creación del PIN conserva UTF-8', () {
    expect(
      LoginScreen.pinSetupPrompt,
      '¿Quieres crear un PIN de 4 dígitos para entrar más rápido la próxima vez?',
    );
  });

  testWidgets('Ayuda muestra todas sus secciones sin errores', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pumpAndSettle();

    const Map<String, String> sections = <String, String>{
      'Primer acceso':
          'Ingresa con el correo y contraseña asignados por el administrador.',
      'PIN de acceso': 'El PIN es personal y está asociado al usuario actual.',
      'Turnos': 'Inicia tu turno antes de realizar una ronda.',
      'Rondas': 'Presiona “Iniciar ronda”.',
      'Novedades': 'Selecciona “Con novedad”.',
      'Historial': 'Permite revisar las rondas finalizadas.',
      'Reportes': 'Permite revisar información semanal y mensual.',
      'Funciones del administrador': 'Revisar turnos.',
      'Problemas frecuentes': '“No puedo iniciar una ronda”',
      'Soporte': 'Soporte RondaQR',
    };

    for (final MapEntry<String, String> section in sections.entries) {
      final Finder tile = find.widgetWithText(ExpansionTile, section.key);
      expect(tile, findsWidgets);
      await tester.tap(tile.first);
      await tester.pumpAndSettle();
      expect(find.text(section.value), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(tile.first);
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Acerca de muestra identidad y funciones principales', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AboutRondaQrScreen()));
    await tester.pumpAndSettle();

    expect(find.text('RondaQR'), findsOneWidget);
    expect(find.text('LG Seguridad SPA'), findsOneWidget);
    expect(
      find.text(
        'Aplicación para el control y trazabilidad de rondas de seguridad mediante códigos QR.',
      ),
      findsOneWidget,
    );
    expect(find.text('Funciones principales'), findsOneWidget);
    expect(find.textContaining('Versión '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login compacto no desborda en una pantalla baja', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Acceso'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
