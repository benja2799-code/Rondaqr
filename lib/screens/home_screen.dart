import 'package:flutter/material.dart';

import '../access_control.dart';
import '../app_routes.dart';
import '../auth_models.dart';
import '../round_history.dart';
import '../round_state.dart';
import '../services/sync_status.dart';
import '../services/supabase_data_coordinator.dart';
import '../services/supabase_round_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase_shift_service.dart';
import '../session_store.dart';
import '../user_accounts.dart';
import '../user_configuration.dart';
import '../work_shifts.dart';
import 'qr_scan_screen.dart';
import 'round_summary_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color naranja = Color(0xFFF59E0B);

  Future<void> abrirScanner(BuildContext context) async {
    final SessionStore sessionStore = SessionStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final AppUser? user = sessionStore.currentUser;
    final RoundState roundState = RoundState.instance;
    WorkShiftRecord? activeShift = user == null
        ? null
        : shiftStore.activeForUser(user.id);
    final String? authUid =
        SupabaseService.instance.client?.auth.currentUser?.id;
    final String localRoundId = SupabaseRoundService.instance.buildRoundLocalId(
      userId: user?.id ?? 'sin_usuario',
    );

    debugPrint(
      'RondaQR iniciar ronda | usuario activo: '
      'id=${user?.id ?? 'null'}, '
      'nombre=${user?.displayName ?? 'null'}, '
      'email=${user?.email ?? 'null'}, '
      'rol=${user?.role.name ?? 'null'}',
    );
    debugPrint('RondaQR iniciar ronda | auth.uid: ${authUid ?? 'null'}');
    debugPrint(
      'RondaQR iniciar ronda | installation_id: '
      '${user?.installationId ?? 'null'}',
    );
    debugPrint(
      'RondaQR iniciar ronda | turno activo local: '
      '${activeShift == null ? 'null' : 'id=${activeShift.id}, shiftId=${activeShift.shiftId}, status=${activeShift.statusLabel}, isActive=${activeShift.isActive}'}',
    );
    debugPrint(
      'RondaQR iniciar ronda | id real Supabase work_shifts: '
      '${activeShift?.id ?? 'null'} | uuidValido=${activeShift == null ? false : SupabaseRoundService.instance.isSupabaseUuid(activeShift.id)}',
    );
    debugPrint(
      'RondaQR iniciar ronda | status turno activo: '
      '${activeShift?.statusLabel ?? 'null'}',
    );
    debugPrint(
      'RondaQR iniciar ronda | total puntos control: '
      '${roundState.totalPoints}',
    );
    debugPrint('RondaQR iniciar ronda | local_id ronda: $localRoundId');

    if (user == null ||
        user.role != AppRole.guard ||
        !sessionStore.can(AppPermission.manageRounds) ||
        !sessionStore.can(AppPermission.scanQr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu rol no permite iniciar ni escanear rondas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final AppUser activeUser = user;

    if (SupabaseService.instance.onlineMode &&
        (activeShift == null ||
            !SupabaseRoundService.instance.isSupabaseUuid(activeShift.id))) {
      try {
        debugPrint(
          'RondaQR iniciar ronda | refrescando turno activo desde Supabase...',
        );
        await SupabaseShiftService.instance.refreshForUser(activeUser);
        activeShift = shiftStore.activeForUser(activeUser.id);
        debugPrint(
          'RondaQR iniciar ronda | turno activo tras refrescar: '
          '${activeShift == null ? 'null' : 'id=${activeShift.id}, shiftId=${activeShift.shiftId}, status=${activeShift.statusLabel}, isActive=${activeShift.isActive}, uuidValido=${SupabaseRoundService.instance.isSupabaseUuid(activeShift.id)}'}',
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'No fue posible validar el turno activo en Supabase.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    if (activeShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar tu turno antes de comenzar una ronda.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (SupabaseService.instance.onlineMode &&
        !SupabaseRoundService.instance.isSupabaseUuid(activeShift.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al asociar la ronda con el turno activo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (roundState.totalPoints == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay puntos de control activos. Activa o crea un punto desde Perfil.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (roundState.roundStarted && roundState.allPointsCompleted) {
      final RoundPoint lastPoint = roundState.points.last;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PermissionGuard(
            permission: AppPermission.manageRounds,
            child: RoundSummaryScreen(
              pointName: lastPoint.name,
              pointStatus: lastPoint.hasNovelty ? 'Con novedad' : 'Sin novedad',
              observation: lastPoint.observation,
            ),
          ),
        ),
      );

      return;
    }

    try {
      String onlineRoundId = roundState.operationalContext?.onlineRoundId ?? '';
      if (SupabaseService.instance.onlineMode && onlineRoundId.isEmpty) {
        onlineRoundId = await SupabaseRoundService.instance.startRound(
          user: activeUser,
          shift: activeShift,
          totalPoints: roundState.totalPoints,
          localId: localRoundId,
        );
      }

      await roundState.startRound(
        roundContext: RoundOperationalContext(
          userId: activeUser.id,
          guardName: activeUser.displayName,
          role: activeUser.role.label,
          installation: activeUser.installationName,
          shiftRecordId: activeShift.id,
          shiftId: activeShift.shiftId,
          shiftName: activeShift.shiftName,
          shiftScheduledStart: activeShift.scheduledStart,
          shiftScheduledEnd: activeShift.scheduledEnd,
          shiftStartedAt: activeShift.actualStartedAt,
          onlineRoundId: onlineRoundId,
          onlineRoundLocalId: localRoundId,
        ),
      );
      if (onlineRoundId.isNotEmpty) {
        await roundState.updateOnlineRoundId(onlineRoundId);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is SupabaseRoundStartException
                ? error.message
                : error is StateError
                ? error.message.toString()
                : 'No se pudo iniciar la ronda en Supabase.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PermissionGuard(
          permission: AppPermission.scanQr,
          child: QRScanScreen(),
        ),
      ),
    );
  }

  void abrirHistorial(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.history);
  }

  void abrirReportes(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.reports);
  }

  void abrirPerfil(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.profile);
  }

  void abrirNotificaciones(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.notifications);
  }

  Future<void> iniciarTurno(BuildContext context, AppUser user) async {
    try {
      final WorkShiftRecord shift = await SupabaseShiftService.instance
          .startShift(user);
      await SupabaseDataCoordinator.instance.refreshCurrentUserData(
        force: true,
      );

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Turno iniciado a las ${formatearHora(shift.actualStartedAt)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'No fue posible iniciar el turno.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> cerrarTurno(
    BuildContext context,
    AppUser user,
    RoundState roundState,
  ) async {
    if (roundState.roundStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finaliza o reinicia la ronda activa antes de cerrar el turno.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar turno'),
        content: const Text(
          'Se guardará la hora real de salida y la duración del turno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar turno'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final WorkShiftRecord closed = await SupabaseShiftService.instance
          .closeShift(user);
      await SupabaseDataCoordinator.instance.refreshCurrentUserData(
        force: true,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Turno cerrado a las ${formatearHora(closed.actualEndedAt)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'No fue posible cerrar el turno.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String formatearHora(DateTime? fecha) {
    if (fecha == null) {
      return '';
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

  String formatearDuracion(Duration duracion) {
    final int horas = duracion.inHours;
    final int minutos = duracion.inMinutes.remainder(60);

    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }

    if (minutos <= 0) {
      return '< 1 min';
    }

    return '$minutos min';
  }

  void mostrarMenuRonda(BuildContext context, RoundState roundState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Opciones de ronda',
                  style: TextStyle(
                    color: azulOscuro,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: azulPrincipal,
                    ),
                  ),
                  title: const Text(
                    'Continuar ronda',
                    style: TextStyle(
                      color: azulOscuro,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${roundState.completedPoints} de '
                    '${roundState.totalPoints} puntos completados',
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    abrirScanner(context);
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEECEC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                  title: const Text(
                    'Reiniciar ronda',
                    style: TextStyle(
                      color: Color(0xFFD92D20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Todos los puntos volverán a pendiente'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    mostrarConfirmacionReinicio(context, roundState);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void mostrarConfirmacionReinicio(
    BuildContext context,
    RoundState roundState,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Reiniciar ronda'),
          content: const Text(
            '¿Deseas borrar el progreso actual y comenzar una nueva ronda?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await roundState.resetRound();

                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La ronda fue reiniciada correctamente.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reiniciar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoundState roundState = RoundState.instance;
    final RoundHistoryStore historyStore = RoundHistoryStore.instance;
    final UserConfigurationStore configurationStore =
        UserConfigurationStore.instance;
    final SessionStore sessionStore = SessionStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;
    final UserAccountStore userAccountStore = UserAccountStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        roundState,
        historyStore,
        configurationStore,
        sessionStore,
        shiftStore,
        userAccountStore,
      ]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final AppUser? user = sessionStore.currentUser;
        final String displayName = user?.displayName ?? 'Usuario';
        final String installation =
            user?.installationName ?? configuration.installationNameDisplay;
        final String jobTitle = user?.jobTitle ?? 'Cargo sin configurar';
        final String role = user?.role.label ?? 'Sin rol';
        final bool canManageRounds =
            user?.role == AppRole.guard &&
            sessionStore.can(AppPermission.manageRounds);
        final ShiftDefinition? assignedShift = user == null
            ? null
            : shiftStore.definitionForUser(user);
        final WorkShiftRecord? activeShift = user == null
            ? null
            : shiftStore.activeForUser(user.id);
        final bool canViewHistory = sessionStore.can(AppPermission.viewHistory);
        final bool canViewReports = sessionStore.can(AppPermission.viewReports);
        final bool canViewNovelties = sessionStore.can(
          AppPermission.viewNovelties,
        );
        final int completados = roundState.completedPoints;

        final int total = roundState.totalPoints;

        final int porcentaje = (roundState.progress * 100).round();
        final bool hasHistory = historyStore.totalRounds > 0;
        final int noveltyNotifications = historyStore.rounds.fold(
          0,
          (total, round) => total + round.noveltyCount,
        );
        final List<_HomeNavigationItem> navigationItems = [
          const _HomeNavigationItem(icon: Icons.home_rounded, label: 'Inicio'),
          if (canViewHistory)
            _HomeNavigationItem(
              icon: Icons.history_rounded,
              label: 'Historial',
              onTap: () => abrirHistorial(context),
            ),
          if (canViewReports)
            _HomeNavigationItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reportes',
              onTap: () => abrirReportes(context),
            ),
          _HomeNavigationItem(
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            onTap: () => abrirPerfil(context),
          ),
        ];

        if (user?.role == AppRole.administrator) {
          return _AdminHomeScaffold(
            installation: installation,
            currentDate: formatearFecha(DateTime.now()),
            activeGuardCount: userAccountStore.activeGuards.length,
            shiftDefinitions: shiftStore.definitions,
            activeShifts: shiftStore.activeShifts,
            shiftHistory: shiftStore.history,
            rounds: historyStore.rounds,
            userAccountStore: userAccountStore,
            formatTime: formatearHora,
            formatDate: formatearFecha,
            formatDuration: formatearDuracion,
            navigationItems: navigationItems,
            notificationCount: noveltyNotifications,
            canViewNovelties: canViewNovelties,
            onOpenNotifications: () => abrirNotificaciones(context),
          );
        }

        return Scaffold(
          backgroundColor: fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [azulOscuro, azulMedio],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (canManageRounds)
                        IconButton(
                          onPressed: () {
                            if (roundState.roundStarted) {
                              mostrarMenuRonda(context, roundState);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Todavía no hay una ronda activa.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                      const Expanded(
                        child: Text(
                          'RondaQR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (canViewNovelties)
                        _NotificationBell(
                          count: noveltyNotifications,
                          onTap: () => abrirNotificaciones(context),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
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
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -12,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    size: 112,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.shield_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Bienvenido, $displayName',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Instalación',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                installation,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 9),
                                              const Text(
                                                'Cargo y rol',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                '$jobTitle · $role',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (canManageRounds &&
                                        roundState.roundStarted) ...[
                                      const SizedBox(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Progreso de ronda',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.80,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '$porcentaje%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: LinearProgressIndicator(
                                          value: roundState.progress,
                                          minHeight: 8,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.20),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                Color
                                              >(Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (canManageRounds && user != null) ...[
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: _ShiftStatusCard(
                              shift: assignedShift,
                              activeShift: activeShift,
                              formatTime: formatearHora,
                              onStart: activeShift == null
                                  ? () => iniciarTurno(context, user)
                                  : null,
                              onClose: activeShift != null
                                  ? () => cerrarTurno(context, user, roundState)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (canManageRounds)
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  abrirScanner(context);
                                },
                                icon: Icon(
                                  roundState.roundStarted
                                      ? Icons.qr_code_scanner_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                label: Text(
                                  roundState.roundStarted
                                      ? 'Continuar ronda'
                                      : hasHistory
                                      ? 'Nueva ronda'
                                      : 'Iniciar ronda',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: azulPrincipal,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: azulPrincipal.withValues(
                                    alpha: 0.35,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (canManageRounds) ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Puntos de control',
                                  style: TextStyle(
                                    color: azulOscuro,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: completados == total && total > 0
                                      ? const Color(0xFFE8F8F0)
                                      : const Color(0xFFEAF2FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$completados/$total completados',
                                  style: TextStyle(
                                    color: completados == total && total > 0
                                        ? verde
                                        : azulPrincipal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...roundState.points.map((punto) {
                            return _PuntoControlCard(
                              nombre: punto.name,
                              icono: punto.icon,
                              completado: punto.completed,
                              conNovedad: punto.hasNovelty,
                              horaCompletado: formatearHora(punto.completedAt),
                              onTap: () {
                                if (punto.completed) {
                                  mostrarPuntoCompletado(context, punto);
                                } else {
                                  abrirScanner(context);
                                }
                              },
                            );
                          }),
                        ] else
                          _RoleAccessCard(
                            role: role,
                            canViewReports: canViewReports,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              navigationItems[index].onTap?.call();
            },
            selectedItemColor: azulPrincipal,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: navigationItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  void mostrarPuntoCompletado(BuildContext context, RoundPoint punto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: punto.hasNovelty
                        ? const Color(0xFFFFF4E5)
                        : const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    punto.hasNovelty
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: punto.hasNovelty ? naranja : verde,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  punto.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: azulOscuro,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  punto.hasNovelty
                      ? 'Completado con novedad'
                      : 'Completado sin novedad',
                  style: TextStyle(
                    color: punto.hasNovelty ? naranja : verde,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (punto.completedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Registrado a las '
                    '${formatearHora(punto.completedAt)}',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                ],
                if (punto.observation.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      punto.observation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: azulOscuro, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulPrincipal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

class _AdminHomeScaffold extends StatelessWidget {
  final String installation;
  final String currentDate;
  final int activeGuardCount;
  final List<ShiftDefinition> shiftDefinitions;
  final List<WorkShiftRecord> activeShifts;
  final List<WorkShiftRecord> shiftHistory;
  final List<RoundHistoryItem> rounds;
  final UserAccountStore userAccountStore;
  final String Function(DateTime?) formatTime;
  final String Function(DateTime) formatDate;
  final String Function(Duration) formatDuration;
  final List<_HomeNavigationItem> navigationItems;
  final int notificationCount;
  final bool canViewNovelties;
  final VoidCallback onOpenNotifications;

  const _AdminHomeScaffold({
    required this.installation,
    required this.currentDate,
    required this.activeGuardCount,
    required this.shiftDefinitions,
    required this.activeShifts,
    required this.shiftHistory,
    required this.rounds,
    required this.userAccountStore,
    required this.formatTime,
    required this.formatDate,
    required this.formatDuration,
    required this.navigationItems,
    required this.notificationCount,
    required this.canViewNovelties,
    required this.onOpenNotifications,
  });

  bool _sameDay(DateTime value, DateTime day) {
    return value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;
  }

  _AdminShiftStatus _statusForShift(
    ShiftDefinition definition,
    DateTime today,
  ) {
    final AppUser? assignedGuard = definition.assignedUserId.isEmpty
        ? null
        : userAccountStore.accountById(definition.assignedUserId)?.user;

    final List<WorkShiftRecord> currentMatches = activeShifts.where((shift) {
      return shift.shiftId == definition.id &&
          (assignedGuard == null || shift.userId == assignedGuard.id);
    }).toList();
    currentMatches.sort(
      (a, b) => b.actualStartedAt.compareTo(a.actualStartedAt),
    );
    final WorkShiftRecord? current = currentMatches.isEmpty
        ? null
        : currentMatches.first;
    final bool isCurrentShift = current != null;

    if (isCurrentShift) {
      return _AdminShiftStatus(
        definition: definition,
        guardName: assignedGuard?.displayName ?? current.guardName,
        record: current,
        label: 'En turno',
        color: HomeScreen.verde,
        backgroundColor: const Color(0xFFE8F8F0),
      );
    }

    final List<WorkShiftRecord> closed = shiftHistory.where((shift) {
      return shift.shiftId == definition.id &&
          (assignedGuard == null || shift.userId == assignedGuard.id) &&
          _sameDay(shift.actualStartedAt, today);
    }).toList();

    closed.sort((a, b) {
      final DateTime aEndedAt = a.actualEndedAt ?? a.actualStartedAt;
      final DateTime bEndedAt = b.actualEndedAt ?? b.actualStartedAt;
      return bEndedAt.compareTo(aEndedAt);
    });

    if (closed.isNotEmpty) {
      final WorkShiftRecord record = closed.first;
      return _AdminShiftStatus(
        definition: definition,
        guardName: assignedGuard?.displayName ?? record.guardName,
        record: record,
        label: 'Cerrado',
        color: HomeScreen.azulPrincipal,
        backgroundColor: const Color(0xFFEAF2FF),
      );
    }

    return _AdminShiftStatus(
      definition: definition,
      guardName: assignedGuard?.displayName ?? 'Sin guardia asignado',
      record: null,
      label: 'No iniciado',
      color: HomeScreen.naranja,
      backgroundColor: const Color(0xFFFFF4E5),
    );
  }

  _AdminNoveltySummary? _latestNovelty(List<RoundHistoryItem> orderedRounds) {
    for (final RoundHistoryItem round in orderedRounds) {
      for (final RoundHistoryPoint point in round.points) {
        if (point.hasNovelty) {
          return _AdminNoveltySummary(round: round, point: point);
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final List<RoundHistoryItem> todayRounds = rounds
        .where((round) => _sameDay(round.finishedAt, today))
        .toList(growable: false);
    final int todayNoveltyCount = todayRounds.fold(
      0,
      (total, round) => total + round.noveltyCount,
    );
    final List<_AdminShiftStatus> shiftStatuses = shiftDefinitions
        .map((definition) => _statusForShift(definition, today))
        .toList(growable: false);
    final int inProgressCount = shiftStatuses
        .where((status) => status.label == 'En turno')
        .length;
    final int closedCount = shiftStatuses
        .where((status) => status.label == 'Cerrado')
        .length;
    final int notStartedCount = shiftStatuses
        .where((status) => status.label == 'No iniciado')
        .length;
    final RoundHistoryItem? latestRound = rounds.isEmpty ? null : rounds.first;
    final _AdminNoveltySummary? latestNovelty = _latestNovelty(rounds);

    final bool onlineMode = SupabaseService.instance.onlineMode;

    return Scaffold(
      backgroundColor: HomeScreen.fondo,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 92,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [HomeScreen.azulOscuro, HomeScreen.azulMedio],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Panel Administrador',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (canViewNovelties)
                    _NotificationBell(
                      count: notificationCount,
                      onTap: onOpenNotifications,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F6FFF), HomeScreen.azulMedio],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: HomeScreen.azulPrincipal.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -22,
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 112,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                onlineMode
                                    ? 'Control operativo en línea'
                                    : 'Control operativo local',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                installation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha actual: $currentDate',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _AdminHeaderMetric(
                                      value: '$activeGuardCount',
                                      label: 'Guardias activos',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _AdminHeaderMetric(
                                      value:
                                          '$inProgressCount/$closedCount/$notStartedCount',
                                      label: 'En turno / cerrados / pendientes',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _AdminStatCard(
                          value: '${todayRounds.length}',
                          label: 'Rondas hoy',
                          icon: Icons.shield_rounded,
                          color: HomeScreen.azulPrincipal,
                          backgroundColor: const Color(0xFFEAF2FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AdminStatCard(
                          value: '$todayNoveltyCount',
                          label: 'Novedades hoy',
                          icon: Icons.warning_amber_rounded,
                          color: HomeScreen.naranja,
                          backgroundColor: const Color(0xFFFFF4E5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Turnos del día',
                    style: TextStyle(
                      color: HomeScreen.azulOscuro,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (shiftStatuses.isEmpty)
                    const _AdminEmptyCard(
                      icon: Icons.schedule_rounded,
                      title: 'Sin turnos configurados',
                      message:
                          'Configura Turno Día y Turno Noche desde Perfil > Guardias y turnos.',
                    )
                  else
                    ...shiftStatuses.map((status) {
                      return _AdminShiftCard(
                        status: status,
                        formatTime: formatTime,
                        formatDuration: formatDuration,
                      );
                    }),
                  const SizedBox(height: 22),
                  const Text(
                    'Últimos registros',
                    style: TextStyle(
                      color: HomeScreen.azulOscuro,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 13),
                  _AdminLatestCard(
                    title: 'Última ronda registrada',
                    icon: Icons.route_rounded,
                    color: HomeScreen.verde,
                    text: latestRound == null
                        ? 'Aún no hay rondas finalizadas.'
                        : '${formatDate(latestRound.finishedAt)} · '
                              '${formatTime(latestRound.finishedAt)} · '
                              '${latestRound.guardName} · '
                              '${latestRound.completedPoints}/${latestRound.totalPoints} puntos',
                  ),
                  const SizedBox(height: 11),
                  _AdminLatestCard(
                    title: 'Última novedad registrada',
                    icon: Icons.notification_important_rounded,
                    color: HomeScreen.naranja,
                    text: latestNovelty == null
                        ? 'No hay novedades registradas.'
                        : '${formatDate(latestNovelty.round.finishedAt)} · '
                              '${formatTime(latestNovelty.point.completedAt ?? latestNovelty.round.finishedAt)} · '
                              '${latestNovelty.round.guardName} · '
                              '${latestNovelty.point.name}',
                    detail: latestNovelty?.point.observation,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          onlineMode
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: HomeScreen.azulPrincipal,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            onlineMode
                                ? 'Modo en línea: los turnos, rondas y novedades se leen desde Supabase para ver información de otros teléfonos.'
                                : 'Modo local: el administrador ve solo los turnos y rondas guardados en este dispositivo.',
                            style: const TextStyle(
                              color: HomeScreen.azulOscuro,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          navigationItems[index].onTap?.call();
        },
        selectedItemColor: HomeScreen.azulPrincipal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: navigationItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AdminHeaderMetric extends StatelessWidget {
  final String value;
  final String label;

  const _AdminHeaderMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _AdminStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 7),
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
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminShiftCard extends StatelessWidget {
  final _AdminShiftStatus status;
  final String Function(DateTime?) formatTime;
  final String Function(Duration) formatDuration;

  const _AdminShiftCard({
    required this.status,
    required this.formatTime,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final WorkShiftRecord? record = status.record;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  record?.isActive == true
                      ? Icons.security_rounded
                      : Icons.schedule_rounded,
                  color: status.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.guardName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeScreen.azulOscuro,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${status.definition.name} ${status.definition.schedule}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: _AdminShiftValue(
                  label: 'Ingreso real',
                  value: record == null
                      ? 'Pendiente'
                      : formatTime(record.actualStartedAt),
                ),
              ),
              Expanded(
                child: _AdminShiftValue(
                  label: 'Salida real',
                  value: record?.actualEndedAt == null
                      ? 'Pendiente'
                      : formatTime(record!.actualEndedAt),
                ),
              ),
              Expanded(
                child: _AdminShiftValue(
                  label: 'Duración',
                  value: record == null
                      ? '--'
                      : formatDuration(record.duration),
                ),
              ),
            ],
          ),
          if (record != null) ...[
            const SizedBox(height: 12),
            Text(
              '${record.roundIds.length} rondas asociadas · '
              '${record.noveltyCount} novedades · Sync: ${record.syncStatus.label}',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminShiftValue extends StatelessWidget {
  final String label;
  final String value;

  const _AdminShiftValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HomeScreen.azulOscuro,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _AdminLatestCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String text;
  final String? detail;

  const _AdminLatestCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.text,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final String? cleanDetail = detail == null || detail!.trim().isEmpty
        ? null
        : detail!.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 13,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: HomeScreen.azulOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (cleanDetail != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    cleanDetail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AdminEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, color: HomeScreen.azulPrincipal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: HomeScreen.azulOscuro,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminShiftStatus {
  final ShiftDefinition definition;
  final String guardName;
  final WorkShiftRecord? record;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _AdminShiftStatus({
    required this.definition,
    required this.guardName,
    required this.record,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });
}

class _AdminNoveltySummary {
  final RoundHistoryItem round;
  final RoundHistoryPoint point;

  const _AdminNoveltySummary({required this.round, required this.point});
}

class _ShiftStatusCard extends StatelessWidget {
  final ShiftDefinition? shift;
  final WorkShiftRecord? activeShift;
  final String Function(DateTime?) formatTime;
  final VoidCallback? onStart;
  final VoidCallback? onClose;

  const _ShiftStatusCard({
    required this.shift,
    required this.activeShift,
    required this.formatTime,
    required this.onStart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF061B44);
    const Color primaryBlue = Color(0xFF0866FF);
    const Color green = Color(0xFF16A36A);
    final bool active = activeShift != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFE8F8F0)
                      : const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  active ? Icons.schedule_rounded : Icons.badge_outlined,
                  color: active ? green : primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift?.name ?? 'Sin turno asignado',
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shift == null
                          ? 'Solicita al administrador una asignación.'
                          : 'Horario programado: ${shift!.schedule}',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Ingreso real: ${formatTime(activeShift!.actualStartedAt)}',
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFE8F8F0)
                      : const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  active ? 'En turno' : 'Pendiente',
                  style: TextStyle(
                    color: active ? green : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: active
                ? OutlinedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar turno'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD92D20),
                      side: const BorderSide(color: Color(0xFFD92D20)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: shift?.isActive == true ? onStart : null,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Iniciar turno'),
                    style: FilledButton.styleFrom(backgroundColor: primaryBlue),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PuntoControlCard extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final bool completado;
  final bool conNovedad;
  final String horaCompletado;
  final VoidCallback onTap;

  const _PuntoControlCard({
    required this.nombre,
    required this.icono,
    required this.completado,
    required this.conNovedad,
    required this.horaCompletado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color azulPrincipal = Color(0xFF0866FF);
    const Color azulOscuro = Color(0xFF061B44);
    const Color verde = Color(0xFF16A36A);
    const Color naranja = Color(0xFFF59E0B);

    final Color estadoColor = completado
        ? conNovedad
              ? naranja
              : verde
        : azulPrincipal;

    final Color estadoFondo = completado
        ? conNovedad
              ? const Color(0xFFFFF4E5)
              : const Color(0xFFE8F8F0)
        : const Color(0xFFEAF2FF);

    final String estadoTexto = completado
        ? conNovedad
              ? 'Con novedad'
              : 'Completado'
        : 'Pendiente';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: estadoFondo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    completado
                        ? conNovedad
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded
                        : icono,
                    color: estadoColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (completado && horaCompletado.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Registrado a las $horaCompletado',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: estadoFondo,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded, color: azulOscuro),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavigationItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HomeNavigationItem({
    required this.icon,
    required this.label,
    this.onTap,
  });
}

class _RoleAccessCard extends StatelessWidget {
  final String role;
  final bool canViewReports;

  const _RoleAccessCard({required this.role, required this.canViewReports});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFF0866FF),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acceso de $role',
                  style: const TextStyle(
                    color: Color(0xFF061B44),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  canViewReports
                      ? 'Puedes revisar el historial, las novedades y los reportes de la instalación desde el menú inferior.'
                      : 'Las opciones disponibles para tu rol aparecen en el menú inferior.',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasNotifications = count > 0;
    final String visibleCount = count > 99 ? '99+' : '$count';

    return Semantics(
      button: true,
      label: hasNotifications
          ? '$count novedades registradas'
          : 'Sin novedades registradas',
      child: Tooltip(
        message: hasNotifications
            ? '$count novedades registradas'
            : 'Sin novedades registradas',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white.withValues(
                alpha: hasNotifications ? 0.16 : 0.08,
              ),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    hasNotifications
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
            ),
            if (hasNotifications)
              Positioned(
                top: -4,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 21,
                    minHeight: 21,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF04438),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    visibleCount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
