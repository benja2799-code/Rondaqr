import 'package:flutter/material.dart';

import 'control_points.dart';

class RoundPoint {
  final String id;
  final String name;
  final String qrIdentifier;
  final String description;
  final int order;
  final String? iconKey;

  bool completed;
  bool hasNovelty;
  String observation;
  DateTime? completedAt;

  RoundPoint({
    required this.id,
    required this.name,
    required this.qrIdentifier,
    required this.description,
    required this.order,
    required this.iconKey,
    this.completed = false,
    this.hasNovelty = false,
    this.observation = '',
    this.completedAt,
  });

  IconData get icon {
    return ControlPointIcons.iconFor(iconKey);
  }
}

class ActiveRoundPointSnapshot {
  final String name;
  final bool completed;
  final bool hasNovelty;
  final String observation;
  final DateTime? completedAt;
  final String? id;
  final String? qrIdentifier;
  final String? description;
  final int? order;
  final String? iconKey;

  ActiveRoundPointSnapshot({
    required this.name,
    required this.completed,
    required this.hasNovelty,
    required this.observation,
    required this.completedAt,
    this.id,
    this.qrIdentifier,
    this.description,
    this.order,
    this.iconKey,
  });
}

class ActiveRoundSnapshot {
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<ActiveRoundPointSnapshot> points;

  ActiveRoundSnapshot({
    required this.startedAt,
    required this.finishedAt,
    required this.points,
  });
}

class RoundState extends ChangeNotifier {
  RoundState._internal();

  static final RoundState instance = RoundState._internal();

  final List<RoundPoint> points = [];
  final List<ControlPointDefinition> _configuredPoints = [];

  DateTime? roundStartedAt;
  DateTime? roundFinishedAt;

  Future<void> Function(ActiveRoundSnapshot?)? onActiveRoundChanged;

  bool get roundStarted {
    return roundStartedAt != null;
  }

  bool get roundFinished {
    return roundFinishedAt != null;
  }

  int get completedPoints {
    return points.where((point) => point.completed).length;
  }

  int get totalPoints {
    return points.length;
  }

  double get progress {
    if (totalPoints == 0) {
      return 0;
    }

    return completedPoints / totalPoints;
  }

  bool get allPointsCompleted {
    return totalPoints > 0 && completedPoints == totalPoints;
  }

  ActiveRoundSnapshot? get activeRoundSnapshot {
    final DateTime? startedAt = roundStartedAt;

    if (startedAt == null) {
      return null;
    }

    return ActiveRoundSnapshot(
      startedAt: startedAt,
      finishedAt: roundFinishedAt,
      points: points.map((point) {
        return ActiveRoundPointSnapshot(
          id: point.id,
          name: point.name,
          qrIdentifier: point.qrIdentifier,
          description: point.description,
          order: point.order,
          iconKey: point.iconKey,
          completed: point.completed,
          hasNovelty: point.hasNovelty,
          observation: point.observation,
          completedAt: point.completedAt,
        );
      }).toList(),
    );
  }

  void configureControlPoints(List<ControlPointDefinition> activePoints) {
    _configuredPoints
      ..clear()
      ..addAll(activePoints);

    if (roundStarted) {
      return;
    }

    _replacePointsFromConfiguration();
    notifyListeners();
  }

  void loadActiveRound(ActiveRoundSnapshot? savedRound) {
    if (savedRound == null) {
      return;
    }

    roundStartedAt = savedRound.startedAt;
    points
      ..clear()
      ..addAll(
        savedRound.points.asMap().entries.map((entry) {
          final int index = entry.key;
          final ActiveRoundPointSnapshot savedPoint = entry.value;
          final ControlPointDefinition? configuredPoint = _findConfiguredPoint(
            savedPoint,
          );
          final String normalizedQr =
              ControlPointDefinition.normalizeQrIdentifier(
                savedPoint.qrIdentifier ?? configuredPoint?.qrIdentifier ?? '',
              );
          final String savedId = savedPoint.id?.trim() ?? '';

          return RoundPoint(
            id: savedId.isNotEmpty
                ? savedId
                : configuredPoint?.id ??
                      'legacy_${index}_${_legacyIdPart(savedPoint.name)}',
            name: savedPoint.name,
            qrIdentifier: normalizedQr,
            description:
                savedPoint.description ?? configuredPoint?.description ?? '',
            order: savedPoint.order ?? configuredPoint?.order ?? index + 1,
            iconKey: savedPoint.iconKey ?? configuredPoint?.iconKey,
            completed: savedPoint.completed,
            hasNovelty: savedPoint.completed && savedPoint.hasNovelty,
            observation: savedPoint.completed ? savedPoint.observation : '',
            completedAt: savedPoint.completed ? savedPoint.completedAt : null,
          );
        }),
      );

    points.sort((a, b) => a.order.compareTo(b.order));
    roundFinishedAt = allPointsCompleted ? savedRound.finishedAt : null;

    notifyListeners();
  }

