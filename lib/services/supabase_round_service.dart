import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_models.dart';
import '../round_history.dart';
import '../round_state.dart';
import '../services/sync_status.dart';
import '../user_accounts.dart';
import '../work_shifts.dart';
import 'supabase_service.dart';

class OnlinePointRegistration {
  final String roundPointId;
  final DateTime scannedAt;

  const OnlinePointRegistration({
    required this.roundPointId,
    required this.scannedAt,
  });
}

class SupabaseRoundStartException implements Exception {
  final String message;
  final Object? cause;

  const SupabaseRoundStartException(this.message, {this.cause});

  @override
  String toString() => message;
}

class SupabasePointRegistrationException implements Exception {
  final String message;
  final Object? cause;

  const SupabasePointRegistrationException(this.message, {this.cause});

  @override
  String toString() => message;
}

class SupabaseRoundFinishException implements Exception {
  final String message;
  final Object? cause;

  const SupabaseRoundFinishException(this.message, {this.cause});

  @override
  String toString() => message;
}

class SupabaseHistoryLoadException implements Exception {
  final String message;
  final String technicalDetail;
  final Object? cause;

  const SupabaseHistoryLoadException(
    this.message, {
    this.technicalDetail = '',
    this.cause,
  });

  @override
  String toString() => message;
}

class _RoundPointCounters {
  final int completedPoints;
  final int noveltiesCount;

  const _RoundPointCounters({
    required this.completedPoints,
    required this.noveltiesCount,
  });
}

class SupabaseRoundService {
  SupabaseRoundService._internal();

  static final SupabaseRoundService instance = SupabaseRoundService._internal();

  String buildRoundLocalId({required String userId, DateTime? dateTime}) {
    final DateTime now = dateTime ?? DateTime.now();
    final String date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final String time =
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final String cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '');
    final String userPart =
        (cleanUserId.length > 8 ? cleanUserId.substring(0, 8) : cleanUserId)
            .ifEmpty('guard');

