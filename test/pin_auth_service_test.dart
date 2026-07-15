import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/services/pin_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Los PIN de Admin, Guardia Día y Guardia Noche son independientes',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      const FlutterSecureStorage storage = FlutterSecureStorage();
      final PinAuthService service = PinAuthService.instance;

      const Map<String, String> pins = <String, String>{
        'admin-test-id': '1357',
        'day-guard-test-id': '2468',
        'night-guard-test-id': '9876',
      };

      for (final MapEntry<String, String> entry in pins.entries) {
        await service.createOrUpdatePin(userId: entry.key, pin: entry.value);

        expect(
          await service.verifyPin(userId: entry.key, pin: entry.value),
          isTrue,
        );
        expect(
          await service.verifyPin(userId: entry.key, pin: '0000'),
          isFalse,
        );

        final String? saved = await storage.read(
          key: 'rondaqr_pin_hash_${entry.key}',
        );
        expect(saved, isNotNull);
        expect(saved, isNot(contains(entry.value)));
        expect(saved, matches(RegExp(r'^v1:[^:]+:[a-f0-9]{64}$')));
      }
    },
  );
}
