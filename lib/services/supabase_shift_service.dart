import 'package:flutter/foundation.dart';

import '../auth_models.dart';
import '../services/sync_status.dart';
import '../user_accounts.dart';
import '../work_shifts.dart';
import 'supabase_config_service.dart';
import 'supabase_service.dart';

class SupabaseShiftService {
  SupabaseShiftService._internal();

  static final SupabaseShiftService instance = SupabaseShiftService._internal();

  Future<WorkShiftRecord> startShift(AppUser user) async {
    if (!SupabaseService.instance.onlineMode) {
      return WorkShiftStore.instance.startShift(user);
    }

    final client = SupabaseService.instance.requireClient();
    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final WorkShiftRecord? existing = shiftStore.activeForUser(user.id);
    if (existing != null) {
      return existing;
    }

    if (user.role != AppRole.guard || !user.isActive) {
      throw StateError('Solo un guardia activo puede iniciar turno.');
    }

    final ShiftDefinition? definition = shiftStore.definitionForUser(user);
    if (definition == null || !definition.isActive) {
      throw StateError('El guardia no tiene un turno activo asignado.');
    }

    final DateTime now = DateTime.now();
    final DateTime scheduledStart = _scheduledDateTime(
      now,
      definition.scheduledStart,
    );
    DateTime scheduledEnd = _scheduledDateTime(now, definition.scheduledEnd);
    if (!scheduledEnd.isAfter(scheduledStart)) {
      scheduledEnd = scheduledEnd.add(const Duration(days: 1));
    }
    final String localId = '${user.id}_${now.microsecondsSinceEpoch}';

    try {
      final dynamic response = await client
          .from('work_shifts')
          .insert({
            'local_id': localId,
            'installation_id': user.installationId,
            'guard_id': user.id,
            'shift_config_id': SupabaseConfigService.instance
                .remoteShiftConfigId(definition.id),
            'shift_name': definition.name,
            'scheduled_start_at': scheduledStart.toUtc().toIso8601String(),
            'scheduled_end_at': scheduledEnd.toUtc().toIso8601String(),
            'actual_start_at': now.toUtc().toIso8601String(),
            'status': 'active',
            'device_id': SupabaseService.instance.deviceId,
          })
          .select('*')
          .single();

      final WorkShiftRecord shift = shiftFromSupabaseRow(
        Map<String, dynamic>.from(response as Map),
        fallbackUser: user,
        fallbackDefinition: definition,
      );

      shiftStore.loadRemoteActiveShifts([
        ...shiftStore.activeShifts.where((item) => item.userId != user.id),
        shift,
      ], currentUserId: user.id);

      return shift;
    } catch (error, stackTrace) {
      debugPrint('No fue posible iniciar turno Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw StateError('No fue posible iniciar el turno en Supabase.');
    }
  }

  Future<WorkShiftRecord> closeShift(AppUser user) async {
    if (!SupabaseService.instance.onlineMode) {
      return WorkShiftStore.instance.closeShift(user.id);
    }

    final client = SupabaseService.instance.requireClient();
    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final WorkShiftRecord? current = shiftStore.activeForUser(user.id);
    if (current == null) {
      throw StateError('No existe un turno activo para este guardia.');
    }

    final DateTime endedAt = DateTime.now();
    final int durationMinutes = endedAt
        .difference(current.actualStartedAt)
        .inMinutes;

    try {
      final dynamic response = await client
          .from('work_shifts')
          .update({
            'actual_end_at': endedAt.toUtc().toIso8601String(),
            'duration_minutes': durationMinutes < 0 ? 0 : durationMinutes,
            'status': 'closed',
          })
          .eq('id', current.id)
          .select('*')
          .single();

      final WorkShiftRecord closed = shiftFromSupabaseRow(
        Map<String, dynamic>.from(response as Map),
        fallbackUser: user,
        fallbackDefinition: shiftStore.definitionById(current.shiftId),
      );

      shiftStore.loadRemoteActiveShifts(
        shiftStore.activeShifts
            .where((shift) => shift.id != current.id)
            .toList(growable: false),
        currentUserId: user.id,
      );
      shiftStore.replaceHistoryFromRemote([closed, ...shiftStore.history]);

      return closed;
    } catch (error, stackTrace) {
      debugPrint('No fue posible cerrar turno Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw StateError('No fue posible cerrar el turno en Supabase.');
    }
  }

  Future<void> refreshForUser(AppUser user) async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    final List<WorkShiftRecord> active = await loadActiveShifts(user);
    final List<WorkShiftRecord> history = await loadShiftHistory(user);

    WorkShiftStore.instance.loadRemoteActiveShifts(
      active,
      currentUserId: user.id,
    );
    WorkShiftStore.instance.replaceHistoryFromRemote(history);
  }

  Future<List<WorkShiftRecord>> loadActiveShifts(AppUser user) async {
    final client = SupabaseService.instance.requireClient();

    try {
      final dynamic response;

      if (user.role == AppRole.guard) {
        response = await client
            .from('work_shifts')
            .select('*')
            .eq('status', 'active')
            .eq('guard_id', user.id)
            .order('actual_start_at', ascending: false);
      } else if (user.installationId.isNotEmpty) {
        response = await client
            .from('work_shifts')
            .select('*')
            .eq('status', 'active')
            .eq('installation_id', user.installationId)
            .order('actual_start_at', ascending: false);
      } else {
        response = await client
            .from('work_shifts')
            .select('*')
            .eq('status', 'active')
            .order('actual_start_at', ascending: false);
      }

      return _rows(
        response,
      ).map((row) => shiftFromSupabaseRow(row)).toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('No fue posible cargar turnos activos Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw StateError(
        'No fue posible cargar los turnos activos desde Supabase.',
      );
    }
  }

  Future<List<WorkShiftRecord>> loadShiftHistory(AppUser user) async {
    final client = SupabaseService.instance.requireClient();

    try {
      final dynamic response;

      if (user.role == AppRole.guard) {
        response = await client
            .from('work_shifts')
            .select('*')
            .neq('status', 'active')
            .eq('guard_id', user.id)
            .order('actual_start_at', ascending: false)
            .limit(100);
      } else if (user.installationId.isNotEmpty) {
        response = await client
            .from('work_shifts')
            .select('*')
            .neq('status', 'active')
            .eq('installation_id', user.installationId)
            .order('actual_start_at', ascending: false)
            .limit(100);
      } else {
        response = await client
            .from('work_shifts')
            .select('*')
            .neq('status', 'active')
            .order('actual_start_at', ascending: false)
            .limit(100);
      }

      return _rows(
        response,
      ).map((row) => shiftFromSupabaseRow(row)).toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('No fue posible cargar historial de turnos Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw StateError(
        'No fue posible cargar el historial de turnos desde Supabase.',
      );
    }
  }

  DateTime _scheduledDateTime(DateTime base, String clock) {
    final List<String> parts = clock.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

WorkShiftRecord shiftFromSupabaseRow(
  Map<String, dynamic> row, {
  AppUser? fallbackUser,
  ShiftDefinition? fallbackDefinition,
}) {
  final DateTime now = DateTime.now();
  final String id = _readText(row, 'id');
  final String userId = _readText(row, 'guard_id').isNotEmpty
      ? _readText(row, 'guard_id')
      : fallbackUser?.id ?? '';
  final AppUser? storedUser =
      fallbackUser ?? UserAccountStore.instance.accountById(userId)?.user;
  final String status = _readText(row, 'status').toLowerCase();
  final DateTime startedAt =
      _readDate(row, 'actual_start_at') ?? _readDate(row, 'started_at') ?? now;
  final DateTime? endedAt =
      _readDate(row, 'actual_end_at') ?? _readDate(row, 'ended_at');
  final String shiftName = _readText(row, 'shift_name').isNotEmpty
      ? _readText(row, 'shift_name')
      : fallbackDefinition?.name ?? 'Turno';
  final String shiftId =
      fallbackDefinition?.id ??
      SupabaseConfigService.instance.localShiftId(
        _readText(row, 'shift_config_id'),
      );

  return WorkShiftRecord(
    id: id.isNotEmpty ? id : _readText(row, 'local_id'),
    userId: userId,
    guardName: storedUser?.displayName ?? _readText(row, 'guard_name'),
    role: storedUser?.role.label ?? 'Guardia',
    installation:
        storedUser?.installationName ?? _readText(row, 'installation_name'),
    shiftId: shiftId.isNotEmpty ? shiftId : _readText(row, 'shift_config_id'),
    shiftName: shiftName,
    scheduledStart: _clockText(
      _readText(row, 'scheduled_start_at'),
      fallback: fallbackDefinition?.scheduledStart ?? '',
    ),
    scheduledEnd: _clockText(
      _readText(row, 'scheduled_end_at'),
      fallback: fallbackDefinition?.scheduledEnd ?? '',
    ),
    actualStartedAt: startedAt,
    actualEndedAt: endedAt,
    isActive: status == 'active' || endedAt == null,
    noveltyCount: _readInt(row, 'novelty_count'),
    syncStatus: SyncStatus.synced,
  );
}

String _readText(Map<String, dynamic> row, String key) {
  final dynamic value = row[key];
  return value == null ? '' : value.toString().trim();
}

DateTime? _readDate(Map<String, dynamic> row, String key) {
  final String value = _readText(row, key);
  if (value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

int _readInt(Map<String, dynamic> row, String key) {
  final dynamic value = row[key];
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _clockText(String value, {required String fallback}) {
  final RegExpMatch? match = RegExp(
    r'([01]\d|2[0-3]):([0-5]\d)',
  ).firstMatch(value);
  if (match == null) {
    return fallback;
  }
  return '${match.group(1)}:${match.group(2)}';
}
