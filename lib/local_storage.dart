import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';
import 'control_points.dart';
import 'round_history.dart';
import 'round_state.dart';
import 'services/sync_status.dart';
import 'user_configuration.dart';
import 'work_shifts.dart';

class LocalStorage {
  LocalStorage._internal();

  static final LocalStorage instance = LocalStorage._internal();

  static const String _historyKey = 'rondaqr_history_v1';
  static const String _activeRoundKey = 'rondaqr_active_round_v1';
  static const String _userConfigurationKey = 'rondaqr_user_configuration_v1';
  static const String _controlPointsKey = 'rondaqr_control_points_v1';
  static const String _sessionKey = 'rondaqr_session_v1';
  static const String _usersKey = 'rondaqr_users_v1';
  static const String _shiftDefinitionsKey = 'rondaqr_shift_definitions_v1';
  static const String _activeShiftKey = 'rondaqr_active_shift_v1';
  static const String _shiftHistoryKey = 'rondaqr_shift_history_v1';

  Future<void> saveSession(AppSession session) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setString(
      _sessionKey,
      jsonEncode(session.toJson()),
    );

    if (!saved) {
      throw Exception('No fue posible guardar la sesión.');
    }
  }

  Future<AppSession?> loadSession() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_sessionKey);

      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);

      if (decoded is! Map) {
        return null;
      }

      return AppSession.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('Error cargando sesión: $error');
      return null;
    }
  }

  Future<void> clearSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  Future<void> saveUsers(List<LocalUserAccount> accounts) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setString(
      _usersKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );

    if (!saved) {
      throw Exception('No fue posible guardar los usuarios.');
    }
  }

  Future<List<LocalUserAccount>?> loadUsers() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_usersKey);

      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);
      if (decoded is! List) {
        return null;
      }

      final List<LocalUserAccount> accounts = [];
      final Set<String> usedIds = {};
      final Set<String> usedEmails = {};

      for (final dynamic item in decoded) {
        if (item is! Map) {
          continue;
        }

        final LocalUserAccount? account = LocalUserAccount.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (account == null) {
          continue;
        }

        final String email = account.user.email.toLowerCase();
        if (!usedIds.add(account.user.id) || !usedEmails.add(email)) {
          continue;
        }
        accounts.add(account);
      }

      return accounts.isEmpty ? null : accounts;
    } catch (error) {
      debugPrint('Error cargando usuarios: $error');
      return null;
    }
  }

  Future<void> saveShiftDefinitions(List<ShiftDefinition> shifts) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setString(
      _shiftDefinitionsKey,
      jsonEncode(shifts.map((shift) => shift.toJson()).toList()),
    );

    if (!saved) {
      throw Exception('No fue posible guardar la configuración de turnos.');
    }
  }

  Future<List<ShiftDefinition>?> loadShiftDefinitions() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_shiftDefinitionsKey);
      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);
      if (decoded is! List) {
        return null;
      }

      final List<ShiftDefinition> shifts = [];
      final Set<String> usedIds = {};
      for (final dynamic item in decoded) {
        if (item is! Map) {
          continue;
        }
        final ShiftDefinition? shift = ShiftDefinition.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (shift != null && usedIds.add(shift.id)) {
          shifts.add(shift);
        }
      }

      return shifts.isEmpty ? null : shifts;
    } catch (error) {
      debugPrint('Error cargando configuración de turnos: $error');
      return null;
    }
  }

  Future<void> saveActiveShift(WorkShiftRecord? shift) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    if (shift == null) {
      await preferences.remove(_activeShiftKey);
      return;
    }

    final bool saved = await preferences.setString(
      _activeShiftKey,
      jsonEncode(shift.toJson()),
    );
    if (!saved) {
      throw Exception('No fue posible guardar el turno activo.');
    }
  }

  Future<WorkShiftRecord?> loadActiveShift() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_activeShiftKey);
      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);
      return decoded is Map
          ? WorkShiftRecord.fromJson(Map<String, dynamic>.from(decoded))
          : null;
    } catch (error) {
      debugPrint('Error cargando turno activo: $error');
      return null;
    }
  }

  Future<void> saveShiftHistory(List<WorkShiftRecord> shifts) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setString(
      _shiftHistoryKey,
      jsonEncode(shifts.map((shift) => shift.toJson()).toList()),
    );
    if (!saved) {
      throw Exception('No fue posible guardar el historial de turnos.');
    }
  }

  Future<List<WorkShiftRecord>> loadShiftHistory() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_shiftHistoryKey);
      if (savedText == null || savedText.isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(savedText);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => WorkShiftRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .whereType<WorkShiftRecord>()
          .toList();
    } catch (error) {
      debugPrint('Error cargando historial de turnos: $error');
      return [];
    }
  }

  Future<void> saveControlPoints(List<ControlPointDefinition> points) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> encodedPoints = points.map((point) {
      return {
        'id': point.id,
        'name': point.name,
        'qrIdentifier': point.qrIdentifier,
        'description': point.description,
        'order': point.order,
        'isActive': point.isActive,
        'iconKey': point.iconKey,
      };
    }).toList();

    final bool saved = await preferences.setString(
      _controlPointsKey,
      jsonEncode(encodedPoints),
    );

    if (!saved) {
      throw Exception('No fue posible guardar los puntos de control.');
    }
  }

  Future<List<ControlPointDefinition>?> loadControlPoints() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_controlPointsKey);

      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);

      if (decoded is! List) {
        return null;
      }

      final List<ControlPointDefinition> points = [];
      final Set<String> usedQrIdentifiers = {};

      for (int index = 0; index < decoded.length; index++) {
        final dynamic item = decoded[index];

        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> pointMap = Map<String, dynamic>.from(item);
        final String name = pointMap['name'] is String
            ? (pointMap['name'] as String).trim()
            : '';
        final String qrIdentifier =
            ControlPointDefinition.normalizeQrIdentifier(
              pointMap['qrIdentifier'] is String
                  ? pointMap['qrIdentifier'] as String
                  : '',
            );

        if (name.isEmpty ||
            qrIdentifier.isEmpty ||
            usedQrIdentifiers.contains(qrIdentifier)) {
          continue;
        }

        usedQrIdentifiers.add(qrIdentifier);

        final String savedId = pointMap['id'] is String
            ? (pointMap['id'] as String).trim()
            : '';
        final String description = pointMap['description'] is String
            ? (pointMap['description'] as String).trim()
            : '';
        final String? iconKey = pointMap['iconKey'] is String
            ? pointMap['iconKey'] as String
            : null;

        points.add(
          ControlPointDefinition(
            id: savedId.isEmpty ? 'stored_${index}_$qrIdentifier' : savedId,
            name: name,
            qrIdentifier: qrIdentifier,
            description: description,
            order: (pointMap['order'] as num?)?.toInt() ?? index + 1,
            isActive: pointMap['isActive'] as bool? ?? true,
            iconKey: ControlPointIcons.values.containsKey(iconKey)
                ? iconKey
                : null,
          ),
        );
      }

      if (decoded.isNotEmpty && points.isEmpty) {
        return null;
      }

      return points;
    } catch (error) {
      debugPrint('Error cargando puntos de control: $error');
      return null;
    }
  }

  Future<void> saveUserConfiguration(UserConfiguration configuration) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final Map<String, String> encodedConfiguration = {
      'guardName': configuration.guardName,
      'identifier': configuration.identifier,
      'installationName': configuration.installationName,
      'company': configuration.company,
      'shift': configuration.shift,
      'role': configuration.role,
    };

    final bool saved = await preferences.setString(
      _userConfigurationKey,
      jsonEncode(encodedConfiguration),
    );

    if (!saved) {
      throw Exception('No fue posible guardar la configuración.');
    }
  }

  Future<UserConfiguration?> loadUserConfiguration() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? savedText = preferences.getString(_userConfigurationKey);

      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);

      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> configurationMap = Map<String, dynamic>.from(
        decoded,
      );

      String readText(String key) {
        final dynamic value = configurationMap[key];
        return value is String ? value.trim() : '';
      }

      return UserConfiguration(
        guardName: readText('guardName'),
        identifier: readText('identifier'),
        installationName: readText('installationName'),
        company: readText('company'),
        shift: readText('shift'),
        role: readText('role'),
      );
    } catch (error) {
      debugPrint('Error cargando configuración: $error');
      return null;
    }
  }

  Future<void> saveHistory(List<RoundHistoryItem> rounds) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> encodedRounds = rounds.map((round) {
      return {
        'id': round.id,
        'guardId': round.guardId,
        'guardName': round.guardName,
        'role': round.role,
        'installation': round.installation,
        'shiftRecordId': round.shiftRecordId,
        'shiftId': round.shiftId,
        'shiftName': round.shiftName,
        'shiftScheduledStart': round.shiftScheduledStart,
        'shiftScheduledEnd': round.shiftScheduledEnd,
        'shiftStartedAt': round.shiftStartedAt?.toIso8601String(),
        'startedAt': round.startedAt.toIso8601String(),
        'finishedAt': round.finishedAt.toIso8601String(),
        'totalPoints': round.totalPoints,
        'completedPoints': round.completedPoints,
        'noveltyCount': round.noveltyCount,
        'syncStatus': round.syncStatus.storageValue,
        'points': round.points.map((point) {
          return {
            'name': point.name,
            'completed': point.completed,
            'hasNovelty': point.hasNovelty,
            'observation': point.observation,
            'noveltyCategory': point.noveltyCategory,
            'noveltySeverity': point.noveltySeverity,
            'noveltyPhotoPath': point.noveltyPhotoPath,
            'completedAt': point.completedAt?.toIso8601String(),
          };
        }).toList(),
      };
    }).toList();

    final bool saved = await preferences.setString(
      _historyKey,
      jsonEncode(encodedRounds),
    );

    if (!saved) {
      throw Exception('No fue posible guardar el historial.');
    }
  }

  Future<List<RoundHistoryItem>> loadHistory() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? savedText = preferences.getString(_historyKey);

    if (savedText == null || savedText.isEmpty) {
      return [];
    }

    try {
      final dynamic decoded = jsonDecode(savedText);

      if (decoded is! List) {
        return [];
      }

      return decoded.map<RoundHistoryItem>((dynamic item) {
        final Map<String, dynamic> roundMap = Map<String, dynamic>.from(
          item as Map,
        );

        final List<dynamic> pointsData =
            roundMap['points'] as List<dynamic>? ?? [];

        final List<RoundHistoryPoint> points = pointsData
            .map<RoundHistoryPoint>((dynamic pointItem) {
              final Map<String, dynamic> pointMap = Map<String, dynamic>.from(
                pointItem as Map,
              );

              final String? completedAtText =
                  pointMap['completedAt'] as String?;

              return RoundHistoryPoint(
                name: pointMap['name'] as String? ?? 'Punto sin nombre',
                completed: pointMap['completed'] as bool? ?? false,
                hasNovelty: pointMap['hasNovelty'] as bool? ?? false,
                observation: pointMap['observation'] as String? ?? '',
                noveltyCategory: pointMap['noveltyCategory'] as String?,
                noveltySeverity: pointMap['noveltySeverity'] as String?,
                noveltyPhotoPath: pointMap['noveltyPhotoPath'] as String?,
                completedAt: completedAtText == null
                    ? null
                    : DateTime.tryParse(completedAtText),
              );
            })
            .toList();

        final String? startedAtText = roundMap['startedAt'] as String?;

        final String? finishedAtText = roundMap['finishedAt'] as String?;
        final String? shiftStartedAtText =
            roundMap['shiftStartedAt'] as String?;

        final DateTime now = DateTime.now();

        return RoundHistoryItem(
          id:
              roundMap['id'] as String? ??
              now.microsecondsSinceEpoch.toString(),
          guardId: roundMap['guardId'] as String? ?? '',
          guardName: roundMap['guardName'] as String? ?? 'Guardia',
          role: roundMap['role'] as String? ?? '',
          installation: roundMap['installation'] as String? ?? 'Instalación',
          shiftRecordId: roundMap['shiftRecordId'] as String? ?? '',
          shiftId: roundMap['shiftId'] as String? ?? '',
          shiftName: roundMap['shiftName'] as String? ?? '',
          shiftScheduledStart: roundMap['shiftScheduledStart'] as String? ?? '',
          shiftScheduledEnd: roundMap['shiftScheduledEnd'] as String? ?? '',
          shiftStartedAt: DateTime.tryParse(shiftStartedAtText ?? ''),
          startedAt: DateTime.tryParse(startedAtText ?? '') ?? now,
          finishedAt: DateTime.tryParse(finishedAtText ?? '') ?? now,
          totalPoints: (roundMap['totalPoints'] as num?)?.toInt() ?? 0,
          completedPoints: (roundMap['completedPoints'] as num?)?.toInt() ?? 0,
          noveltyCount: (roundMap['noveltyCount'] as num?)?.toInt() ?? 0,
          points: points,
          syncStatus: SyncStatusX.fromStorage(
            roundMap['syncStatus'] as String? ?? '',
          ),
        );
      }).toList();
    } catch (error) {
      debugPrint('Error cargando historial: $error');

      return [];
    }
  }

  Future<void> saveActiveRound(ActiveRoundSnapshot activeRound) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final Map<String, dynamic> encodedRound = {
      'startedAt': activeRound.startedAt.toIso8601String(),
      'finishedAt': activeRound.finishedAt?.toIso8601String(),
      'operationalContext': activeRound.operationalContext == null
          ? null
          : {
              'userId': activeRound.operationalContext!.userId,
              'guardName': activeRound.operationalContext!.guardName,
              'role': activeRound.operationalContext!.role,
              'installation': activeRound.operationalContext!.installation,
              'shiftRecordId': activeRound.operationalContext!.shiftRecordId,
              'shiftId': activeRound.operationalContext!.shiftId,
              'shiftName': activeRound.operationalContext!.shiftName,
              'shiftScheduledStart':
                  activeRound.operationalContext!.shiftScheduledStart,
              'shiftScheduledEnd':
                  activeRound.operationalContext!.shiftScheduledEnd,
              'shiftStartedAt': activeRound.operationalContext!.shiftStartedAt
                  .toIso8601String(),
            },
      'points': activeRound.points.map((point) {
        return {
          'id': point.id,
          'name': point.name,
          'qrIdentifier': point.qrIdentifier,
          'description': point.description,
          'order': point.order,
          'iconKey': point.iconKey,
          'completed': point.completed,
          'hasNovelty': point.hasNovelty,
          'observation': point.observation,
          'noveltyCategory': point.noveltyCategory,
          'noveltySeverity': point.noveltySeverity,
          'noveltyPhotoPath': point.noveltyPhotoPath,
          'completedAt': point.completedAt?.toIso8601String(),
        };
      }).toList(),
    };

    final bool saved = await preferences.setString(
      _activeRoundKey,
      jsonEncode(encodedRound),
    );

    if (!saved) {
      throw Exception('No fue posible guardar la ronda activa.');
    }
  }

  Future<ActiveRoundSnapshot?> loadActiveRound() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final String? savedText = preferences.getString(_activeRoundKey);

      if (savedText == null || savedText.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(savedText);

      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> roundMap = Map<String, dynamic>.from(decoded);

      final DateTime? startedAt = DateTime.tryParse(
        roundMap['startedAt'] as String? ?? '',
      );
      final DateTime? finishedAt = DateTime.tryParse(
        roundMap['finishedAt'] as String? ?? '',
      );

      if (startedAt == null) {
        return null;
      }

      final List<dynamic> pointsData =
          roundMap['points'] as List<dynamic>? ?? [];

      final List<ActiveRoundPointSnapshot> points = pointsData
          .map<ActiveRoundPointSnapshot>((dynamic pointItem) {
            final Map<String, dynamic> pointMap = Map<String, dynamic>.from(
              pointItem as Map,
            );

            final String? completedAtText = pointMap['completedAt'] as String?;

            return ActiveRoundPointSnapshot(
              id: pointMap['id'] as String?,
              name: pointMap['name'] as String? ?? 'Punto sin nombre',
              qrIdentifier: pointMap['qrIdentifier'] as String?,
              description: pointMap['description'] as String?,
              order: (pointMap['order'] as num?)?.toInt(),
              iconKey: pointMap['iconKey'] as String?,
              completed: pointMap['completed'] as bool? ?? false,
              hasNovelty: pointMap['hasNovelty'] as bool? ?? false,
              observation: pointMap['observation'] as String? ?? '',
              noveltyCategory: pointMap['noveltyCategory'] as String?,
              noveltySeverity: pointMap['noveltySeverity'] as String?,
              noveltyPhotoPath: pointMap['noveltyPhotoPath'] as String?,
              completedAt: completedAtText == null
                  ? null
                  : DateTime.tryParse(completedAtText),
            );
          })
          .toList();

      RoundOperationalContext? operationalContext;
      final dynamic contextData = roundMap['operationalContext'];
      if (contextData is Map) {
        final Map<String, dynamic> contextMap = Map<String, dynamic>.from(
          contextData,
        );

        String readText(String key) {
          final dynamic value = contextMap[key];
          return value is String ? value.trim() : '';
        }

        final DateTime? shiftStartedAt = DateTime.tryParse(
          readText('shiftStartedAt'),
        );
        final String userId = readText('userId');
        final String shiftId = readText('shiftId');

        if (userId.isNotEmpty && shiftId.isNotEmpty && shiftStartedAt != null) {
          operationalContext = RoundOperationalContext(
            userId: userId,
            guardName: readText('guardName'),
            role: readText('role'),
            installation: readText('installation'),
            shiftRecordId: readText('shiftRecordId'),
            shiftId: shiftId,
            shiftName: readText('shiftName'),
            shiftScheduledStart: readText('shiftScheduledStart'),
            shiftScheduledEnd: readText('shiftScheduledEnd'),
            shiftStartedAt: shiftStartedAt,
          );
        }
      }

      return ActiveRoundSnapshot(
        startedAt: startedAt,
        finishedAt: finishedAt,
        points: points,
        operationalContext: operationalContext,
      );
    } catch (error) {
      debugPrint('Error cargando ronda activa: $error');

      return null;
    }
  }

  Future<void> clearActiveRound() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final bool removed = await preferences.remove(_activeRoundKey);

    if (!removed) {
      throw Exception('No fue posible eliminar la ronda activa.');
    }
  }

  Future<void> clearHistory() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.remove(_historyKey);
  }
}
