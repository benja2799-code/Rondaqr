import 'package:flutter/material.dart';
import 'package:rondaqr/round_history.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color naranja = Color(0xFFF59E0B);
  static const Color rojo = Color(0xFFD92D20);

  String formatearFecha(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  String formatearHora(DateTime fecha) {
    final String hora = fecha.hour.toString().padLeft(2, '0');
    final String minuto = fecha.minute.toString().padLeft(2, '0');

    return '$hora:$minuto';
  }

  String formatearDuracion(Duration duracion) {
    final int horas = duracion.inHours;
    final int minutos = duracion.inMinutes.remainder(60);

    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }

    return '${minutos}min';
  }

  Color obtenerColorEstado(RoundHistoryItem ronda) {
    if (!ronda.completed) {
      return rojo;
    }

    if (ronda.hasNovelty) {
      return naranja;
    }

    return verde;
  }

  Color obtenerFondoEstado(RoundHistoryItem ronda) {
    if (!ronda.completed) {
      return const Color(0xFFFEECEC);
    }

    if (ronda.hasNovelty) {
      return const Color(0xFFFFF4E5);
    }

    return const Color(0xFFE8F8F0);
  }

  IconData obtenerIconoEstado(RoundHistoryItem ronda) {
    if (!ronda.completed) {
      return Icons.cancel_outlined;
    }

    if (ronda.hasNovelty) {
      return Icons.warning_amber_rounded;
    }

    return Icons.check_circle_rounded;
  }

  void mostrarDetalle(BuildContext context, RoundHistoryItem ronda) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final Color estadoColor = obtenerColorEstado(ronda);

            final Color estadoFondo = obtenerFondoEstado(ronda);

            return Container(
              decoration: const BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: estadoFondo,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                obtenerIconoEstado(ronda),
                                color: estadoColor,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ronda.status,
                                    style: const TextStyle(
                                      color: azulOscuro,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatearFecha(ronda.finishedAt),
                                    style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(bottomSheetContext);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _DetailRow(
                                icon: Icons.person_outline_rounded,
                                label: 'Guardia',
                                value: ronda.guardName,
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.apartment_rounded,
                                label: 'Instalación',
                                value: ronda.installation,
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.play_arrow_rounded,
                                label: 'Inicio',
                                value: formatearHora(ronda.startedAt),
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.stop_circle_outlined,
                                label: 'Término',
                                value: formatearHora(ronda.finishedAt),
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.timer_outlined,
                                label: 'Duración',
                                value: formatearDuracion(ronda.duration),
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.checklist_rounded,
                                label: 'Puntos',
                                value:
                                    '${ronda.completedPoints} de ${ronda.totalPoints}',
                              ),
                              const Divider(height: 28),
                              _DetailRow(
                                icon: Icons.warning_amber_rounded,
                                label: 'Novedades',
                                value: '${ronda.noveltyCount}',
                                valueColor: ronda.noveltyCount > 0
                                    ? naranja
                                    : verde,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Puntos registrados',
                          style: TextStyle(
                            color: azulOscuro,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...ronda.points.map((point) {
                          return _HistoryPointCard(
                            point: point,
                            formattedTime: point.completedAt == null
                                ? '--:--'
                                : formatearHora(point.completedAt!),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void confirmarEliminarHistorial(
    BuildContext context,
    RoundHistoryStore historyStore,
  ) {
    if (historyStore.rounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay registros para eliminar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: rojo),
              SizedBox(width: 10),
              Expanded(child: Text('Eliminar historial')),
            ],
          ),
          content: const Text(
            '¿Deseas eliminar todas las rondas guardadas durante esta sesión?',
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
                await historyStore.clearHistory();

                if (!dialogContext.mounted || !context.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El historial fue eliminado.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: rojo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoundHistoryStore historyStore = RoundHistoryStore.instance;

    return AnimatedBuilder(
      animation: historyStore,
      builder: (context, _) {
        final List<RoundHistoryItem> rondas = historyStore.rounds;

        return Scaffold(
          backgroundColor: fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [azulOscuro, azulMedio],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
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
                          'Historial de rondas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          confirmarEliminarHistorial(context, historyStore);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: rondas.isEmpty
                      ? const _EmptyHistory()
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
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
                                    color: azulPrincipal.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Historial de actividad',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${rondas.length} rondas guardadas',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Expanded(
                                  child: _HistoryStat(
                                    value: '${historyStore.totalRounds}',
                                    label: 'Total',
                                    color: azulPrincipal,
                                    backgroundColor: const Color(0xFFEAF2FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HistoryStat(
                                    value: '${historyStore.completedRounds}',
                                    label: 'Completadas',
                                    color: verde,
                                    backgroundColor: const Color(0xFFE8F8F0),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HistoryStat(
                                    value: '${historyStore.roundsWithNovelty}',
                                    label: 'Novedades',
                                    color: naranja,
                                    backgroundColor: const Color(0xFFFFF4E5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Rondas recientes',
                              style: TextStyle(
                                color: azulOscuro,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ...rondas.map((ronda) {
                              return _HistoryCard(
                                ronda: ronda,
                                formattedDate: formatearFecha(ronda.finishedAt),
                                formattedSchedule:
                                    '${formatearHora(ronda.startedAt)} - '
                                    '${formatearHora(ronda.finishedAt)}',
                                statusColor: obtenerColorEstado(ronda),
                                statusBackground: obtenerFondoEstado(ronda),
                                statusIcon: obtenerIconoEstado(ronda),
                                onTap: () {
                                  mostrarDetalle(context, ronda);
                                },
                              );
                            }),
                          ],
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF0866FF),
                size: 56,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Sin rondas registradas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF061B44),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Cuando finalices una ronda, aparecerá automáticamente en esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _HistoryStat({
    required this.value,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final RoundHistoryItem ronda;
  final String formattedDate;
  final String formattedSchedule;
  final Color statusColor;
  final Color statusBackground;
  final IconData statusIcon;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.ronda,
    required this.formattedDate,
    required this.formattedSchedule,
    required this.statusColor,
    required this.statusBackground,
    required this.statusIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.07),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Color(0xFF061B44),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedSchedule,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ronda.installation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ronda.guardName} • '
                        '${ronda.completedPoints} de '
                        '${ronda.totalPoints} puntos',
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        ronda.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF98A2B3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPointCard extends StatelessWidget {
  final RoundHistoryPoint point;
  final String formattedTime;

  const _HistoryPointCard({required this.point, required this.formattedTime});

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

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  : Icons.location_on_outlined,
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
                if (point.observation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    point.observation,
                    style: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0866FF), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF061B44),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
