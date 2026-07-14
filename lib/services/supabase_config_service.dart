import 'package:flutter/foundation.dart';

import '../auth_models.dart';
import '../control_points.dart';
import '../round_state.dart';
import '../user_accounts.dart';
import '../work_shifts.dart';
import 'supabase_auth_service.dart';
import 'supabase_service.dart';

class SupabaseConfigService {
  SupabaseConfigService._internal();

  static final SupabaseConfigService instance =
      SupabaseConfigService._internal();

  final Map<String, String> _remoteShiftIdsByLocalId = {};
  final Map<String, String> _localShiftIdsByRemoteId = {};

  String remoteShiftConfigId(String localShiftId) {
    return _remoteShiftIdsByLocalId[localShiftId] ?? localShiftId;
  }

  String localShiftId(String remoteShiftId) {
    return _localShiftIdsByRemoteId[remoteShiftId] ??
        normalizeSupabaseShiftId(remoteShiftId);
  }

  Future<void> loadForUser(AppUser user) async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    try {
      final List<Map<String, dynamic>> profiles = await _loadProfiles(
        installationId: user.installationId,
      );
      final Map<String, Map<String, dynamic>> installations =
          await _loadInstallationsForProfiles(profiles, user);

      final List<AppUser> remoteUsers = profiles
          .map((profile) {
            final String installationId = readSupabaseText(
              profile,
              'installation_id',
            );

            return appUserFromSupabaseProfile(
              profile: profile,
              authUser: null,
              installation: installations[installationId] ?? const {},
            );
          })
          .toList(growable: false);

      if (remoteUsers.isNotEmpty) {
        UserAccountStore.instance.replaceUsersFromRemote(remoteUsers);
      }

      final List<ShiftDefinition> shifts = await _loadShiftDefinitions(
        profiles: profiles,
      );
      if (shifts.isNotEmpty) {
        WorkShiftStore.instance.replaceDefinitionsFromRemote(shifts);
      }

      final List<ControlPointDefinition> points = await _loadControlPoints(
        installationId: user.installationId,
      );
      if (points.isNotEmpty) {
        ControlPointStore.instance.loadPoints(points);
        RoundState.instance.configureControlPoints(
          ControlPointStore.instance.activePoints,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('No fue posible cargar configuración Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw StateError('No se pudo cargar la configuración desde Supabase.');
    }
  }

  Future<List<Map<String, dynamic>>> _loadProfiles({
    required String installationId,
  }) async {
    final client = SupabaseService.instance.requireClient();
    dynamic query = client.from('profiles').select('*');

    if (installationId.isNotEmpty) {
      query = query.eq('installation_id', installationId);
    }

    final dynamic response = await query;
    return _rows(response);
  }

  Future<Map<String, Map<String, dynamic>>> _loadInstallationsForProfiles(
    List<Map<String, dynamic>> profiles,
    AppUser user,
  ) async {
    final client = SupabaseService.instance.requireClient();
    final Set<String> installationIds = profiles
        .map((profile) => readSupabaseText(profile, 'installation_id'))
        .where((id) => id.isNotEmpty)
        .toSet();

    if (user.installationId.isNotEmpty) {
      installationIds.add(user.installationId);
    }

    final Map<String, Map<String, dynamic>> result = {};
    for (final String installationId in installationIds) {
      try {
        final dynamic response = await client
            .from('installations')
            .select('*')
            .eq('id', installationId)
            .limit(1);
        final List<Map<String, dynamic>> rows = _rows(response);
        if (rows.isNotEmpty) {
          result[installationId] = rows.first;
        }
      } catch (error) {
        debugPrint('No fue posible leer instalación $installationId: $error');
      }
    }

    return result;
  }

  Future<List<ShiftDefinition>> _loadShiftDefinitions({
    required List<Map<String, dynamic>> profiles,
  }) async {
    final client = SupabaseService.instance.requireClient();
    final dynamic response = await client.from('shift_configs').select('*');
    final List<Map<String, dynamic>> rows = _rows(response);
    final List<ShiftDefinition> definitions = [];

    _remoteShiftIdsByLocalId.clear();
    _localShiftIdsByRemoteId.clear();

    for (int index = 0; index < rows.length; index++) {
      final Map<String, dynamic> row = rows[index];
      final String remoteId = readSupabaseText(row, 'id');
      final String code = _firstText(row, [
        'code',
        'shift_code',
        'assigned_shift_code',
        'slug',
      ]);
      final String localId = normalizeSupabaseShiftId(
        code.isNotEmpty ? code : remoteId,
      );
      final String name = _firstText(row, ['name', 'shift_name', 'label']);
      final String scheduledStart = _clockText(
        _firstText(row, [
          'scheduled_start',
          'scheduled_start_at',
          'start_time',
          'starts_at',
        ]),
        fallback: localId == 'shift_night' ? '20:00' : '08:00',
      );
      final String scheduledEnd = _clockText(
        _firstText(row, [
          'scheduled_end',
          'scheduled_end_at',
          'end_time',
          'ends_at',
        ]),
        fallback: localId == 'shift_night' ? '08:00' : '20:00',
      );
      final bool active = _readBool(row, 'is_active', fallback: true);
      final String assignedUserId = _assignedUserForShift(
        profiles: profiles,
        localShiftId: localId,
        code: code,
      );

      if (localId.isEmpty ||
          !ShiftDefinition.isValidClockTime(scheduledStart) ||
          !ShiftDefinition.isValidClockTime(scheduledEnd)) {
        continue;
      }

      _remoteShiftIdsByLocalId[localId] = remoteId.isNotEmpty
          ? remoteId
          : localId;
      if (remoteId.isNotEmpty) {
        _localShiftIdsByRemoteId[remoteId] = localId;
      }

      definitions.add(
        ShiftDefinition(
          id: localId,
          name: name.isNotEmpty ? name : shiftDisplayForSupabaseCode(code),
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          assignedUserId: assignedUserId,
          isActive: active,
        ),
      );
    }

    definitions.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return definitions;
  }

  Future<List<ControlPointDefinition>> _loadControlPoints({
    required String installationId,
  }) async {
    final client = SupabaseService.instance.requireClient();
    dynamic query = client.from('control_points').select('*');

    if (installationId.isNotEmpty) {
      query = query.eq('installation_id', installationId);
    }

    final dynamic response = await query;
    final List<Map<String, dynamic>> rows = _rows(response);
    final List<ControlPointDefinition> points = [];
    final Set<String> usedQr = {};

    for (int index = 0; index < rows.length; index++) {
      final Map<String, dynamic> row = rows[index];
      final String qrIdentifier = ControlPointDefinition.normalizeQrIdentifier(
        _firstText(row, ['qr_code', 'qr_identifier', 'identifier', 'code']),
      );
      final String name = _firstText(row, ['name', 'point_name', 'label']);

      if (qrIdentifier.isEmpty || name.isEmpty || !usedQr.add(qrIdentifier)) {
        continue;
      }

      points.add(
        ControlPointDefinition(
          id: readSupabaseText(row, 'id').isNotEmpty
              ? readSupabaseText(row, 'id')
              : 'supabase_$index',
          name: name,
          qrIdentifier: qrIdentifier,
          description: _firstText(row, ['description', 'location', 'address']),
          order: _readInt(row, 'order', fallback: index + 1),
          isActive: _readBool(row, 'is_active', fallback: true),
          iconKey: _iconKey(row),
        ),
      );
    }

    points.sort((a, b) => a.order.compareTo(b.order));
    return points;
  }

  String _assignedUserForShift({
    required List<Map<String, dynamic>> profiles,
    required String localShiftId,
    required String code,
  }) {
    for (final Map<String, dynamic> profile in profiles) {
      final String role = readSupabaseText(profile, 'role').toLowerCase();
      if (role != 'guard' && role != 'guardia' && role != 'security_guard') {
        continue;
      }

      final String profileShift = readSupabaseText(
        profile,
        'assigned_shift_code',
      );
      final String normalizedProfileShift = normalizeSupabaseShiftId(
        profileShift,
      );

      if (normalizedProfileShift == localShiftId ||
          (code.isNotEmpty &&
              profileShift.trim().toLowerCase() == code.trim().toLowerCase())) {
        return readSupabaseText(profile, 'id');
      }
    }

    return '';
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

  String _firstText(Map<String, dynamic> row, List<String> keys) {
    for (final String key in keys) {
      final String value = readSupabaseText(row, key);
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _clockText(String value, {required String fallback}) {
    final String trimmed = value.trim();
    final RegExpMatch? match = RegExp(
      r'([01]\d|2[0-3]):([0-5]\d)',
    ).firstMatch(trimmed);

    if (match == null) {
      return fallback;
    }

    return '${match.group(1)}:${match.group(2)}';
  }

  bool _readBool(
    Map<String, dynamic> row,
    String key, {
    required bool fallback,
  }) {
    final dynamic value = row[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  int _readInt(Map<String, dynamic> row, String key, {required int fallback}) {
    final dynamic value = row[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  String? _iconKey(Map<String, dynamic> row) {
    final String icon = _firstText(row, ['icon', 'icon_key', 'iconKey']);
    return ControlPointIcons.values.containsKey(icon) ? icon : null;
  }
}