  Future<void> startRound() async {
    if (roundStartedAt == null && points.isNotEmpty) {
      _clearPointProgress();
      roundStartedAt = DateTime.now();
      roundFinishedAt = null;
      notifyListeners();

      await _saveActiveRound();
    }
  }

  Future<void> completePoint({
    required String pointId,
    required bool hasNovelty,
    required String observation,
  }) async {
    final int index = points.indexWhere((point) => point.id == pointId);

    if (index == -1 || points[index].completed) {
      return;
    }

    points[index].completed = true;
    points[index].hasNovelty = hasNovelty;
    points[index].observation = observation;
    points[index].completedAt = DateTime.now();

    notifyListeners();

    await _saveActiveRound();
  }

  bool isPointCompleted(String pointId) {
    final RoundPoint? point = getPointById(pointId);
    return point?.completed ?? false;
  }

  RoundPoint? getPointById(String pointId) {
    for (final RoundPoint point in points) {
      if (point.id == pointId) {
        return point;
      }
    }

    return null;
  }

  RoundPoint? getPointByQrIdentifier(String qrIdentifier) {
    final String normalized = ControlPointDefinition.normalizeQrIdentifier(
      qrIdentifier,
    );

    for (final RoundPoint point in points) {
      if (point.qrIdentifier == normalized) {
        return point;
      }
    }

    return null;
  }

  Future<void> finishRound() async {
    roundFinishedAt = DateTime.now();
    notifyListeners();

    await _saveActiveRound();
  }

  Future<void> resetRound() async {
    roundStartedAt = null;
    roundFinishedAt = null;

    _replacePointsFromConfiguration();

    notifyListeners();

    await _saveActiveRound();
  }

  Future<void> clearSavedActiveRound() async {
    final saveFunction = onActiveRoundChanged;

    if (saveFunction == null) {
      return;
    }

    await saveFunction(null);
  }

  Future<void> _saveActiveRound() async {
    final saveFunction = onActiveRoundChanged;

    if (saveFunction == null) {
      return;
    }

    await saveFunction(activeRoundSnapshot);
  }

  void _replacePointsFromConfiguration() {
    points
      ..clear()
      ..addAll(
        _configuredPoints.map((point) {
          return RoundPoint(
            id: point.id,
            name: point.name,
            qrIdentifier: point.qrIdentifier,
            description: point.description,
            order: point.order,
            iconKey: point.iconKey,
          );
        }),
      );

    points.sort((a, b) => a.order.compareTo(b.order));
  }

  ControlPointDefinition? _findConfiguredPoint(
    ActiveRoundPointSnapshot savedPoint,
  ) {
    final String? savedId = savedPoint.id;
    final String normalizedQr = ControlPointDefinition.normalizeQrIdentifier(
      savedPoint.qrIdentifier ?? '',
    );

    for (final ControlPointDefinition point in _configuredPoints) {
      if ((savedId != null && savedId.isNotEmpty && point.id == savedId) ||
          (normalizedQr.isNotEmpty && point.qrIdentifier == normalizedQr) ||
          point.name == savedPoint.name) {
        return point;
      }
    }

    return null;
  }

  String _legacyIdPart(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  void _clearPointProgress() {
    for (final point in points) {
      point.completed = false;
      point.hasNovelty = false;
      point.observation = '';
      point.completedAt = null;
    }
  }
}
