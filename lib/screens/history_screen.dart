import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/round_history_filters.dart';
import 'package:rondaqr/services/supabase_round_service.dart';
import 'package:rondaqr/services/supabase_service.dart';
import 'package:rondaqr/session_store.dart';
import 'package:rondaqr/widgets/round_history_filters.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color azulOscuro = Color(0xFF061B44);
  static const Color azulMedio = Color(0xFF073C85);
  static const Color azulPrincipal = Color(0xFF0866FF);
  static const Color fondo = Color(0xFFF4F7FB);
  static const Color verde = Color(0xFF16A36A);
  static const Color naranja = Color(0xFFF59E0B);
  static const Color rojo = Color(0xFFD92D20);

  final TextEditingController _searchController = TextEditingController();
  RoundHistoryFilters _filters = RoundHistoryFilters();
  bool _loadingOnlineHistory = false;
  bool _onlineHistoryLoaded = false;
  String? _onlineHistoryError;
  String? _onlineHistoryTechnicalDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOnlineHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineHistory() async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    final AppUser? user = SessionStore.instance.currentUser;
    if (user == null || _loadingOnlineHistory) {
      return;
    }

    setState(() {
      _loadingOnlineHistory = true;
      _onlineHistoryError = null;
      _onlineHistoryTechnicalDetail = null;
    });

    try {
      await SupabaseRoundService.instance.loadCompletedRoundsForHistory(
        user,
        caller: 'HistoryScreen',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _onlineHistoryLoaded = true;
      });
    } catch (error, stackTrace) {
      debugPrint('No se pudo cargar el historial desde Supabase: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _onlineHistoryLoaded = true;
        _onlineHistoryError = error is SupabaseHistoryLoadException
            ? error.message
            : 'No se pudo cargar el historial desde Supabase.';
        _onlineHistoryTechnicalDetail = error is SupabaseHistoryLoadException
            ? error.technicalDetail
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOnlineHistory = false;
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    if (SupabaseService.instance.onlineMode) {
      await _loadOnlineHistory();
    }
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _filters.clear();
    });
  }

  Future<void> _openFilters(List<RoundHistoryItem> rounds) async {
    final RoundHistoryFilters? selected = await showRoundHistoryFilters(
      context: context,
      currentFilters: _filters,
      rounds: rounds,
    );

    if (selected == null || !mounted) {
      return;
    }

    _searchController.text = selected.searchText;

    setState(() {
      _filters = selected;
    });
  }

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
                                icon: Icons.schedule_rounded,
                                label: 'Turno',
                                value: ronda.shiftDisplay,
                              ),
                              if (ronda.shiftStartedAt != null) ...[
                                const Divider(height: 28),
                                _DetailRow(
                                  icon: Icons.login_rounded,
                                  label: 'Ingreso al turno',
                                  value: formatearHora(ronda.shiftStartedAt!),
                                ),
                              ],
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
    final SessionStore sessionStore = SessionStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([historyStore, sessionStore]),
      builder: (context, _) {
        final AppUser? user = sessionStore.currentUser;
        final bool onlineMode = SupabaseService.instance.onlineMode;
        final List<RoundHistoryItem> allRounds = historyStore.rounds.where((
          round,
        ) {
          if (user == null) {
            return false;
          }
          if (user.role != AppRole.guard) {
            return true;
          }
          return round.guardId == user.id ||
              (round.guardId.isEmpty && round.guardName == user.displayName);
        }).toList();
        final List<RoundHistoryItem> rondas = _filters.apply(allRounds);
        final int completedRounds = rondas
            .where((round) => round.completed)
            .length;
        final int roundsWithNovelty = rondas
            .where((round) => round.hasNovelty)
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
                      if (user?.role == AppRole.administrator && !onlineMode)
                        IconButton(
                          onPressed: () {
                            confirmarEliminarHistorial(context, historyStore);
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshHistory,
                    child:
                        onlineMode &&
                            !_onlineHistoryLoaded &&
                            _loadingOnlineHistory
                        ? const _HistoryLoading()
                        : _onlineHistoryError != null
                        ? _HistoryLoadError(
                            message: _onlineHistoryError!,
                            technicalDetail: _onlineHistoryTechnicalDetail,
                            onRetry: _loadOnlineHistory,
                          )
                        : allRounds.isEmpty
                        ? const _HistoryScrollablePlaceholder(
                            child: _EmptyHistory(),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              RoundHistoryFilterPanel(
                                searchController: _searchController,
                                resultCount: rondas.length,
                                activeFilterCount: _filters.activeCount,
                                hasActiveFilters: _filters.isActive,
                                onSearchChanged: (value) {
                                  setState(() {
                                    _filters.searchText = value;
                                  });
                                },
                                onOpenFilters: () => _openFilters(allRounds),
                                onClearFilters: _clearFilters,
                              ),
                              const SizedBox(height: 18),
                              if (rondas.isEmpty)
                                NoRoundFilterResults(
                                  onClearFilters: _clearFilters,
                                )
                              else ...[
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
                                              '${rondas.length} ${rondas.length == 1 ? 'ronda encontrada' : 'rondas encontradas'}',
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
                                        value: '${rondas.length}',
                                        label: 'Total',
                                        color: azulPrincipal,
                                        backgroundColor: const Color(
                                          0xFFEAF2FF,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _HistoryStat(
                                        value: '$completedRounds',
                                        label: 'Completadas',
                                        color: verde,
                                        backgroundColor: const Color(
                                          0xFFE8F8F0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _HistoryStat(
                                        value: '$roundsWithNovelty',
                                        label: 'Novedades',
                                        color: naranja,
                                        backgroundColor: const Color(
                                          0xFFFFF4E5,
                                        ),
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
                                    formattedDate: formatearFecha(
                                      ronda.finishedAt,
                                    ),
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

class _HistoryScrollablePlaceholder extends StatelessWidget {
  final Widget child;

  const _HistoryScrollablePlaceholder({required this.child});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height - 160;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: height < 360 ? 360 : height, child: child)],
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const _HistoryScrollablePlaceholder(
      child: Center(child: CircularProgressIndicator(color: Color(0xFF0866FF))),
    );
  }
}

class _HistoryLoadError extends StatelessWidget {
  final String message;
  final String? technicalDetail;
  final Future<void> Function() onRetry;

  const _HistoryLoadError({
    required this.message,
    required this.technicalDetail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _HistoryScrollablePlaceholder(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFD92D20),
                size: 58,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF061B44),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (technicalDetail != null && technicalDetail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Detalle técnico: $technicalDetail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
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
                        '${ronda.guardName} • ${ronda.shiftName.isEmpty ? 'Turno no registrado' : ronda.shiftName} • '
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

    final Color severityColor = switch (point.noveltySeverity) {
      'Crítica' => const Color(0xFFD92D20),
      'Alta' => const Color(0xFFF04438),
      'Media' => naranja,
      _ => verde,
    };

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
                if (point.hasNovelty &&
                    (point.noveltyCategory != null ||
                        point.noveltySeverity != null)) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (point.noveltyCategory != null)
                        _HistoryNoveltyTag(
                          text: point.noveltyCategory!,
                          color: azulPrincipal,
                        ),
                      if (point.noveltySeverity != null)
                        _HistoryNoveltyTag(
                          text: point.noveltySeverity!,
                          color: severityColor,
                        ),
                    ],
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
                if (point.noveltyPhotoPath != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(point.noveltyPhotoPath!),
                      width: double.infinity,
                      height: 115,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

class _HistoryNoveltyTag extends StatelessWidget {
  final String text;
  final Color color;

  const _HistoryNoveltyTag({required this.text, required this.color});

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
