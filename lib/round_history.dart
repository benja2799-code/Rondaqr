import 'package:flutter/material.dart';

class RoundHistoryItem {
  final String id;
  final String guardName;
  final String installation;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int totalPoints;
  final int completedPoints;
  final int noveltyCount;
  final List<RoundHistoryPoint> points;

  RoundHistoryItem({
    required this.id,
    required this.guardName,
    required this.installation,
    required this.startedAt,
    required this.finishedAt,
    required this.totalPoints,
    required this.completedPoints,
    required this.noveltyCount,
    required this.points,
  });

  bool get completed {
    return totalPoints > 0 && completedPoints == totalPoints;
  }

  bool get hasNovelty {
    return noveltyCount > 0;
  }

  Duration get duration {
    return finishedAt.difference(startedAt);
  }

  String get status {
    if (!completed) {
      return 'Incompleta';
    }

    if (hasNovelty) {
      return 'Con novedad';
    }

    return 'Completada';
  }
}

class RoundHistoryPoint {
  final String name;
  final bool completed;
  final bool hasNovelty;
  final String observation;
  final DateTime? completedAt;

  RoundHistoryPoint({
    required this.name,
    required this.completed,
    required this.hasNovelty,
    required this.observation,
    required this.completedAt,
  });
}

class RoundHistoryStore extends ChangeNotifier {
  RoundHistoryStore._internal();

  static final RoundHistoryStore instance = RoundHistoryStore._internal();

  final List<RoundHistoryItem> _rounds = [];
  final Map<String, Future<void>> _pendingAdds = {};

  Future<void> Function(List<RoundHistoryItem>)? onHistoryChanged;

  bool _initialized = false;

  bool get initialized {
    return _initialized;
  }

  List<RoundHistoryItem> get rounds {
    final List<RoundHistoryItem> ordered = List<RoundHistoryItem>.from(_rounds);

    ordered.sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

    return List<RoundHistoryItem>.unmodifiable(ordered);
  }

  int get totalRounds {
    return _rounds.length;
  }

  int get completedRounds {
    return _rounds.where((round) => round.completed).length;
  }

  int get roundsWithNovelty {
    return _rounds.where((round) => round.hasNovelty).length;
  }

  int get incompleteRounds {
    return _rounds.where((round) => !round.completed).length;
  }

  double get compliance {
    if (_rounds.isEmpty) {
      return 0;
    }

    return completedRounds / totalRounds;
  }

  void loadRounds(List<RoundHistoryItem> savedRounds) {
    _rounds
      ..clear()
      ..addAll(savedRounds);

    _initialized = true;

    notifyListeners();
  }

  Future<void> addRound(RoundHistoryItem round) async {
    final Future<void>? pendingAdd = _pendingAdds[round.id];

    if (pendingAdd != null) {
      await pendingAdd;
      return;
    }

    final Future<void> operation = _addRoundAndSave(round);
    _pendingAdds[round.id] = operation;

    try {
      await operation;
    } finally {
      if (identical(_pendingAdds[round.id], operation)) {
        _pendingAdds.remove(round.id);
      }
    }
  }

  Future<void> _addRoundAndSave(RoundHistoryItem round) async {
    final bool alreadyExists = _rounds.any((item) => item.id == round.id);

    if (alreadyExists) {
      return;
    }

    _rounds.add(round);

    notifyListeners();

    try {
      await _saveChanges();
    } catch (_) {
      _rounds.removeWhere((item) => item.id == round.id);
      notifyListeners();
      rethrow;
    }
  }

  RoundHistoryItem? getRoundById(String id) {
    try {
      return _rounds.firstWhere((round) => round.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearHistory() async {
    _rounds.clear();

    notifyListeners();

    await _saveChanges();
  }

  Future<void> _saveChanges() async {
    final saveFunction = onHistoryChanged;

    if (saveFunction == null) {
      debugPrint(
        'El historial cambió, pero no existe una función de guardado conectada.',
      );
      return;
    }

    await saveFunction(List<RoundHistoryItem>.from(_rounds));
  }
}