    return 'round_${date}_${time}_${now.microsecondsSinceEpoch}_$userPart';
  }

  String buildPointLocalId({required String userId, DateTime? dateTime}) {
    return _buildOperationalLocalId(
      prefix: 'point',
      userId: userId,
      dateTime: dateTime,
    );
  }

  String buildNoveltyLocalId({required String userId, DateTime? dateTime}) {
    return _buildOperationalLocalId(
      prefix: 'novelty',
      userId: userId,
      dateTime: dateTime,
    );
  }

  String _buildOperationalLocalId({
    required String prefix,
    required String userId,
    DateTime? dateTime,
  }) {
    final DateTime now = dateTime ?? DateTime.now();
    final String date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final String time =
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final String cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '');
    final String userPart =
        (cleanUserId.length > 8 ? cleanUserId.substring(0, 8) : cleanUserId)
            .ifEmpty('guard');

    return '${prefix}_${date}_${time}_${now.microsecondsSinceEpoch}_$userPart';
  }

  bool isSupabaseUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  Future<String> startRound({
    required AppUser user,
    required WorkShiftRecord shift,
    required int totalPoints,
    required String localId,
  }) async {
    if (!SupabaseService.instance.onlineMode) {
      return '';
    }

    final client = SupabaseService.instance.requireClient();
    final DateTime now = DateTime.now();

    if (!isSupabaseUuid(shift.id)) {
      throw const SupabaseRoundStartException(
        'Error al asociar la ronda con el turno activo.',
      );
    }

    if (localId.trim().isEmpty || localId.trim() == user.id) {
      throw const SupabaseRoundStartException(
        'Error: identificador local de ronda duplicado.',
      );
    }

    try {
      final dynamic existingResponse = await client
          .from('rounds')
          .select('id,local_id,status,started_at')
          .eq('guard_id', user.id)
          .eq('work_shift_id', shift.id)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1);
      final List<Map<String, dynamic>> existingRows = _rows(existingResponse);
      if (existingRows.isNotEmpty) {
        final String existingRoundId = _readText(existingRows.first, 'id');
        if (existingRoundId.isNotEmpty) {
          debugPrint(
            'RondaQR iniciar ronda | ya existe ronda activa para este turno: '
            '$existingRoundId',
          );
          return existingRoundId;
        }
      }

      final dynamic response = await client
          .from('rounds')
          .insert({
            'local_id': localId,
            'installation_id': user.installationId,
            'guard_id': user.id,
            'work_shift_id': shift.id,
            'started_at': now.toUtc().toIso8601String(),
            'status': 'active',
            'total_points': totalPoints,
            'completed_points': 0,
            'novelties_count': 0,
            'device_id': SupabaseService.instance.deviceId,
          })
          .select('*')
          .single();

      return _readText(Map<String, dynamic>.from(response as Map), 'id');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('No fue posible iniciar ronda Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw SupabaseRoundStartException(
        _messageForRoundInsertError(error),
        cause: error,
      );
    } on SupabaseRoundStartException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('No fue posible iniciar ronda Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_looksLikeNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw SupabaseRoundStartException(
        'No se pudo iniciar la ronda en Supabase.',
        cause: error,
      );
    }
  }

  String _messageForRoundInsertError(PostgrestException error) {
    final String code = (error.code ?? '').trim();
    final String text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();

    if (code == '42501' ||
        text.contains('row-level security') ||
        text.contains('rls') ||
        text.contains('permission denied') ||
        text.contains('not authorized')) {
      return 'Error de permisos en Supabase al iniciar ronda.';
    }

    if (code == '23503' ||
        text.contains('foreign key') ||
        text.contains('work_shift_id') ||
        text.contains('work shifts') ||
        text.contains('work_shifts')) {
      return 'Error al asociar la ronda con el turno activo.';
    }

    if (code == '23505' ||
        text.contains('duplicate') ||
        text.contains('duplicado') ||
        text.contains('local_id')) {
      return 'Error: identificador local de ronda duplicado.';
    }

    return 'No se pudo iniciar la ronda en Supabase.';
  }

  bool _looksLikeNetworkError(Object error) {
    return SupabaseService.instance.isLikelyNetworkError(error);
  }

  Future<OnlinePointRegistration> registerPoint({
    required AppUser user,
    required RoundOperationalContext context,
    required RoundPoint point,
    required bool hasNovelty,
    required String observation,
  }) async {
    if (!SupabaseService.instance.onlineMode) {
      return OnlinePointRegistration(
        roundPointId: '',
        scannedAt: DateTime.now(),
      );
    }

    final SupabaseClient client;
    try {
      client = SupabaseService.instance.requireClient();
    } catch (_) {
      SupabaseService.instance.throwOnlineRequired();
    }

    final User? authUser = client.auth.currentUser;
    final String authUid = authUser?.id.trim() ?? '';
    final String roundId = context.onlineRoundId.trim();
    final String controlPointId = point.id.trim();
    final String installationId = user.installationId.trim();
    final String qrCode = 'RONDAQR:${point.qrIdentifier}';
    final DateTime scannedAt = DateTime.now();
    final String localIdUser = authUid.isNotEmpty ? authUid : user.id;
    final String roundPointLocalId = buildPointLocalId(
      userId: localIdUser,
      dateTime: scannedAt,
    );
    final String noveltyLocalId = hasNovelty
        ? buildNoveltyLocalId(userId: localIdUser)
        : '';

    _logPointRegistrationAttempt(
      authUid: authUid,
      user: user,
      installationId: installationId,
      context: context,
      point: point,
      qrCode: qrCode,
      hasNovelty: hasNovelty,
      observation: observation,
      roundPointLocalId: roundPointLocalId,
      noveltyLocalId: noveltyLocalId,
    );

    if (authUid.isEmpty) {
      throw const SupabasePointRegistrationException(
        'Error de permisos en Supabase al registrar el punto. Revisar RLS.',
      );
    }

    if (authUid != user.id) {
      debugPrint(
        'RondaQR confirmar punto | advertencia: auth.uid ($authUid) '
        'no coincide con profile.id (${user.id}). Se usará auth.uid como guard_id.',
      );
    }

    if (roundId.isEmpty || !isSupabaseUuid(roundId)) {
      throw const SupabasePointRegistrationException(
        'No existe una ronda activa válida.',
      );
    }

    if (controlPointId.isEmpty || !isSupabaseUuid(controlPointId)) {
      throw const SupabasePointRegistrationException(
        'El punto QR no existe o no está activo.',
      );
    }

    if (installationId.isEmpty) {
      throw const SupabasePointRegistrationException(
        'El punto QR no existe o no está activo.',
      );
    }

    final dynamic duplicates = await _runSupabasePointOperation(
      table: 'round_points',
      action: 'validar punto duplicado',
      fallbackMessage: 'No se pudo registrar el punto en Supabase.',
      operation: () {
        return client
            .from('round_points')
            .select('id')
            .eq('round_id', roundId)
            .eq('control_point_id', controlPointId)
            .limit(1);
      },
    );

    if (_rows(duplicates).isNotEmpty) {
      throw StateError('Este punto ya fue registrado en la ronda actual.');
    }

    final dynamic response = await _runSupabasePointOperation(
      table: 'round_points',
      action: 'insertar punto registrado',
      fallbackMessage: 'No se pudo registrar el punto en Supabase.',
      operation: () {
        return client
            .from('round_points')
            .insert({
              'local_id': roundPointLocalId,
              'installation_id': installationId,
              'guard_id': authUid,
              'round_id': roundId,
              'control_point_id': controlPointId,
              'point_name': point.name,
              'qr_code': qrCode,
              'scanned_at': scannedAt.toUtc().toIso8601String(),
              'has_novelty': hasNovelty,
              'observation': observation,
              'sync_status': SyncStatus.synced.storageValue,
              'device_id': SupabaseService.instance.deviceId,
            })
            .select('*')
            .single();
      },
    );

    final Map<String, dynamic> row = Map<String, dynamic>.from(response as Map);
    final String roundPointId = _readText(row, 'id');

    if (roundPointId.isEmpty) {
      throw const SupabasePointRegistrationException(
        'No se pudo registrar el punto en Supabase.',
      );
    }

    if (hasNovelty) {
      await _runSupabasePointOperation(
        table: 'novelties',
        action: 'insertar novedad',
        fallbackMessage: 'No se pudo registrar la novedad en Supabase.',
        operation: () {
          return client.from('novelties').insert({
            'local_id': noveltyLocalId,
            'installation_id': installationId,
            'guard_id': authUid,
            'round_id': roundId,
            'round_point_id': roundPointId,
            'control_point_id': controlPointId,
            'occurred_at': scannedAt.toUtc().toIso8601String(),
            'point_name': point.name,
            'description': observation,
            'status': 'open',
            'sync_status': SyncStatus.synced.storageValue,
            'device_id': SupabaseService.instance.deviceId,
          });
        },
      );
    }

    final int completedAfter = RoundState.instance.points.where((candidate) {
      return candidate.completed || candidate.id == point.id;
    }).length;
    final int noveltiesAfter = RoundState.instance.points.where((candidate) {
      if (candidate.id == point.id) {
        return hasNovelty;
      }

      return candidate.completed && candidate.hasNovelty;
    }).length;

    await _runSupabasePointOperation(
      table: 'rounds',
      action: 'actualizar avance',
      fallbackMessage: 'No se pudo actualizar el avance de la ronda.',
      operation: () {
        return client
            .from('rounds')
            .update({
              'completed_points': completedAfter,
              'novelties_count': noveltiesAfter,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', roundId);
      },
    );

    return OnlinePointRegistration(
      roundPointId: roundPointId,
      scannedAt: scannedAt,
    );
  }

  Future<dynamic> _runSupabasePointOperation({
    required String table,
    required String action,
    required String fallbackMessage,
    required dynamic Function() operation,
  }) async {
    try {
      return await operation();
    } on PostgrestException catch (error, stackTrace) {
      _logSupabaseFailure(
        table: table,
        action: action,
        error: error,
        stackTrace: stackTrace,
      );
      throw SupabasePointRegistrationException(
        _messageForPointOperationError(error, fallbackMessage),
        cause: error,
      );
    } catch (error, stackTrace) {
      _logSupabaseFailure(
        table: table,
        action: action,
        error: error,
        stackTrace: stackTrace,
      );

      if (_looksLikeNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }

      throw SupabasePointRegistrationException(fallbackMessage, cause: error);
    }
  }

  String _messageForPointOperationError(
    PostgrestException error,
    String fallbackMessage,
  ) {
    final String code = (error.code ?? '').trim();
    final String text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();

    if (code == '42501' ||
        text.contains('row-level security') ||
        text.contains('rls') ||
        text.contains('permission denied') ||
        text.contains('not authorized')) {
      return 'Error de permisos en Supabase al registrar el punto. Revisar RLS.';
    }

    return fallbackMessage;
  }

  void _logPointRegistrationAttempt({
    required String authUid,
    required AppUser user,
    required String installationId,
    required RoundOperationalContext context,
    required RoundPoint point,
    required String qrCode,
    required bool hasNovelty,
    required String observation,
    required String roundPointLocalId,
    required String noveltyLocalId,
  }) {
    debugPrint('RondaQR confirmar punto | auth.uid: $authUid');
    debugPrint('RondaQR confirmar punto | profile.id: ${user.id}');
    debugPrint('RondaQR confirmar punto | profile.email: ${user.email}');
    debugPrint('RondaQR confirmar punto | installation_id: $installationId');
    debugPrint(
      'RondaQR confirmar punto | active round_id: ${context.onlineRoundId}',
    );
    debugPrint(
      'RondaQR confirmar punto | active round local_id: '
      '${context.onlineRoundLocalId}',
    );
    debugPrint('RondaQR confirmar punto | control_point_id: ${point.id}');
    debugPrint('RondaQR confirmar punto | qr_code: $qrCode');
    debugPrint('RondaQR confirmar punto | point_name: ${point.name}');
    debugPrint('RondaQR confirmar punto | has_novelty: $hasNovelty');
    debugPrint('RondaQR confirmar punto | observation: $observation');
    debugPrint(
      'RondaQR confirmar punto | generated round_point local_id: '
      '$roundPointLocalId',
    );

    if (noveltyLocalId.isNotEmpty) {
      debugPrint(
        'RondaQR confirmar punto | generated novelty local_id: '
        '$noveltyLocalId',
      );
    }
  }

  void _logSupabaseFailure({
    required String table,
    required String action,
    required Object error,
    StackTrace? stackTrace,
  }) {
    debugPrint('RondaQR Supabase error | tabla: $table | accion: $action');

    if (error is PostgrestException) {
      debugPrint('RondaQR Supabase error | codigo: ${error.code ?? ''}');
      debugPrint('RondaQR Supabase error | mensaje: ${error.message}');
      debugPrint('RondaQR Supabase error | detalles: ${error.details ?? ''}');
      debugPrint('RondaQR Supabase error | hint: ${error.hint ?? ''}');
    } else {
      debugPrint('RondaQR Supabase error | error: $error');
    }

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> finishRound({
    required RoundState roundState,
    required AppUser user,
    DateTime? finishedAt,
  }) async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    final SupabaseClient client;
    try {
      client = SupabaseService.instance.requireClient();
    } catch (_) {
      SupabaseService.instance.throwOnlineRequired();
    }

    final User? authUser = client.auth.currentUser;
    final String authUid = authUser?.id.trim() ?? '';
    final RoundOperationalContext? context = roundState.operationalContext;
    final String installationId = user.installationId.trim();
    final int memoryTotalPoints = roundState.totalPoints;
    final int memoryCompletedPoints = roundState.completedPoints;
    final int memoryNoveltyCount = roundState.points
        .where((point) => point.completed && point.hasNovelty)
        .length;
    final WorkShiftRecord? activeShift = WorkShiftStore.instance.activeForUser(
      user.id,
    );
    String workShiftId = context?.shiftRecordId.trim() ?? '';
    if (!isSupabaseUuid(workShiftId)) {
      workShiftId = activeShift?.id.trim() ?? '';
    }

    if (authUid.isEmpty || authUid != user.id) {
      throw const SupabaseRoundFinishException(
        'Error de permisos en Supabase al finalizar ronda. Revisar RLS.',
      );
    }

    if (installationId.isEmpty) {
      throw const SupabaseRoundFinishException(
        'No existe una ronda activa para finalizar.',
      );
    }

    if (!isSupabaseUuid(workShiftId)) {
      workShiftId = await _findActiveWorkShiftId(
        client: client,
        authUid: authUid,
        installationId: installationId,
      );
    }

    if (!isSupabaseUuid(workShiftId)) {
      throw const SupabaseRoundFinishException(
        'No existe una ronda activa para finalizar.',
      );
    }

    if (activeShift != null && activeShift.id != workShiftId) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }

    Map<String, dynamic>? candidateRoundRow = await _loadRoundForFinishById(
      client: client,
      roundId: context?.onlineRoundId.trim() ?? '',
    );
    candidateRoundRow ??= await _loadLatestActiveRoundForFinish(
      client: client,
      authUid: authUid,
      installationId: installationId,
      workShiftId: workShiftId,
    );
    final String roundId = _readText(
      candidateRoundRow ?? const <String, dynamic>{},
      'id',
    );
    if (!isSupabaseUuid(roundId)) {
      throw const SupabaseRoundFinishException(
        'No existe una ronda activa para finalizar.',
      );
    }

    final dynamic roundResponse = await _runSupabaseRoundFinishOperation(
      table: 'rounds',
      action: 'leer ronda activa',
      fallbackMessage: 'No se encontró la ronda en Supabase.',
      operation: () {
        return client
            .from('rounds')
            .select(
              'id,installation_id,guard_id,work_shift_id,status,total_points,completed_points,novelties_count',
            )
            .eq('id', roundId)
            .limit(1);
      },
    );

    final List<Map<String, dynamic>> rows = _rows(roundResponse);
    if (rows.isEmpty) {
      throw const SupabaseRoundFinishException(
        'No se encontró la ronda en Supabase.',
      );
    }

    final Map<String, dynamic> roundRow = rows.first;
    final String currentStatus = _readText(
      roundRow,
      'status',
    ).ifEmpty('active');
    debugPrint('RondaQR finalizar ronda | status actual: $currentStatus');

    _logRoundFinishAttempt(
      authUid: authUid,
      profileId: user.id,
      profileEmail: user.email,
      installationId: installationId,
      roundId: roundId,
      roundLocalId: context?.onlineRoundLocalId.trim() ?? '',
      workShiftId: workShiftId,
      totalPoints: memoryTotalPoints,
      completedPoints: memoryCompletedPoints,
      noveltyCount: memoryNoveltyCount,
      currentStatus: currentStatus,
    );

    if (_readText(roundRow, 'guard_id') != authUid) {
      throw const SupabaseRoundFinishException(
        'La ronda activa no pertenece al usuario actual.',
      );
    }

    if (_readText(roundRow, 'installation_id') != installationId ||
        _readText(roundRow, 'work_shift_id') != workShiftId) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }

    final int activeTotalPoints = await _countActiveControlPoints(
      client: client,
      installationId: installationId,
    );
    final _RoundPointCounters onlineCounters = await _countRoundPoints(
      client: client,
      roundId: roundId,
    );

    debugPrint(
      'RondaQR finalizar ronda | total_points activos Supabase: '
      '$activeTotalPoints',
    );
    debugPrint(
      'RondaQR finalizar ronda | completed_points desde round_points: '
      '${onlineCounters.completedPoints}',
    );
    debugPrint(
      'RondaQR finalizar ronda | novelties_count desde round_points: '
      '${onlineCounters.noveltiesCount}',
    );
    debugPrint('RondaQR finalizar ronda | status nuevo: completed');

    if (activeTotalPoints <= 0) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }

    if (onlineCounters.completedPoints < activeTotalPoints) {
      throw const SupabaseRoundFinishException(
        'Debes completar todos los puntos activos antes de finalizar.',
      );
    }

    final DateTime finishTime = finishedAt ?? DateTime.now();

    final dynamic updateResponse = await _runSupabaseRoundFinishOperation(
      table: 'rounds',
      action: 'finalizar ronda',
      fallbackMessage: 'No se pudo finalizar la ronda en Supabase.',
      operation: () {
        return client
            .from('rounds')
            .update({
              'status': 'completed',
              'finished_at': finishTime.toUtc().toIso8601String(),
              'total_points': activeTotalPoints,
              'completed_points': onlineCounters.completedPoints,
              'novelties_count': onlineCounters.noveltiesCount,
              'updated_at': finishTime.toUtc().toIso8601String(),
            })
            .eq('id', roundId)
            .eq('guard_id', authUid)
            .select(
              'id,status,finished_at,total_points,completed_points,novelties_count',
            )
            .single();
      },
    );

    if (updateResponse is! Map) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }

    final Map<String, dynamic> updatedRow = Map<String, dynamic>.from(
      updateResponse,
    );
    debugPrint('RondaQR finalizar ronda | respuesta update: $updatedRow');

    if (_readText(updatedRow, 'status') != 'completed' ||
        _readText(updatedRow, 'finished_at').isEmpty) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }

    final dynamic verificationResponse = await _runSupabaseRoundFinishOperation(
      table: 'rounds',
      action: 'validar ronda finalizada',
      fallbackMessage: 'No se pudo finalizar la ronda en Supabase.',
      operation: () {
        return client
            .from('rounds')
            .select(
              'id,status,finished_at,total_points,completed_points,novelties_count',
            )
            .eq('id', roundId)
            .limit(1);
      },
    );

    final List<Map<String, dynamic>> verificationRows = _rows(
      verificationResponse,
    );
    if (verificationRows.isEmpty) {
      throw const SupabaseRoundFinishException(
        'No se encontró la ronda en Supabase.',
      );
    }

    final Map<String, dynamic> finalRow = verificationRows.first;
    debugPrint(
      'RondaQR finalizar ronda | status final leído desde Supabase: '
      '${_readText(finalRow, 'status')}',
    );
    debugPrint(
      'RondaQR finalizar ronda | finished_at final leído desde Supabase: '
      '${_readText(finalRow, 'finished_at')}',
    );
    debugPrint('RondaQR finalizar ronda | flujo Supabase finalizado: ok');

    if (_readText(finalRow, 'status') != 'completed' ||
        _readText(finalRow, 'finished_at').isEmpty) {
      throw const SupabaseRoundFinishException(
        'No se pudo finalizar la ronda en Supabase.',
      );
    }
  }

  Future<String> _findActiveWorkShiftId({
    required SupabaseClient client,
    required String authUid,
    required String installationId,
  }) async {
    final dynamic response = await _runSupabaseRoundFinishOperation(
      table: 'work_shifts',
      action: 'buscar turno activo',
      fallbackMessage: 'No existe una ronda activa para finalizar.',
      operation: () {
        return client
            .from('work_shifts')
            .select('id,status,actual_start_at')
            .eq('guard_id', authUid)
            .eq('installation_id', installationId)
            .eq('status', 'active')
            .order('actual_start_at', ascending: false)
            .limit(1);
      },
    );

    final List<Map<String, dynamic>> rows = _rows(response);
    return rows.isEmpty ? '' : _readText(rows.first, 'id');
  }

  Future<Map<String, dynamic>?> _loadRoundForFinishById({
    required SupabaseClient client,
    required String roundId,
  }) async {
    if (!isSupabaseUuid(roundId)) {
      return null;
    }

    final dynamic response = await _runSupabaseRoundFinishOperation(
      table: 'rounds',
      action: 'leer ronda activa por id',
      fallbackMessage: 'No se encontró la ronda en Supabase.',
      operation: () {
        return client
            .from('rounds')
            .select(
              'id,local_id,installation_id,guard_id,work_shift_id,status,total_points,completed_points,novelties_count',
            )
            .eq('id', roundId)
            .limit(1);
      },
    );

    final List<Map<String, dynamic>> rows = _rows(response);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> _loadLatestActiveRoundForFinish({
    required SupabaseClient client,
    required String authUid,
    required String installationId,
    required String workShiftId,
  }) async {
    final dynamic response = await _runSupabaseRoundFinishOperation(
      table: 'rounds',
      action: 'buscar ronda activa',
      fallbackMessage: 'No se encontró la ronda en Supabase.',
      operation: () {
        return client
            .from('rounds')
            .select(
              'id,local_id,installation_id,guard_id,work_shift_id,status,total_points,completed_points,novelties_count,started_at',
            )
            .eq('guard_id', authUid)
            .eq('installation_id', installationId)
            .eq('work_shift_id', workShiftId)
            .eq('status', 'active')
            .order('started_at', ascending: false)
            .limit(1);
      },
    );

    final List<Map<String, dynamic>> rows = _rows(response);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> _countActiveControlPoints({
    required SupabaseClient client,
    required String installationId,
  }) async {
    final dynamic response = await _runSupabaseRoundFinishOperation(
      table: 'control_points',
      action: 'contar puntos activos',
      fallbackMessage: 'No se pudo finalizar la ronda en Supabase.',
      operation: () {
        return client
            .from('control_points')
            .select('id')
            .eq('installation_id', installationId)
            .eq('is_active', true);
      },
    );

    return _rows(response).length;
  }

  Future<_RoundPointCounters> _countRoundPoints({
    required SupabaseClient client,
    required String roundId,
  }) async {
    final dynamic response = await _runSupabaseRoundFinishOperation(
      table: 'round_points',
      action: 'contar puntos registrados',
      fallbackMessage: 'No se pudo finalizar la ronda en Supabase.',
      operation: () {
        return client
            .from('round_points')
            .select('control_point_id,has_novelty')
            .eq('round_id', roundId);
      },
    );

    final Set<String> completedControlPoints = {};
    int noveltiesCount = 0;
    for (final Map<String, dynamic> row in _rows(response)) {
      final String controlPointId = _readText(row, 'control_point_id');
      if (controlPointId.isNotEmpty) {
        completedControlPoints.add(controlPointId);
      }
      if (_readBool(row, 'has_novelty')) {
        noveltiesCount++;
      }
    }

    return _RoundPointCounters(
      completedPoints: completedControlPoints.length,
      noveltiesCount: noveltiesCount,
    );
  }

  Future<dynamic> _runSupabaseRoundFinishOperation({
    required String table,
    required String action,
    required String fallbackMessage,
    required dynamic Function() operation,
  }) async {
    try {
      return await operation();
    } on PostgrestException catch (error, stackTrace) {
      _logSupabaseFailure(
        table: table,
        action: action,
        error: error,
        stackTrace: stackTrace,
      );
      throw SupabaseRoundFinishException(
        _messageForRoundFinishOperationError(error, fallbackMessage),
        cause: error,
      );
    } catch (error, stackTrace) {
      _logSupabaseFailure(
        table: table,
        action: action,
        error: error,
        stackTrace: stackTrace,
      );

      if (_looksLikeNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }

      throw SupabaseRoundFinishException(fallbackMessage, cause: error);
    }
  }

  String _messageForRoundFinishOperationError(
    PostgrestException error,
    String fallbackMessage,
  ) {
    final String code = (error.code ?? '').trim();
    final String text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();

    if (code == '42501' ||
        text.contains('row-level security') ||
        text.contains('rls') ||
        text.contains('permission denied') ||
        text.contains('not authorized')) {
      return 'Error de permisos en Supabase al finalizar ronda. Revisar RLS.';
    }

    if (code == 'PGRST116' ||
        text.contains('0 rows') ||
        text.contains('no rows') ||
        text.contains('json object requested')) {
      if (fallbackMessage.contains('finalizar')) {
        return fallbackMessage;
      }
      return 'No se encontró la ronda en Supabase.';
    }

    return fallbackMessage;
  }

  void _logRoundFinishAttempt({
    required String authUid,
    required String profileId,
    required String profileEmail,
    required String installationId,
    required String roundId,
    required String roundLocalId,
    required String workShiftId,
    required int totalPoints,
    required int completedPoints,
    required int noveltyCount,
    required String currentStatus,
  }) {
    debugPrint('RondaQR finalizar ronda | auth.uid: $authUid');
    debugPrint('RondaQR finalizar ronda | profile.id: $profileId');
    debugPrint('RondaQR finalizar ronda | profile.email: $profileEmail');
    debugPrint('RondaQR finalizar ronda | installation_id: $installationId');
    debugPrint('RondaQR finalizar ronda | round_id: $roundId');
    debugPrint(
      'RondaQR finalizar ronda | active round local_id: $roundLocalId',
    );
    debugPrint('RondaQR finalizar ronda | work_shift_id: $workShiftId');
    debugPrint('RondaQR finalizar ronda | total_points: $totalPoints');
    debugPrint('RondaQR finalizar ronda | completed_points: $completedPoints');
    debugPrint('RondaQR finalizar ronda | novelties_count: $noveltyCount');
    debugPrint('RondaQR finalizar ronda | status actual: $currentStatus');
  }

  Future<List<RoundHistoryItem>> loadHistory(AppUser user) async {
    if (!SupabaseService.instance.onlineMode) {
      return RoundHistoryStore.instance.rounds;
    }

    return loadCompletedRoundsForHistory(user, caller: 'SupabaseRoundService');
  }

  Future<List<RoundHistoryItem>> loadCompletedRoundsForHistory(
    AppUser user, {
    required String caller,
  }) async {
    if (!SupabaseService.instance.onlineMode) {
      return RoundHistoryStore.instance.rounds;
    }

    final SupabaseClient client = SupabaseService.instance.requireClient();
    final String authUid = client.auth.currentUser?.id.trim() ?? '';
    String queryDescription = 'profiles actual por auth.uid';

    _logHistoryLoadStart(
      caller: caller,
      user: user,
      authUid: authUid,
      queryDescription: queryDescription,
    );

    try {
      if (authUid.isEmpty) {
        throw const SupabaseHistoryLoadException(
          'No se encontró el perfil del usuario.',
          technicalDetail: 'auth.uid vacío al cargar historial.',
        );
      }

      final Map<String, dynamic> currentProfile = await _loadCurrentProfile(
        client: client,
        authUid: authUid,
      );
      final String profileRole = _readText(currentProfile, 'role');
      final String profileInstallationId = _readText(
        currentProfile,
        'installation_id',
      ).ifEmpty(user.installationId);
      final bool guardRole = _isHistoryGuardRole(profileRole, user.role);

      queryDescription = guardRole
          ? 'rounds completed por guard_id'
          : 'rounds completed por installation_id';

      final List<Map<String, dynamic>> roundRows =
          await _loadCompletedRoundRows(
            client: client,
            authUid: authUid,
            installationId: profileInstallationId,
            guardRole: guardRole,
          );

      debugPrint(
        'RondaQR historial Supabase | pantalla: $caller | '
        'rondas completed recibidas: ${roundRows.length}',
      );

      if (roundRows.isEmpty) {
        RoundHistoryStore.instance.loadRounds(const []);
        return const [];
      }

      final Set<String> guardIds = roundRows
          .map((row) => _readText(row, 'guard_id'))
          .where((id) => id.isNotEmpty)
          .toSet();
      final Set<String> roundIds = roundRows
          .map((row) => _readText(row, 'id'))
          .where((id) => id.isNotEmpty)
          .toSet();

      final Map<String, Map<String, dynamic>> profilesById =
          await _loadHistoryGuardProfilesOptional(
            client: client,
            guardIds: guardIds,
            caller: caller,
          );
      profilesById.putIfAbsent(authUid, () => currentProfile);

      final Map<String, List<RoundHistoryPoint>> pointsByRoundId =
          await _loadHistoryRoundPointsOptional(
            client: client,
            roundIds: roundIds,
            caller: caller,
          );

      final List<RoundHistoryItem> rounds = roundRows
          .map((row) {
            return _historyItemFromRound(
              row,
              user,
              profilesById[_readText(row, 'guard_id')],
              pointsByRoundId[_readText(row, 'id')] ??
                  const <RoundHistoryPoint>[],
            );
          })
          .whereType<RoundHistoryItem>()
          .toList(growable: false);

      RoundHistoryStore.instance.loadRounds(rounds);
      return rounds;
    } on SupabaseHistoryLoadException catch (error, stackTrace) {
      _logHistoryFailure(
        caller: caller,
        user: user,
        authUid: authUid,
        queryDescription: queryDescription,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } on PostgrestException catch (error, stackTrace) {
      _logHistoryFailure(
        caller: caller,
        user: user,
        authUid: authUid,
        queryDescription: queryDescription,
        error: error,
        stackTrace: stackTrace,
      );
      if (_looksLikeNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw SupabaseHistoryLoadException(
        'No se pudo cargar el historial desde Supabase.',
        technicalDetail: _technicalDetailForError(error),
        cause: error,
      );
    } catch (error, stackTrace) {
      _logHistoryFailure(
        caller: caller,
        user: user,
        authUid: authUid,
        queryDescription: queryDescription,
        error: error,
        stackTrace: stackTrace,
      );
      if (_looksLikeNetworkError(error)) {
        SupabaseService.instance.throwOnlineRequired();
      }
      throw SupabaseHistoryLoadException(
        'No se pudo cargar el historial desde Supabase.',
        technicalDetail: _technicalDetailForError(error),
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _loadCurrentProfile({
    required SupabaseClient client,
    required String authUid,
  }) async {
    final dynamic response = await client
        .from('profiles')
        .select('id,full_name,email,role,position,installation_id')
        .eq('id', authUid)
        .limit(1);

    final List<Map<String, dynamic>> rows = _rows(response);
    if (rows.isEmpty) {
      throw SupabaseHistoryLoadException(
        'No se encontró el perfil del usuario.',
        technicalDetail: 'profiles no devolvió filas para auth.uid=$authUid',
      );
    }

    return rows.first;
  }

  Future<List<Map<String, dynamic>>> _loadCompletedRoundRows({
    required SupabaseClient client,
    required String authUid,
    required String installationId,
    required bool guardRole,
  }) async {
    final dynamic response;

    if (guardRole) {
      response = await client
          .from('rounds')
          .select(
            'id,local_id,guard_id,installation_id,work_shift_id,started_at,finished_at,status,total_points,completed_points,novelties_count,updated_at',
          )
          .eq('guard_id', authUid)
          .eq('status', 'completed')
          .not('finished_at', 'is', null)
          .order('finished_at', ascending: false)
          .limit(200);
    } else {
      if (installationId.isEmpty) {
        throw const SupabaseHistoryLoadException(
          'No se encontró el perfil del usuario.',
          technicalDetail: 'installation_id vacío para usuario no guardia.',
        );
      }

      response = await client
          .from('rounds')
          .select(
            'id,local_id,guard_id,installation_id,work_shift_id,started_at,finished_at,status,total_points,completed_points,novelties_count,updated_at',
          )
          .eq('installation_id', installationId)
          .eq('status', 'completed')
          .not('finished_at', 'is', null)
          .order('finished_at', ascending: false)
          .limit(200);
    }

    return _rows(response)
        .where((row) {
          return _readText(row, 'status') == 'completed' &&
              _readText(row, 'finished_at').isNotEmpty;
        })
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _loadHistoryGuardProfilesOptional({
    required SupabaseClient client,
    required Set<String> guardIds,
    required String caller,
  }) async {
    final List<String> ids = guardIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }

    try {
      final dynamic response = await client
          .from('profiles')
          .select('id,full_name,email,role,position,installation_id')
          .inFilter('id', ids);

      return {
        for (final Map<String, dynamic> row in _rows(response))
          _readText(row, 'id'): row,
      };
    } catch (error, stackTrace) {
      _logOptionalHistoryFailure(
        caller: caller,
        queryDescription: 'profiles por guard_ids',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, Map<String, dynamic>>{};
    }
  }

  Future<Map<String, List<RoundHistoryPoint>>> _loadHistoryRoundPointsOptional({
    required SupabaseClient client,
    required Set<String> roundIds,
    required String caller,
  }) async {
    final List<String> ids = roundIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) {
      return const <String, List<RoundHistoryPoint>>{};
    }

    try {
      final dynamic response = await client
          .from('round_points')
          .select('round_id,point_name,has_novelty,observation,scanned_at')
          .inFilter('round_id', ids)
          .order('scanned_at', ascending: true);

      final Map<String, List<RoundHistoryPoint>> pointsByRound = {};
      for (final Map<String, dynamic> row in _rows(response)) {
        final String roundId = _readText(row, 'round_id');
        if (roundId.isEmpty) {
          continue;
        }
        pointsByRound
            .putIfAbsent(roundId, () => <RoundHistoryPoint>[])
            .add(
              RoundHistoryPoint(
                name: _readText(row, 'point_name').ifEmpty('Punto de control'),
                completed: true,
                hasNovelty: _readBool(row, 'has_novelty'),
                observation: _readText(row, 'observation'),
                completedAt: _readDate(row, 'scanned_at'),
              ),
            );
      }

      return pointsByRound;
    } catch (error, stackTrace) {
      _logOptionalHistoryFailure(
        caller: caller,
        queryDescription: 'round_points por round_ids',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, List<RoundHistoryPoint>>{};
    }
  }

  void _logHistoryLoadStart({
    required String caller,
    required AppUser user,
    required String authUid,
    required String queryDescription,
  }) {
    debugPrint('RondaQR historial Supabase | pantalla: $caller');
    debugPrint('RondaQR historial Supabase | auth.uid: $authUid');
    debugPrint('RondaQR historial Supabase | profile.id: ${user.id}');
    debugPrint('RondaQR historial Supabase | profile.email: ${user.email}');
    debugPrint('RondaQR historial Supabase | profile.role: ${user.role.name}');
    debugPrint(
      'RondaQR historial Supabase | profile.installation_id: ${user.installationId}',
    );
    debugPrint('RondaQR historial Supabase | query: $queryDescription');
  }

  void _logHistoryFailure({
    required String caller,
    required AppUser user,
    required String authUid,
    required String queryDescription,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint('RondaQR historial Supabase | pantalla: $caller');
    debugPrint('RondaQR historial Supabase | auth.uid: $authUid');
    debugPrint('RondaQR historial Supabase | profile.id: ${user.id}');
    debugPrint('RondaQR historial Supabase | profile.email: ${user.email}');
    debugPrint('RondaQR historial Supabase | profile.role: ${user.role.name}');
    debugPrint(
      'RondaQR historial Supabase | profile.installation_id: ${user.installationId}',
    );
    debugPrint('RondaQR historial Supabase | query usada: $queryDescription');
    debugPrint(
      'RondaQR historial Supabase | detalle: ${_technicalDetailForError(error)}',
    );

    if (error is PostgrestException) {
      debugPrint('RondaQR historial Supabase | code: ${error.code ?? ''}');
      debugPrint('RondaQR historial Supabase | message: ${error.message}');
      debugPrint(
        'RondaQR historial Supabase | details: ${error.details ?? ''}',
      );
      debugPrint('RondaQR historial Supabase | hint: ${error.hint ?? ''}');
    } else if (error is SupabaseHistoryLoadException) {
      debugPrint(
        'RondaQR historial Supabase | technicalDetail: ${error.technicalDetail}',
      );
    }

    debugPrintStack(stackTrace: stackTrace);
  }

  void _logOptionalHistoryFailure({
    required String caller,
    required String queryDescription,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint(
      'RondaQR historial Supabase | pantalla: $caller | '
      'dato opcional falló: $queryDescription',
    );
    debugPrint(
      'RondaQR historial Supabase | detalle opcional: ${_technicalDetailForError(error)}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  RoundHistoryItem? _historyItemFromRound(
    Map<String, dynamic> row,
    AppUser currentUser,
    Map<String, dynamic>? guardProfile,
    List<RoundHistoryPoint> points,
  ) {
    final String roundId = _readText(row, 'id');
    if (roundId.isEmpty) {
      return null;
    }

    final String guardId = _readText(row, 'guard_id');
    final AppUser? guard = UserAccountStore.instance.accountById(guardId)?.user;
    final String workShiftId = _readText(row, 'work_shift_id');
    final WorkShiftRecord? shift = _findShift(workShiftId);
    final DateTime startedAt =
        _readDate(row, 'started_at') ??
        _readDate(row, 'finished_at') ??
        DateTime.now();
    final DateTime finishedAt =
        _readDate(row, 'finished_at') ??
        _readDate(row, 'updated_at') ??
        startedAt;
    final int totalPoints = _readInt(
      row,
      'total_points',
      fallback: points.isEmpty ? 0 : points.length,
    );
    final int completedPoints = _readInt(
      row,
      'completed_points',
      fallback: points.where((point) => point.completed).length,
    );
    final int noveltyCount = _readInt(
      row,
      'novelties_count',
      fallback: points.where((point) => point.hasNovelty).length,
    );

    final String profileName = _readText(guardProfile ?? const {}, 'full_name');
    final String profileEmail = _readText(guardProfile ?? const {}, 'email');
    final String profileRole = _readText(guardProfile ?? const {}, 'role');

    return RoundHistoryItem(
      id: roundId,
      guardId: guardId,
      guardName: profileName.ifEmpty(
        guard?.displayName ?? profileEmail.ifEmpty('Guardia'),
      ),
      role: guard?.role.label ?? _historyRoleLabel(profileRole),
      installation:
          guard?.installationName ??
          currentUser.installationName.ifEmpty('Instalación'),
      shiftRecordId: workShiftId,
      shiftId: shift?.shiftId ?? '',
      shiftName: shift?.shiftName ?? _readText(row, 'shift_name'),
      shiftScheduledStart: shift?.scheduledStart ?? '',
      shiftScheduledEnd: shift?.scheduledEnd ?? '',
      shiftStartedAt: shift?.actualStartedAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      totalPoints: totalPoints,
      completedPoints: completedPoints,
      noveltyCount: noveltyCount,
      points: points,
      syncStatus: SyncStatus.synced,
    );
  }

  String _historyRoleLabel(String role) {
    final String normalized = role.trim().toLowerCase();
    if (normalized == 'admin' || normalized == 'administrator') {
      return AppRole.administrator.label;
    }
    if (normalized == 'supervisor') {
      return AppRole.supervisor.label;
    }
    return AppRole.guard.label;
  }

  WorkShiftRecord? _findShift(String shiftId) {
    if (shiftId.isEmpty) {
      return null;
    }

    for (final WorkShiftRecord shift in [
      ...WorkShiftStore.instance.activeShifts,
      ...WorkShiftStore.instance.history,
    ]) {
      if (shift.id == shiftId) {
        return shift;
      }
    }

    return null;
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

  bool _isHistoryGuardRole(String role, AppRole fallbackRole) {
    final String normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallbackRole == AppRole.guard;
    }
    return normalized == 'guard' || normalized == 'guardia';
  }

  String _technicalDetailForError(Object error) {
    if (error is SupabaseHistoryLoadException) {
      return error.technicalDetail.ifEmpty(error.message);
    }
    if (error is PostgrestException) {
      final String code = error.code == null ? '' : 'code=${error.code}; ';
      final String details = error.details == null
          ? ''
          : 'details=${error.details}; ';
      final String hint = error.hint == null ? '' : 'hint=${error.hint}; ';
      return '${code}message=${error.message}; $details$hint'.trim();
    }
    return error.toString();
  }

  bool _readBool(Map<String, dynamic> row, String key) {
    final dynamic value = row[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }
}

extension _EmptyStringFallback on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
