import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/round_state.dart';
import 'package:rondaqr/services/supabase_round_service.dart';
import 'package:rondaqr/services/supabase_service.dart';
import 'package:rondaqr/session_store.dart';
import 'package:rondaqr/user_configuration.dart';
import 'package:rondaqr/work_shifts.dart';

class RoundSummaryScreen extends StatefulWidget {
  final String pointName;
  final String pointStatus;
  final String observation;

  const RoundSummaryScreen({
    super.key,
    required this.pointName,
    required this.pointStatus,
    required this.observation,
  });

  @override
  State<RoundSummaryScreen> createState() => _RoundSummaryScreenState();
}

class _RoundSummaryScreenState extends State<RoundSummaryScreen> {
  bool _finalizationDialogOpen = false;
  bool _savingRound = false;

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color naranja = Color(0xFFF59E0B);
  static const Color rojo = Color(0xFFD92D20);

  String formatearHora(DateTime? fecha) {
    if (fecha == null) {
      return '--:--';
    }

    final String hora = fecha.hour.toString().padLeft(2, '0');

    final String minuto = fecha.minute.toString().padLeft(2, '0');

    return '$hora:$minuto';
  }

  String formatearFecha(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');

    final String mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  void continuarEscaneando(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> finalizarRonda(
    BuildContext context,
    RoundState roundState,
  ) async {
    if (_finalizationDialogOpen || _savingRound) {
      return;
    }

    if (!roundState.allPointsCompleted) {
      final int faltantes = roundState.totalPoints - roundState.completedPoints;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aún faltan $faltantes puntos por completar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    _finalizationDialogOpen = true;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: verde, size: 30),
              SizedBox(width: 10),
              Expanded(child: Text('Finalizar ronda')),
            ],
          ),
          content: const Text(
            'Todos los puntos fueron completados. '
            '¿Deseas finalizar y guardar esta ronda?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrincipal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );

    _finalizationDialogOpen = false;

    if (confirmed != true || !context.mounted) {
      return;
    }

    setState(() {
      _savingRound = true;
    });

    try {
      await guardarRondaFinalizada(context, roundState);
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      setState(() {
        _savingRound = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SupabaseRoundFinishException
                ? error.message
                : error is StateError
                ? error.message.toString()
                : 'No fue posible guardar la ronda. Intenta nuevamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> guardarRondaFinalizada(
    BuildContext context,
    RoundState roundState,
  ) async {
    final DateTime fechaTermino = DateTime.now();
    final DateTime fechaInicio = roundState.roundStartedAt ?? fechaTermino;

    final int novedades = roundState.points
        .where((point) => point.completed && point.hasNovelty)
        .length;

    final List<RoundHistoryPoint> puntosGuardados = roundState.points.map((
      point,
    ) {
      return RoundHistoryPoint(
        name: point.name,
        completed: point.completed,
        hasNovelty: point.hasNovelty,
        observation: point.observation,
        noveltyCategory: point.noveltyCategory,
        noveltySeverity: point.noveltySeverity,
        noveltyPhotoPath: point.noveltyPhotoPath,
        completedAt: point.completedAt,
      );
    }).toList();
    final UserConfiguration configuration =
        UserConfigurationStore.instance.configuration;
    final AppUser? user = SessionStore.instance.currentUser;
    final RoundOperationalContext? roundContext = roundState.operationalContext;
    final WorkShiftRecord? activeShift = user == null
        ? null
        : WorkShiftStore.instance.activeForUser(user.id);

    final RoundHistoryItem nuevaRonda = RoundHistoryItem(
      id: fechaInicio.microsecondsSinceEpoch.toString(),
      guardId: roundContext?.userId ?? user?.id ?? '',
      guardName:
          roundContext?.guardName ?? user?.displayName ?? 'Guardia sin nombre',
      role: roundContext?.role ?? user?.role.label ?? 'Guardia',
      installation:
          roundContext?.installation ??
          user?.installationName ??
          configuration.installationNameDisplay,
      shiftRecordId: roundContext?.shiftRecordId ?? activeShift?.id ?? '',
      shiftId: roundContext?.shiftId ?? activeShift?.shiftId ?? '',
      shiftName: roundContext?.shiftName ?? activeShift?.shiftName ?? '',
      shiftScheduledStart:
          roundContext?.shiftScheduledStart ??
          activeShift?.scheduledStart ??
          '',
      shiftScheduledEnd:
          roundContext?.shiftScheduledEnd ?? activeShift?.scheduledEnd ?? '',
      shiftStartedAt:
          roundContext?.shiftStartedAt ?? activeShift?.actualStartedAt,
      startedAt: fechaInicio,
      finishedAt: fechaTermino,
      totalPoints: roundState.totalPoints,
      completedPoints: roundState.completedPoints,
      noveltyCount: novedades,
      points: puntosGuardados,
    );

    if (SupabaseService.instance.onlineMode) {
      if (user == null) {
        throw StateError(
          'No existe una sesión activa para finalizar la ronda.',
        );
      }

      await SupabaseRoundService.instance.finishRound(
        roundState: roundState,
        user: user,
        finishedAt: fechaTermino,
      );
      await _runOptionalPostSupabaseStep(
        'marcar ronda finalizada localmente',
        roundState.finishRound,
      );
      await _refreshSupabaseHistoryOpcional(user);
      await _runOptionalPostSupabaseStep(
        'limpiar ronda activa local',
        roundState.resetRound,
      );
    } else {
      await roundState.finishRound();
      await RoundHistoryStore.instance.addRound(nuevaRonda);
      if (nuevaRonda.guardId.isNotEmpty &&
          nuevaRonda.shiftRecordId.isNotEmpty) {
        await WorkShiftStore.instance.attachRoundToActiveShift(
          userId: nuevaRonda.guardId,
          roundId: nuevaRonda.id,
          noveltyCount: nuevaRonda.noveltyCount,
        );
      }
      await roundState.resetRound();
    }

    if (!context.mounted) {
      return;
    }

    mostrarRondaFinalizada(context, roundState);
  }

  Future<void> _refreshSupabaseHistoryOpcional(AppUser user) async {
    try {
      await SupabaseRoundService.instance.loadHistory(user);
      debugPrint('RondaQR finalizar ronda | historial Supabase refrescado: ok');
    } catch (error, stackTrace) {
      debugPrint('Historial local opcional falló: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _runOptionalPostSupabaseStep(
    String description,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
      debugPrint('RondaQR finalizar ronda | $description: ok');
    } catch (error, stackTrace) {
      debugPrint(
        'RondaQR finalizar ronda | $description falló (no crítico): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void mostrarRondaFinalizada(BuildContext context, RoundState roundState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFE8F8F0),
                child: Icon(Icons.verified_rounded, color: verde, size: 40),
              ),
              SizedBox(height: 14),
              Text('Ronda completada', textAlign: TextAlign.center),
            ],
          ),
          content: const Text(
            'Ronda finalizada correctamente.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrincipal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Volver al inicio'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoundState roundState = RoundState.instance;
    final UserConfigurationStore configurationStore =
        UserConfigurationStore.instance;
    final SessionStore sessionStore = SessionStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        roundState,
        configurationStore,
        sessionStore,
      ]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final RoundOperationalContext? roundContext =
            roundState.operationalContext;
        final AppUser? user = sessionStore.currentUser;
        final String installation =
            roundContext?.installation ??
            user?.installationName ??
            configuration.installationNameDisplay;
        final String guardName =
            roundContext?.guardName ?? user?.displayName ?? 'Guardia';
        final String shiftName = roundContext?.shiftName ?? 'Turno';
        final int completados = roundState.completedPoints;

        final int total = roundState.totalPoints;

        final int pendientes = total - completados;

        final int porcentaje = (roundState.progress * 100).round();

        final int novedades = roundState.points
            .where((point) => point.completed && point.hasNovelty)
            .length;

        return Scaffold(
          backgroundColor: fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [azulOscuro, azulMedio]),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Resumen de ronda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F6FFF), azulMedio],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: azulPrincipal.withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 29,
                                    backgroundColor: Color(0x26FFFFFF),
                                    child: Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          roundState.allPointsCompleted
                                              ? 'Ronda completa'
                                              : 'Ronda en curso',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$installation · $shiftName',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$porcentaje%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: roundState.progress,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.20,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Text(
                                    '$completados de $total puntos completados',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Inicio: ${formatearHora(roundState.roundStartedAt)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                value: '$completados',
                                label: 'Completados',
                                icon: Icons.check_circle_rounded,
                                color: verde,
                                backgroundColor: const Color(0xFFE8F8F0),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '$pendientes',
                                label: 'Pendientes',
                                icon: Icons.schedule_rounded,
                                color: naranja,
                                backgroundColor: const Color(0xFFFFF4E5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                value: '$novedades',
                                label: 'Novedades',
                                icon: Icons.warning_amber_rounded,
                                color: rojo,
                                backgroundColor: const Color(0xFFFEECEC),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Puntos de control',
                            style: TextStyle(
                              color: azulOscuro,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...roundState.points.map((point) {
                          return _SummaryPointCard(
                            point: point,
                            formattedTime: formatearHora(point.completedAt),
                          );
                        }),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: azulPrincipal,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'Fecha: ${formatearFecha(DateTime.now())}',
                                  style: const TextStyle(
                                    color: azulOscuro,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                guardName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed:
                                roundState.allPointsCompleted && !_savingRound
                                ? () {
                                    finalizarRonda(context, roundState);
                                  }
                                : null,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(
                              roundState.allPointsCompleted
                                  ? 'Finalizar ronda'
                                  : 'Completa todos los puntos',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulPrincipal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFD0D5DD),
                              disabledForegroundColor: const Color(0xFF667085),
                              elevation: roundState.allPointsCompleted ? 8 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (!roundState.allPointsCompleted) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                continuarEscaneando(context);
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Continuar escaneando'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: azulPrincipal,
                                side: const BorderSide(color: azulPrincipal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 13,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SummaryPointCard extends StatelessWidget {
  final RoundPoint point;
  final String formattedTime;

  const _SummaryPointCard({required this.point, required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    const Color azulOscuro = Color(0xFF061B44);

    const Color azulPrincipal = Color(0xFF0866FF);

    const Color verde = Color(0xFF16A36A);

    const Color naranja = Color(0xFFF59E0B);

    final Color color = point.completed
        ? point.hasNovelty
              ? naranja
              : verde
        : azulPrincipal;

    final Color backgroundColor = point.completed
        ? point.hasNovelty
              ? const Color(0xFFFFF4E5)
              : const Color(0xFFE8F8F0)
        : const Color(0xFFEAF2FF);

    final String status = point.completed
        ? point.hasNovelty
              ? 'Con novedad'
              : 'Completado'
        : 'Pendiente';

    final Color severityColor = switch (point.noveltySeverity) {
      'Crítica' => const Color(0xFFD92D20),
      'Alta' => const Color(0xFFF04438),
      'Media' => naranja,
      _ => const Color(0xFF16A36A),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 13,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              point.completed
                  ? point.hasNovelty
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded
                  : point.icon,
              color: color,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: const TextStyle(
                    color: azulOscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (point.completed) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Registrado a las $formattedTime',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (point.hasNovelty &&
                    (point.noveltyCategory != null ||
                        point.noveltySeverity != null)) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (point.noveltyCategory != null)
                        _NoveltyTag(
                          text: point.noveltyCategory!,
                          color: azulPrincipal,
                        ),
                      if (point.noveltySeverity != null)
                        _NoveltyTag(
                          text: point.noveltySeverity!,
                          color: severityColor,
                        ),
                    ],
                  ),
                ],
                if (point.observation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    point.observation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (point.noveltyPhotoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(point.noveltyPhotoPath!),
                      width: double.infinity,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoveltyTag extends StatelessWidget {
  final String text;
  final Color color;

  const _NoveltyTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
