import 'package:flutter_test/flutter_test.dart';
import 'package:rondaqr/control_points.dart';

void main() {
  final ControlPointStore store = ControlPointStore.instance;

  setUp(() {
    store.onPointsChanged = null;
    store.loadPoints(const <ControlPointDefinition>[]);
  });

  tearDown(() {
    store.onPointsChanged = null;
    store.loadPoints(const <ControlPointDefinition>[]);
  });

  test(
    'aplica el identificador canonico devuelto por el guardado remoto',
    () async {
      store.onPointsChanged = (points) async {
        expect(points, hasLength(1));
        expect(points.single.id, startsWith('point_'));

        return <ControlPointDefinition>[
          ControlPointDefinition(
            id: '895ea0ad-fdc2-459d-951c-2540fa5989a4',
            name: points.single.name,
            qrIdentifier: points.single.qrIdentifier,
            description: points.single.description,
            order: points.single.order,
            isActive: points.single.isActive,
            iconKey: points.single.iconKey,
          ),
        ];
      };

      await store.addPoint(
        const ControlPointDefinition(
          id: 'point_local',
          name: 'Porton trasero',
          qrIdentifier: 'PORTON_TRASERO',
          description: 'Acceso posterior',
          order: 1,
          isActive: true,
          iconKey: 'gate',
        ),
      );

      expect(store.points.single.id, '895ea0ad-fdc2-459d-951c-2540fa5989a4');
      expect(store.activePoints, hasLength(1));
    },
  );

  test('no modifica el estado local cuando el guardado remoto falla', () async {
    const ControlPointDefinition original = ControlPointDefinition(
      id: '895ea0ad-fdc2-459d-951c-2540fa5989a4',
      name: 'Acceso principal',
      qrIdentifier: 'ACCESO_PRINCIPAL',
      description: 'Entrada',
      order: 1,
      isActive: true,
      iconKey: 'gate',
    );
    store.loadPoints(const <ControlPointDefinition>[original]);
    store.onPointsChanged = (_) async {
      throw StateError('RLS rechazo el cambio');
    };

    await expectLater(
      store.updatePoint(original.copyWith(name: 'Nombre nuevo')),
      throwsStateError,
    );

    expect(store.points.single.name, 'Acceso principal');
  });
}
