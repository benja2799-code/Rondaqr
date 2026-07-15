import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final String installationId = user.installationId.trim();
      if (installationId.isEmpty) {
        throw StateError(
          'El usuario no tiene una instalación asignada en Supabase.',
        );
      }

      final List<Map<String, dynamic>> profiles = await _loadProfiles(
        installationId: installationId,
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
        installationId: installationId,
      );
      ControlPointStore.instance.loadPoints(points);
      RoundState.instance.configureControlPoints(
        ControlPointStore.instance.activePoints,
      );
      debugPrint(
        'RondaQR puntos cargados | user_id: ${user.id} | '
        'installation_id: $installationId | total: ${points.length} | '
        'activos: ${points.where((point) => point.isActive).length}',
      );
    } catch (error, stackTrace) {
      debugPrint('No fue posible cargar configuración Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (SupabaseService.instance.isLikelyNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      if (error is StateError) {
        rethrow;
      }
      throw StateError('No se pudo cargar la configuración desde Supabase.');
    }
  }

  Future<List<ControlPointDefinition>> replaceControlPointsForUser({
    required AppUser user,
    required List<ControlPointDefinition> points,
  }) async {
    if (!SupabaseService.instance.onlineMode) {
      return points;
    }

    if (!user.can(AppPermission.manageControlPoints)) {
      throw StateError('Tu usuario no tiene permiso para modificar puntos.');
    }

    final String installationId = user.installationId.trim();
    if (installationId.isEmpty) {
      throw StateError(
        'El administrador no tiene una instalación asignada en Supabase.',
      );
    }

    final Set<String> qrIdentifiers = {};
    for (final ControlPointDefinition point in points) {
      final String qrIdentifier = ControlPointDefinition.normalizeQrIdentifier(
        point.qrIdentifier,
      );
      if (qrIdentifier.isEmpty || !qrIdentifiers.add(qrIdentifier)) {
        throw StateError('Los identificadores QR deben ser únicos.');
      }
    }

    final SupabaseClient client = SupabaseService.instance.requireClient();

    try {
      final List<Map<String, dynamic>> existingRows = _rows(
        await client
            .from('control_points')
            .select(_controlPointColumns)
            .eq('installation_id', installationId),
      );
      final Map<String, Map<String, dynamic>> existingById = {
        for (final Map<String, dynamic> row in existingRows)
          readSupabaseText(row, 'id'): row,
      };
      final Map<String, Map<String, dynamic>> existingByQr = {
        for (final Map<String, dynamic> row in existingRows)
          ControlPointDefinition.normalizeQrIdentifier(
            readSupabaseText(row, 'qr_code'),
          ): row,
      };
      final Set<String> retainedRemoteIds = {};

      for (final ControlPointDefinition point in points) {
        final String qrIdentifier =
            ControlPointDefinition.normalizeQrIdentifier(point.qrIdentifier);
        final Map<String, dynamic>? existing =
            existingById[point.id] ?? existingByQr[qrIdentifier];
        final Map<String, dynamic> values = {
          'installation_id': installationId,
          'name': point.name.trim(),
          'description': point.description.trim(),
          'qr_code': qrIdentifier,
          'display_order': point.order,
          'is_active': point.isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        if (existing == null) {
          final dynamic inserted = await client
              .from('control_points')
              .insert(values)
              .select(_controlPointColumns)
              .single();
          retainedRemoteIds.add(
            readSupabaseText(Map<String, dynamic>.from(inserted as Map), 'id'),
          );
          continue;
        }

        final String remoteId = readSupabaseText(existing, 'id');
        if (remoteId.isEmpty) {
          throw StateError('Supabase devolvió un punto sin identificador.');
        }

        await client
            .from('control_points')
            .update(values)
            .eq('id', remoteId)
            .eq('installation_id', installationId);
        retainedRemoteIds.add(remoteId);
      }

      for (final Map<String, dynamic> existing in existingRows) {
        final String remoteId = readSupabaseText(existing, 'id');
        if (remoteId.isEmpty || retainedRemoteIds.contains(remoteId)) {
          continue;
        }

        await client
            .from('control_points')
            .delete()
            .eq('id', remoteId)
            .eq('installation_id', installationId);
      }

      final List<ControlPointDefinition> saved = await _loadControlPoints(
        installationId: installationId,
      );
      if (!_sameControlPointConfiguration(points, saved)) {
        throw StateError(
          'Supabase no confirmó los cambios de puntos. Revisa los permisos '
          'RLS del Administrador.',
        );
      }
      debugPrint(
        'RondaQR puntos Supabase | installation_id: $installationId | '
        'guardados: ${saved.length} | activos: '
        '${saved.where((point) => point.isActive).length}',
      );
      return saved;
    } catch (error, stackTrace) {
      debugPrint('No fue posible guardar puntos en Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      _throwControlPointSaveError(error);
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
    dynamic query = client.from('control_points').select(_controlPointColumns);

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
          order: _readInt(row, 'display_order', fallback: index + 1),
          isActive: _readBool(row, 'is_active', fallback: true),
          iconKey: _iconKey(row),
        ),
      );
    }

    points.sort((a, b) => a.order.compareTo(b.order));
    return points;
  }

  Never _throwControlPointSaveError(Object error) {
    if (SupabaseService.instance.isLikelyNetworkError(error)) {
      throw StateError(
        'Sin conexión. No fue posible guardar los puntos en Supabase.',
      );
    }

    final String text = error.toString().toLowerCase();
    if ((error is PostgrestException && error.code == '23505') ||
        text.contains('duplicate') ||
        text.contains('unique')) {
      throw StateError('El identificador QR ya está en uso.');
    }

    if ((error is PostgrestException && error.code == '23503') ||
        text.contains('foreign key')) {
      throw StateError(
        'Este punto tiene registros históricos y no puede eliminarse. '
        'Puedes dejarlo inactivo.',
      );
    }

    if ((error is PostgrestException && error.code == '42501') ||
        text.contains('row-level security') ||
        text.contains('permission denied') ||
        text.contains('rls')) {
      throw StateError(
        'Supabase no permite modificar puntos con este usuario. Revisa los '
        'permisos RLS del Administrador.',
      );
    }

    if (error is StateError) {
      throw error;
    }

    throw StateError('No fue posible guardar los puntos en Supabase.');
  }

  bool _sameControlPointConfiguration(
    List<ControlPointDefinition> expected,
    List<ControlPointDefinition> saved,
  ) {
    if (expected.length != saved.length) {
      return false;
    }

    final Map<String, ControlPointDefinition> savedByQr = {
      for (final ControlPointDefinition point in saved)
        ControlPointDefinition.normalizeQrIdentifier(point.qrIdentifier): point,
    };

    for (final ControlPointDefinition point in expected) {
      final String qrIdentifier = ControlPointDefinition.normalizeQrIdentifier(
        point.qrIdentifier,
      );
      final ControlPointDefinition? remote = savedByQr[qrIdentifier];
      if (remote == null ||
          remote.name.trim() != point.name.trim() ||
          remote.description.trim() != point.description.trim() ||
          remote.order != point.order ||
          remote.isActive != point.isActive) {
        return false;
      }
    }

    return true;
  }

  static const String _controlPointColumns =
      'id,installation_id,name,description,qr_code,display_order,is_active,'
      'created_at,updated_at';

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
