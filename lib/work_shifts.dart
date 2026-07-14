import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'services/sync_status.dart';

class ShiftDefinition {
  final String id;
  final String name;
  final String scheduledStart;
  final String scheduledEnd;
  final String assignedUserId;
  final bool isActive;

  const ShiftDefinition({
    required this.id,
    required this.name,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.assignedUserId = '',
    this.isActive = true,
  });

  String get schedule => '$scheduledStart - $scheduledEnd';
  String get displayName => '$name · $schedule';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scheduledStart': scheduledStart,
      'scheduledEnd': scheduledEnd,
      'assignedUserId': assignedUserId,
      'isActive': isActive,
    };
  }

  static ShiftDefinition? fromJson(Map<String, dynamic> json) {
    String readText(String key) {
      final dynamic value = json[key];
      return value is String ? value.trim() : '';
    }

    final String id = readText('id');
    final String name = readText('name');
    final String start = readText('scheduledStart');
    final String end = readText('scheduledEnd');

    if (id.isEmpty ||
        name.isEmpty ||
        !isValidClockTime(start) ||
        !isValidClockTime(end)) {
      return null;
    }

    return ShiftDefinition(
      id: id,
      name: name,
      scheduledStart: start,
      scheduledEnd: end,
      assignedUserId: readText('assignedUserId'),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  ShiftDefinition copyWith({
    String? id,
    String? name,
    String? scheduledStart,
    String? scheduledEnd,
    String? assignedUserId,
    bool? isActive,
  }) {
    return ShiftDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      isActive: isActive ?? this.isActive,
    );
  }

  static bool isValidClockTime(String value) {
    final RegExpMatch? match = RegExp(
      r'^([01]\d|2[0-3]):([0-5]\d)$',
    ).firstMatch(value);
    return match != null;
  }
}

class WorkShiftRecord {
  final String id;
  final String userId;
  final String guardName;
  final String role;
  final String installation;
  final String shiftId;
  final String shiftName;
  final String scheduledStart;
  final String scheduledEnd;
  final DateTime actualStartedAt;
  final DateTime? actualEndedAt;
  final bool isActive;
  final List<String> roundIds;
  final int noveltyCount;
  final SyncStatus syncStatus;

  const WorkShiftRecord({
    required this.id,
    required this.userId,
    required this.guardName,
    required this.role,
    required this.installation,
    required this.shiftId,
    required this.shiftName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.actualStartedAt,
    required this.actualEndedAt,
    required this.isActive,
    this.roundIds = const [],
    this.noveltyCount = 0,
    this.syncStatus = SyncStatus.pending,
  });

  Duration get duration {
    return (actualEndedAt ?? DateTime.now()).difference(actualStartedAt);
  }

  DateTime get startedDate {
    return DateTime(
      actualStartedAt.year,
      actualStartedAt.month,
      actualStartedAt.day,
    );
  }

  DateTime? get closedDate {
    final DateTime? endedAt = actualEndedAt;
    if (endedAt == null) {
      return null;
    }

    return DateTime(endedAt.year, endedAt.month, endedAt.day);
  }

