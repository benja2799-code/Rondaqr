import 'package:flutter/material.dart';

class ControlPointDefinition {
  final String id;
  final String name;
  final String qrIdentifier;
  final String description;
  final int order;
  final bool isActive;
  final String? iconKey;

  const ControlPointDefinition({
    required this.id,
    required this.name,
    required this.qrIdentifier,
    required this.description,
    required this.order,
    required this.isActive,
    required this.iconKey,
  });

  String get qrContent {
    return 'RONDAQR:$qrIdentifier';
  }

  IconData get icon {
    return ControlPointIcons.iconFor(iconKey);
  }

  ControlPointDefinition copyWith({
    String? name,
    String? qrIdentifier,
    String? description,
    int? order,
    bool? isActive,
    String? iconKey,
    bool clearIcon = false,
  }) {
    return ControlPointDefinition(
      id: id,
      name: name ?? this.name,
      qrIdentifier: normalizeQrIdentifier(qrIdentifier ?? this.qrIdentifier),
      description: description ?? this.description,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      iconKey: clearIcon ? null : iconKey ?? this.iconKey,
    );
  }

  static String normalizeQrIdentifier(String value) {
    String normalized = value.trim().toUpperCase();

    if (normalized.startsWith('RONDAQR:')) {
      normalized = normalized.substring('RONDAQR:'.length);
    }

    return normalized;
  }
}

class ControlPointIcons {
  ControlPointIcons._();

  static const Map<String, IconData> values = {
    'apartment': Icons.apartment_rounded,
    'car': Icons.directions_car_rounded,
    'water': Icons.water_damage_rounded,
    'shield': Icons.shield_rounded,
    'gate': Icons.door_sliding_rounded,
    'location': Icons.location_on_rounded,
    'warehouse': Icons.warehouse_rounded,
    'camera': Icons.videocam_rounded,
  };

  static const Map<String, String> labels = {
    'apartment': 'Edificio',
    'car': 'Vehículo',
    'water': 'Agua',
    'shield': 'Seguridad',
    'gate': 'Portón',
    'location': 'Ubicación',
    'warehouse': 'Bodega',
    'camera': 'Cámara',
  };

  static IconData iconFor(String? key) {
    return values[key] ?? Icons.location_on_rounded;
  }
}

class ControlPointStore extends ChangeNotifier {
  ControlPointStore._internal();

  static final ControlPointStore instance = ControlPointStore._internal();

  static const List<ControlPointDefinition> initialPoints = [
    ControlPointDefinition(
      id: 'default_access_main',
      name: 'Acceso principal',
      qrIdentifier: 'ACCESO_PRINCIPAL',
      description: 'Acceso principal de la instalación',
      order: 1,
      isActive: true,
      iconKey: 'apartment',
    ),
    ControlPointDefinition(
      id: 'default_parking',
      name: 'Estacionamiento',
      qrIdentifier: 'ESTACIONAMIENTO',
      description: 'Zona de estacionamientos',
      order: 2,
      isActive: true,
      iconKey: 'car',
    ),
    ControlPointDefinition(
      id: 'default_pump_room',
      name: 'Sala de bombas',
      qrIdentifier: 'SALA_BOMBAS',
      description: 'Sala de bombas de la instalación',
      order: 3,
      isActive: true,
      iconKey: 'water',
    ),
    ControlPointDefinition(
      id: 'default_north_perimeter',
      name: 'Perímetro norte',
      qrIdentifier: 'PERIMETRO_NORTE',
      description: 'Sector norte del perímetro',
      order: 4,
      isActive: true,
      iconKey: 'shield',
    ),
  ];

  final List<ControlPointDefinition> _points = [];
  bool _initialized = false;

  Future<List<ControlPointDefinition>> Function(
    List<ControlPointDefinition> points,
  )?
  onPointsChanged;

  bool get initialized {
    return _initialized;
  }

  List<ControlPointDefinition> get points {
    return List<ControlPointDefinition>.unmodifiable(_ordered(_points));
  }

  List<ControlPointDefinition> get activePoints {
    return List<ControlPointDefinition>.unmodifiable(
      _ordered(_points.where((point) => point.isActive)),
    );
  }

  void loadPoints(List<ControlPointDefinition>? savedPoints) {
    _points
      ..clear()
      ..addAll(savedPoints ?? initialPoints);

    _initialized = true;
    notifyListeners();
  }

  bool hasQrIdentifier(String identifier, {String? excludingId}) {
    final String normalized = ControlPointDefinition.normalizeQrIdentifier(
      identifier,
    );

    return _points.any(
      (point) =>
          point.id != excludingId &&
          point.qrIdentifier.toUpperCase() == normalized,
    );
  }

  Future<void> addPoint(ControlPointDefinition point) async {
    if (hasQrIdentifier(point.qrIdentifier)) {
      throw StateError('El identificador QR ya está en uso.');
    }

    final List<ControlPointDefinition> updated = [
      ..._points,
      point.copyWith(qrIdentifier: point.qrIdentifier),
    ];

    await _saveAndApply(updated);
  }

  Future<void> updatePoint(ControlPointDefinition point) async {
    if (hasQrIdentifier(point.qrIdentifier, excludingId: point.id)) {
      throw StateError('El identificador QR ya está en uso.');
    }

    final int index = _points.indexWhere((item) => item.id == point.id);

    if (index == -1) {
      throw StateError('El punto de control no existe.');
    }

    final List<ControlPointDefinition> updated = [..._points];
    updated[index] = point.copyWith(qrIdentifier: point.qrIdentifier);

    await _saveAndApply(updated);
  }

  Future<void> deletePoint(String pointId) async {
    final List<ControlPointDefinition> updated = _points
        .where((point) => point.id != pointId)
        .toList();

    if (updated.length == _points.length) {
      return;
    }

    await _saveAndApply(updated);
  }

  Future<void> _saveAndApply(List<ControlPointDefinition> updated) async {
    final saveFunction = onPointsChanged;

    if (saveFunction == null) {
      throw StateError(
        'No existe una función de guardado para los puntos de control.',
      );
    }

    final List<ControlPointDefinition> ordered = _ordered(updated);
    final List<ControlPointDefinition> saved = await saveFunction(ordered);

    _points
      ..clear()
      ..addAll(_ordered(saved));

    notifyListeners();
  }

  List<ControlPointDefinition> _ordered(
    Iterable<ControlPointDefinition> source,
  ) {
    final List<ControlPointDefinition> ordered = List.of(source);

    ordered.sort((a, b) {
      final int byOrder = a.order.compareTo(b.order);

      if (byOrder != 0) {
        return byOrder;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return ordered;
  }
}
