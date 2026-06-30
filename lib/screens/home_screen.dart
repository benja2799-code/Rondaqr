import 'package:flutter/material.dart';

import '../round_history.dart';
import '../round_state.dart';
import '../user_configuration.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'qr_scan_screen.dart';
import 'reports_screen.dart';
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
    final RoundState roundState = RoundState.instance;

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
          builder: (_) => RoundSummaryScreen(
            pointName: lastPoint.name,
            pointStatus: lastPoint.hasNovelty ? 'Con novedad' : 'Sin novedad',
            observation: lastPoint.observation,
          ),
        ),
      );

      return;
    }

    await roundState.startRound();

    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScanScreen()),
    );
  }

  void abrirHistorial(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void abrirReportes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  void abrirPerfil(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void abrirNotificaciones(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void seleccionarMenu(BuildContext context, int index) {
    switch (index) {
      case 0:
        break;

      case 1:
        abrirHistorial(context);
        break;

      case 2:
        abrirReportes(context);
        break;

      case 3:
        abrirPerfil(context);
        break;
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

    return AnimatedBuilder(
      animation: Listenable.merge([
        roundState,
        historyStore,
        configurationStore,
      ]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final int completados = roundState.completedPoints;

        final int total = roundState.totalPoints;

        final int porcentaje = (roundState.progress * 100).round();
        final bool hasHistory = historyStore.totalRounds > 0;

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
                      ),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              abrirNotificaciones(context);
                            },
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: azulPrincipal,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                                                'Bienvenido, '
                                                '${configuration.guardNameDisplay}',
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
                                                configuration
                                                    .installationNameDisplay,
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
                                                'Turno',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                configuration.shiftDisplay,
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
                                    if (roundState.roundStarted) ...[
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
              seleccionarMenu(context, index);
            },
            selectedItemColor: azulPrincipal,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: 'Historial',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Reportes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Perfil',
              ),
            ],
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
