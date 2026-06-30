import 'package:flutter/material.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/user_configuration.dart';

const Color _azulOscuro = Color(0xFF061B44);
const Color _azulMedio = Color(0xFF073C85);
const Color _azulPrincipal = Color(0xFF0866FF);
const Color _fondo = Color(0xFFF4F7FB);
const Color _verde = Color(0xFF16A36A);
const Color _naranja = Color(0xFFF59E0B);
const Color _rojo = Color(0xFFD92D20);
const Color _grisTexto = Color(0xFF667085);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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

    if (minutos <= 0) {
      return '< 1 min';
    }

    return '$minutos min';
  }

  Duration calcularDuracionPromedio(List<RoundHistoryItem> rondas) {
    if (rondas.isEmpty) {
      return Duration.zero;
    }

    final int totalSegundos = rondas.fold(
      0,
      (total, ronda) => total + ronda.duration.inSeconds,
    );

    return Duration(seconds: totalSegundos ~/ rondas.length);
  }

  int calcularTotalPuntos(List<RoundHistoryItem> rondas) {
    return rondas.fold(0, (total, ronda) => total + ronda.completedPoints);
  }

  int calcularTotalNovedades(List<RoundHistoryItem> rondas) {
    return rondas.fold(0, (total, ronda) => total + ronda.noveltyCount);
  }

  List<_DayReport> _obtenerReporteUltimosDias(List<RoundHistoryItem> rondas) {
    final DateTime hoy = DateTime.now();

    final List<_DayReport> resultado = [];

    for (int i = 6; i >= 0; i--) {
      final DateTime fecha = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).subtract(Duration(days: i));

      final List<RoundHistoryItem> rondasDelDia = rondas.where((ronda) {
        final DateTime fechaRonda = ronda.finishedAt;

        return fechaRonda.year == fecha.year &&
            fechaRonda.month == fecha.month &&
            fechaRonda.day == fecha.day;
      }).toList();

      resultado.add(
        _DayReport(
          date: fecha,
          totalRounds: rondasDelDia.length,
          completedRounds: rondasDelDia
              .where((ronda) => ronda.completed)
              .length,
          noveltyCount: rondasDelDia.fold(
            0,
            (total, ronda) => total + ronda.noveltyCount,
          ),
        ),
      );
    }

    return resultado;
  }

  String obtenerNombreDia(DateTime fecha) {
    const List<String> dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return dias[fecha.weekday - 1];
  }

  Color obtenerColorEstado(RoundHistoryItem ronda) {
    if (!ronda.completed) {
      return _rojo;
    }

    if (ronda.hasNovelty) {
      return _naranja;
    }

    return _verde;
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

  void mostrarInformacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: _azulPrincipal),
              SizedBox(width: 10),
              Expanded(child: Text('Acerca de los reportes')),
            ],
          ),
          content: const Text(
            'Los indicadores se calculan automáticamente '
            'utilizando las rondas guardadas durante esta sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final RoundHistoryStore historyStore = RoundHistoryStore.instance;
    final UserConfigurationStore configurationStore =
        UserConfigurationStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([historyStore, configurationStore]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final List<RoundHistoryItem> rondas = historyStore.rounds;

        final int totalRondas = rondas.length;

        final int rondasCompletadas = rondas
            .where((ronda) => ronda.completed)
            .length;

        final int totalNovedades = calcularTotalNovedades(rondas);

        final int totalPuntos = calcularTotalPuntos(rondas);

        final Duration duracionPromedio = calcularDuracionPromedio(rondas);

        final int cumplimiento = totalRondas == 0
            ? 0
            : ((rondasCompletadas / totalRondas) * 100).round();

        final List<_DayReport> reporteSemanal = _obtenerReporteUltimosDias(
          rondas,
        );

        return Scaffold(
          backgroundColor: _fondo,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_azulOscuro, _azulMedio],
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
                          'Reportes',
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
                          mostrarInformacion(context);
                        },
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: rondas.isEmpty
                      ? const _EmptyReports()
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F6FFF), _azulMedio],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: _azulPrincipal.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.analytics_outlined,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Cumplimiento general',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '$cumplimiento%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '$rondasCompletadas de $totalRondas rondas completadas',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          configuration.installationNameDisplay,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${configuration.companyDisplay} · '
                                          '${configuration.guardNameDisplay}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _ReportStatCard(
                                    title: 'Rondas',
                                    value: '$totalRondas',
                                    icon: Icons.shield_rounded,
                                    color: _azulPrincipal,
                                    backgroundColor: const Color(0xFFEAF2FF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ReportStatCard(
                                    title: 'Puntos',
                                    value: '$totalPuntos',
                                    icon: Icons.location_on_rounded,
                                    color: _verde,
                                    backgroundColor: const Color(0xFFE8F8F0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _ReportStatCard(
                                    title: 'Novedades',
                                    value: '$totalNovedades',
                                    icon: Icons.warning_amber_rounded,
                                    color: _naranja,
                                    backgroundColor: const Color(0xFFFFF4E5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ReportStatCard(
                                    title: 'Tiempo promedio',
                                    value: formatearDuracion(duracionPromedio),
                                    icon: Icons.timer_outlined,
                                    color: const Color(0xFF7A5AF8),
                                    backgroundColor: const Color(0xFFF2F0FF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'Actividad últimos 7 días',
                              style: TextStyle(
                                color: _azulOscuro,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.055,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 190,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: reporteSemanal.map((dia) {
                                        final int maximo = reporteSemanal.fold(
                                          1,
                                          (maximoActual, item) {
                                            return item.totalRounds >
                                                    maximoActual
                                                ? item.totalRounds
                                                : maximoActual;
                                          },
                                        );

                                        final double altura =
                                            dia.totalRounds == 0
                                            ? 8
                                            : 130 * (dia.totalRounds / maximo);

                                        return Expanded(
                                          child: _DayBar(
                                            day: obtenerNombreDia(dia.date),
                                            total: dia.totalRounds,
                                            completed: dia.completedRounds,
                                            noveltyCount: dia.noveltyCount,
                                            height: altura,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const Divider(height: 28),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LegendItem(
                                        color: _azulPrincipal,
                                        text: 'Rondas',
                                      ),
                                      SizedBox(width: 18),
                                      _LegendItem(
                                        color: _naranja,
                                        text: 'Con novedades',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Últimas rondas',
                                    style: TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${rondas.length} registros',
                                  style: const TextStyle(
                                    color: _grisTexto,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...rondas.take(5).map((ronda) {
                              return _RecentRoundCard(
                                date: formatearFecha(ronda.finishedAt),
                                schedule:
                                    '${formatearHora(ronda.startedAt)} - '
                                    '${formatearHora(ronda.finishedAt)}',
                                guardName: ronda.guardName,
                                installation: ronda.installation,
                                status: ronda.status,
                                points:
                                    '${ronda.completedPoints}/${ronda.totalPoints}',
                                noveltyCount: ronda.noveltyCount,
                                statusColor: obtenerColorEstado(ronda),
                                statusBackground: obtenerFondoEstado(ronda),
                                statusIcon: obtenerIconoEstado(ronda),
                              );
                            }),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: _azulPrincipal,
                                  ),
                                  SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      'Los reportes se actualizan automáticamente al finalizar cada ronda.',
                                      style: TextStyle(
                                        color: _azulOscuro,
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
        );
      },
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: _azulPrincipal,
                size: 58,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Sin información disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Finaliza una ronda para generar estadísticas, indicadores y reportes de actividad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _grisTexto, fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _ReportStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(15),
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
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _grisTexto, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String day;
  final int total;
  final int completed;
  final int noveltyCount;
  final double height;

  const _DayBar({
    required this.day,
    required this.total,
    required this.completed,
    required this.noveltyCount,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor = noveltyCount > 0 ? _naranja : _azulPrincipal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$total',
            style: TextStyle(
              color: total == 0 ? const Color(0xFF98A2B3) : barColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Tooltip(
            message:
                '$total rondas • $completed completadas • $noveltyCount novedades',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 26,
              height: height,
              decoration: BoxDecoration(
                color: total == 0 ? const Color(0xFFE4E7EC) : barColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            day,
            style: const TextStyle(
              color: _grisTexto,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: _grisTexto, fontSize: 11)),
      ],
    );
  }
}

class _RecentRoundCard extends StatelessWidget {
  final String date;
  final String schedule;
  final String guardName;
  final String installation;
  final String status;
  final String points;
  final int noveltyCount;
  final Color statusColor;
  final Color statusBackground;
  final IconData statusIcon;

  const _RecentRoundCard({
    required this.date,
    required this.schedule,
    required this.guardName,
    required this.installation,
    required this.status,
    required this.points,
    required this.noveltyCount,
    required this.statusColor,
    required this.statusBackground,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(statusIcon, color: statusColor, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  schedule,
                  style: const TextStyle(color: _grisTexto, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  '$installation · $guardName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _grisTexto,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$points puntos • $noveltyCount novedades',
                  style: const TextStyle(color: _grisTexto, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
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

class _DayReport {
  final DateTime date;
  final int totalRounds;
  final int completedRounds;
  final int noveltyCount;

  const _DayReport({
    required this.date,
    required this.totalRounds,
    required this.completedRounds,
    required this.noveltyCount,
  });
}