  String get statusLabel {
    return isActive ? 'En turno' : 'Cerrado';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'guardName': guardName,
      'role': role,
      'installation': installation,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'scheduledStart': scheduledStart,
      'scheduledEnd': scheduledEnd,
      'actualStartedAt': actualStartedAt.toIso8601String(),
      'actualEndedAt': actualEndedAt?.toIso8601String(),
      'isActive': isActive,
      'roundIds': roundIds,
      'noveltyCount': noveltyCount,
      'syncStatus': syncStatus.storageValue,
    };
  }

  static WorkShiftRecord? fromJson(Map<String, dynamic> json) {
    String readText(String key) {
      final dynamic value = json[key];
      return value is String ? value.trim() : '';
    }

    final DateTime? startedAt = DateTime.tryParse(readText('actualStartedAt'));
    final String endedText = readText('actualEndedAt');
    final DateTime? endedAt = endedText.isEmpty
        ? null
        : DateTime.tryParse(endedText);
    final String id = readText('id');
    final String userId = readText('userId');
    final String shiftId = readText('shiftId');

    if (id.isEmpty || userId.isEmpty || shiftId.isEmpty || startedAt == null) {
      return null;
    }

    return WorkShiftRecord(
      id: id,
      userId: userId,
      guardName: readText('guardName'),
      role: readText('role'),
      installation: readText('installation'),
      shiftId: shiftId,
      shiftName: readText('shiftName'),
      scheduledStart: readText('scheduledStart'),
      scheduledEnd: readText('scheduledEnd'),
      actualStartedAt: startedAt,
      actualEndedAt: endedAt,
      isActive: json['isActive'] as bool? ?? endedAt == null,
      roundIds: (json['roundIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where((roundId) => roundId.trim().isNotEmpty)
          .toList(growable: false),
      noveltyCount: (json['noveltyCount'] as num?)?.toInt() ?? 0,
      syncStatus: SyncStatusX.fromStorage(readText('syncStatus')),
    );
  }

  WorkShiftRecord close(DateTime endedAt) {
    return WorkShiftRecord(
      id: id,
      userId: userId,
      guardName: guardName,
      role: role,
      installation: installation,
      shiftId: shiftId,
      shiftName: shiftName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStartedAt: actualStartedAt,
      actualEndedAt: endedAt,
      isActive: false,
      roundIds: roundIds,
      noveltyCount: noveltyCount,
      syncStatus: syncStatus,
    );
  }

  WorkShiftRecord withUser(AppUser user) {
    return WorkShiftRecord(
      id: id,
      userId: userId,
      guardName: user.displayName,
      role: user.role.label,
      installation: user.installationName,
      shiftId: shiftId,
      shiftName: shiftName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStartedAt: actualStartedAt,
      actualEndedAt: actualEndedAt,
      isActive: isActive,
      roundIds: roundIds,
      noveltyCount: noveltyCount,
      syncStatus: syncStatus,
    );
  }

  WorkShiftRecord withDefinition(ShiftDefinition definition) {
    return WorkShiftRecord(
      id: id,
      userId: userId,
      guardName: guardName,
      role: role,
      installation: installation,
      shiftId: shiftId,
      shiftName: definition.name,
      scheduledStart: definition.scheduledStart,
      scheduledEnd: definition.scheduledEnd,
      actualStartedAt: actualStartedAt,
      actualEndedAt: actualEndedAt,
      isActive: isActive,
      roundIds: roundIds,
      noveltyCount: noveltyCount,
      syncStatus: syncStatus,
    );
  }

  WorkShiftRecord withRound({
    required String roundId,
    required int noveltyCount,
  }) {
    final List<String> updatedRoundIds = List<String>.from(roundIds);
    if (!updatedRoundIds.contains(roundId)) {
      updatedRoundIds.add(roundId);
    }

    return WorkShiftRecord(
      id: id,
      userId: userId,
      guardName: guardName,
      role: role,
      installation: installation,
      shiftId: shiftId,
      shiftName: shiftName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualStartedAt: actualStartedAt,
      actualEndedAt: actualEndedAt,
      isActive: isActive,
      roundIds: List.unmodifiable(updatedRoundIds),
      noveltyCount: this.noveltyCount + noveltyCount,
      syncStatus: SyncStatus.pending,
    );
  }
}

class WorkShiftStore extends ChangeNotifier {
  WorkShiftStore._internal();

  static final WorkShiftStore instance = WorkShiftStore._internal();

  final List<ShiftDefinition> _definitions = [];
  final List<WorkShiftRecord> _history = [];
  final List<WorkShiftRecord> _remoteActiveShifts = [];
  WorkShiftRecord? _activeShift;
  bool _initialized = false;

  Future<void> Function(List<ShiftDefinition> shifts)? onDefinitionsChanged;
  Future<void> Function(WorkShiftRecord? shift)? onActiveShiftChanged;
  Future<void> Function(List<WorkShiftRecord> shifts)? onHistoryChanged;

  bool get initialized => _initialized;
  WorkShiftRecord? get activeShift => _activeShift;
  List<ShiftDefinition> get definitions => List.unmodifiable(_definitions);
  List<WorkShiftRecord> get history => List.unmodifiable(_history);
  List<WorkShiftRecord> get activeShifts {
    if (_remoteActiveShifts.isNotEmpty) {
      return List.unmodifiable(_remoteActiveShifts);
    }

    final WorkShiftRecord? current = _activeShift;
    return current == null
        ? const []
        : List<WorkShiftRecord>.unmodifiable([current]);
  }

  bool loadDefinitions(
    List<ShiftDefinition>? savedDefinitions, {
    bool seedDefaults = true,
  }) {
    final List<ShiftDefinition> valid = savedDefinitions ?? [];
    final bool seeded = seedDefaults && valid.isEmpty;

    _definitions
      ..clear()
      ..addAll(seeded ? defaultDefinitions : valid);
    _initialized = true;
    notifyListeners();
    return seeded;
  }

  void loadActiveShift(WorkShiftRecord? savedActiveShift) {
    _remoteActiveShifts.clear();
    _activeShift = savedActiveShift != null && savedActiveShift.isActive
        ? savedActiveShift
        : null;
    _initialized = true;
    notifyListeners();
  }

  void loadHistory(List<WorkShiftRecord> savedHistory) {
    _history
      ..clear()
      ..addAll(savedHistory.where((shift) => !shift.isActive));
    _initialized = true;
    notifyListeners();
  }

  void loadRemoteActiveShifts(
    List<WorkShiftRecord> shifts, {
    String currentUserId = '',
  }) {
    final List<WorkShiftRecord> active = shifts
        .where((shift) => shift.isActive)
        .toList(growable: false);

    _remoteActiveShifts
      ..clear()
      ..addAll(active);

    if (currentUserId.isNotEmpty) {
      _activeShift = activeForUserFromList(currentUserId, active);
    } else if (active.length == 1) {
      _activeShift = active.first;
    }

    _initialized = true;
    notifyListeners();
  }

  void replaceDefinitionsFromRemote(List<ShiftDefinition> definitions) {
    _definitions
      ..clear()
      ..addAll(definitions);
    _initialized = true;
    notifyListeners();
  }

  void replaceHistoryFromRemote(List<WorkShiftRecord> shifts) {
    _history
      ..clear()
      ..addAll(shifts.where((shift) => !shift.isActive));
    _initialized = true;
    notifyListeners();
  }

  static const List<ShiftDefinition> defaultDefinitions = [
    ShiftDefinition(
      id: 'shift_day',
      name: 'Turno Día',
      scheduledStart: '08:00',
      scheduledEnd: '20:00',
      assignedUserId: 'demo_guardia',
    ),
    ShiftDefinition(
      id: 'shift_night',
      name: 'Turno Noche',
      scheduledStart: '20:00',
      scheduledEnd: '08:00',
      assignedUserId: 'demo_guardia_noche',
    ),
  ];

  ShiftDefinition? definitionById(String id) {
    for (final ShiftDefinition definition in _definitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return null;
  }

  ShiftDefinition? definitionForUser(AppUser user) {
    if (user.shiftId.isNotEmpty) {
      final ShiftDefinition? byId = definitionById(user.shiftId);
      if (byId != null) {
        return byId;
      }
    }

    for (final ShiftDefinition definition in _definitions) {
      if (definition.assignedUserId == user.id) {
        return definition;
      }
    }
    return null;
  }

  WorkShiftRecord? activeForUser(String userId) {
    return activeForUserFromList(userId, activeShifts);
  }

  WorkShiftRecord? activeForUserFromList(
    String userId,
    List<WorkShiftRecord> shifts,
  ) {
    for (final WorkShiftRecord shift in shifts) {
      if (shift.userId == userId && shift.isActive) {
        return shift;
      }
    }

    return null;
  }

  WorkShiftRecord? latestClosedForShift({
    required String shiftId,
    required String userId,
    required DateTime date,
  }) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final List<WorkShiftRecord> matching = _history.where((shift) {
      return shift.shiftId == shiftId &&
          shift.userId == userId &&
          shift.startedDate == day;
    }).toList();

    matching.sort((a, b) {
      final DateTime aEndedAt = a.actualEndedAt ?? a.actualStartedAt;
      final DateTime bEndedAt = b.actualEndedAt ?? b.actualStartedAt;
      return bEndedAt.compareTo(aEndedAt);
    });

    return matching.isEmpty ? null : matching.first;
  }

  Future<WorkShiftRecord> startShift(AppUser user) async {
    if (user.role != AppRole.guard || !user.isActive) {
      throw StateError('Solo un guardia activo puede iniciar turno.');
    }

    final WorkShiftRecord? current = _activeShift;
    if (current != null) {
      if (current.userId == user.id) {
        return current;
      }
      throw StateError('Ya existe otro turno activo en este dispositivo.');
    }

    final ShiftDefinition? definition = definitionForUser(user);
    if (definition == null || !definition.isActive) {
      throw StateError('El guardia no tiene un turno activo asignado.');
    }

    final DateTime now = DateTime.now();
    final WorkShiftRecord shift = WorkShiftRecord(
      id: '${user.id}_${now.microsecondsSinceEpoch}',
      userId: user.id,
      guardName: user.displayName,
      role: user.role.label,
      installation: user.installationName,
      shiftId: definition.id,
      shiftName: definition.name,
      scheduledStart: definition.scheduledStart,
      scheduledEnd: definition.scheduledEnd,
      actualStartedAt: now,
      actualEndedAt: null,
      isActive: true,
      syncStatus: SyncStatus.pending,
    );

    final saveFunction = onActiveShiftChanged;
    if (saveFunction == null) {
      throw StateError('No existe una función para guardar el turno activo.');
    }
    await saveFunction(shift);

    _activeShift = shift;
    _remoteActiveShifts
      ..clear()
      ..add(shift);
    notifyListeners();
    return shift;
  }

  Future<WorkShiftRecord> closeShift(String userId) async {
    final WorkShiftRecord? current = _activeShift;
    if (current == null || current.userId != userId) {
      throw StateError('No existe un turno activo para este guardia.');
    }

    final WorkShiftRecord closed = current.close(DateTime.now());
    final List<WorkShiftRecord> updatedHistory = List.from(_history);
    final int existingIndex = updatedHistory.indexWhere(
      (item) => item.id == closed.id,
    );

    if (existingIndex == -1) {
      updatedHistory.add(closed);
    } else {
      updatedHistory[existingIndex] = closed;
    }

    final historySave = onHistoryChanged;
    final activeSave = onActiveShiftChanged;
    if (historySave == null || activeSave == null) {
      throw StateError(
        'No existe una función para guardar el cierre de turno.',
      );
    }

    await historySave(List.unmodifiable(updatedHistory));
    await activeSave(null);

    _history
      ..clear()
      ..addAll(updatedHistory);
    _activeShift = null;
    _remoteActiveShifts.removeWhere((shift) => shift.id == current.id);
    notifyListeners();
    return closed;
  }

  Future<void> attachRoundToActiveShift({
    required String userId,
    required String roundId,
    required int noveltyCount,
  }) async {
    final WorkShiftRecord? current = _activeShift;
    if (current == null ||
        current.userId != userId ||
        current.roundIds.contains(roundId)) {
      return;
    }

    final WorkShiftRecord updated = current.withRound(
      roundId: roundId,
      noveltyCount: noveltyCount,
    );
    final saveFunction = onActiveShiftChanged;
    if (saveFunction == null) {
      throw StateError('No existe una función para guardar el turno activo.');
    }

    await saveFunction(updated);
    _activeShift = updated;
    notifyListeners();
  }

  Future<void> refreshActiveUser(AppUser user) async {
    final WorkShiftRecord? current = _activeShift;
    if (current == null || current.userId != user.id) {
      return;
    }

    final WorkShiftRecord refreshed = current.withUser(user);
    final saveFunction = onActiveShiftChanged;
    if (saveFunction == null) {
      throw StateError('No existe una función para guardar el turno activo.');
    }

    await saveFunction(refreshed);
    _activeShift = refreshed;
    notifyListeners();
  }

  Future<void> refreshActiveDefinition(ShiftDefinition definition) async {
    final WorkShiftRecord? current = _activeShift;
    if (current == null || current.shiftId != definition.id) {
      return;
    }

    final WorkShiftRecord refreshed = current.withDefinition(definition);
    final saveFunction = onActiveShiftChanged;
    if (saveFunction == null) {
      throw StateError('No existe una función para guardar el turno activo.');
    }

    await saveFunction(refreshed);
    _activeShift = refreshed;
    notifyListeners();
  }

  Future<void> saveDefinition(ShiftDefinition definition) async {
    if (!ShiftDefinition.isValidClockTime(definition.scheduledStart) ||
        !ShiftDefinition.isValidClockTime(definition.scheduledEnd)) {
      throw StateError('El horario debe usar el formato HH:mm.');
    }

    final List<ShiftDefinition> updated = _definitions.map((item) {
      if (definition.assignedUserId.isNotEmpty &&
          item.id != definition.id &&
          item.assignedUserId == definition.assignedUserId) {
        return item.copyWith(assignedUserId: '');
      }
      return item;
    }).toList();
    final int index = updated.indexWhere((item) => item.id == definition.id);

    if (index == -1) {
      updated.add(definition);
    } else {
      updated[index] = definition;
    }

    await _persistDefinitions(updated);
    await refreshActiveDefinition(definition);
  }

  Future<void> assignUser({
    required String shiftId,
    required String userId,
  }) async {
    final List<ShiftDefinition> updated = _definitions.map((definition) {
      if (definition.id == shiftId) {
        return definition.copyWith(assignedUserId: userId);
      }
      if (userId.isNotEmpty && definition.assignedUserId == userId) {
        return definition.copyWith(assignedUserId: '');
      }
      return definition;
    }).toList();

    await _persistDefinitions(updated);
  }

  Future<void> _persistDefinitions(List<ShiftDefinition> definitions) async {
    final saveFunction = onDefinitionsChanged;
    if (saveFunction == null) {
      throw StateError('No existe una función para guardar los turnos.');
    }

    await saveFunction(List.unmodifiable(definitions));
    _definitions
      ..clear()
      ..addAll(definitions);
    _initialized = true;
    notifyListeners();
  }
}
