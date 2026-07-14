import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rondaqr/auth_models.dart';
import 'package:rondaqr/round_history.dart';
import 'package:rondaqr/round_history_filters.dart';
import 'package:rondaqr/services/report_pdf_service.dart';
import 'package:rondaqr/services/supabase_round_service.dart';
import 'package:rondaqr/services/supabase_service.dart';
import 'package:rondaqr/session_store.dart';
import 'package:rondaqr/user_accounts.dart';
import 'package:rondaqr/user_configuration.dart';
import 'package:rondaqr/widgets/round_history_filters.dart';
import 'package:rondaqr/work_shifts.dart';
import 'package:share_plus/share_plus.dart';

const Color _azulOscuro = Color(0xFF061B44);
const Color _azulMedio = Color(0xFF073C85);
const Color _azulPrincipal = Color(0xFF0866FF);
const Color _fondo = Color(0xFFF4F7FB);
const Color _verde = Color(0xFF16A36A);
const Color _naranja = Color(0xFFF59E0B);
const Color _rojo = Color(0xFFD92D20);
const Color _grisTexto = Color(0xFF667085);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ReportPdfService _reportPdfService = const ReportPdfService();
  RoundHistoryFilters _filters = RoundHistoryFilters();
  DateTime _reportBaseDate = DateTime.now();
  String _reportGuardId = '';
  String _reportShiftId = '';
  bool _reportOnlyWithNovelties = false;
  bool _generatingPdf = false;
  GeneratedReportPdf? _lastGeneratedPdf;
  bool _loadingOnlineRounds = false;
  bool _onlineRoundsLoaded = false;
  String? _onlineRoundsError;
  String? _onlineRoundsTechnicalDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOnlineReportRounds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineReportRounds() async {
    if (!SupabaseService.instance.onlineMode) {
      return;
    }

    final AppUser? user = SessionStore.instance.currentUser;
    if (user == null || _loadingOnlineRounds) {
      return;
    }

    setState(() {
      _loadingOnlineRounds = true;
      _onlineRoundsError = null;
      _onlineRoundsTechnicalDetail = null;
    });

    try {
      await SupabaseRoundService.instance.loadCompletedRoundsForHistory(
        user,
        caller: 'ReportsScreen',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _onlineRoundsLoaded = true;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo cargar la información de reportes desde Supabase: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _onlineRoundsLoaded = true;
        _onlineRoundsError =
            'No se pudo cargar la información de reportes desde Supabase.';
        _onlineRoundsTechnicalDetail = error is SupabaseHistoryLoadException
            ? error.technicalDetail
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOnlineRounds = false;
        });
      }
    }
  }

  Future<void> _refreshReports() async {
    if (SupabaseService.instance.onlineMode) {
      await _loadOnlineReportRounds();
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

  List<WorkShiftRecord> _allShiftRecords(WorkShiftStore shiftStore) {
    final List<WorkShiftRecord> shifts = List<WorkShiftRecord>.from(
      shiftStore.history,
    );
    final WorkShiftRecord? activeShift = shiftStore.activeShift;
    if (activeShift != null &&
        !shifts.any((shift) => shift.id == activeShift.id)) {
      shifts.add(activeShift);
    }
    shifts.sort((a, b) => b.actualStartedAt.compareTo(a.actualStartedAt));
    return shifts;
  }

  Future<void> _pickReportBaseDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _reportBaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona fecha del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _reportBaseDate = selected;
      _lastGeneratedPdf = null;
    });
  }

  Future<void> _generateReportPdf({
    required ReportPdfPeriodType type,
    required UserConfiguration configuration,
    required UserAccountStore userStore,
    required WorkShiftStore shiftStore,
    required List<RoundHistoryItem> rounds,
  }) async {
    if (_generatingPdf) {
      return;
    }

    setState(() {
      _generatingPdf = true;
    });

    try {
      final String guardName = _reportGuardId.isEmpty
          ? ''
          : userStore.accountById(_reportGuardId)?.user.displayName ?? '';
      final ShiftDefinition? shiftDefinition = _reportShiftId.isEmpty
          ? null
          : shiftStore.definitionById(_reportShiftId);

      final GeneratedReportPdf generated = await _reportPdfService
          .generateReport(
            request: ReportPdfRequest(
              type: type,
              baseDate: _reportBaseDate,
              guardId: _reportGuardId,
              guardName: guardName,
              shiftId: _reportShiftId,
              shiftName: shiftDefinition?.name ?? '',
              onlyWithNovelties: _reportOnlyWithNovelties,
            ),
            company: configuration.companyDisplay,
            installation: configuration.installationNameDisplay,
            shifts: _allShiftRecords(shiftStore),
            rounds: rounds,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastGeneratedPdf = generated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF generado: ${generated.roundCount} rondas, '
            '${generated.shiftCount} turnos y '
            '${generated.noveltyCount} novedades.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible generar el PDF. Intenta nuevamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  Future<void> _shareLastPdf() async {
    final GeneratedReportPdf? generated = _lastGeneratedPdf;
    if (generated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero genera un PDF semanal o mensual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final File file = generated.file;
    if (!await file.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El archivo PDF ya no está disponible. Genéralo otra vez.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Rect? shareOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;

    await SharePlus.instance.share(
      ShareParams(
        title: 'Reporte RondaQR',
        subject: 'Reporte ${generated.periodLabel}',
        text: 'Reporte RondaQR - ${generated.periodLabel}',
        files: [XFile(file.path, mimeType: 'application/pdf')],
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  void _showSavedPdfPath() {
    final GeneratedReportPdf? generated = _lastGeneratedPdf;
    if (generated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero genera un PDF semanal o mensual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF guardado en: ${generated.file.path}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
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

  String? obtenerResumenNovedades(RoundHistoryItem ronda) {
    final List<RoundHistoryPoint> noveltyPoints = ronda.points
        .where((point) => point.hasNovelty)
        .toList();

    if (noveltyPoints.isEmpty) {
      return null;
    }

    final Set<String> categories = noveltyPoints
        .map((point) => point.noveltyCategory)
        .whereType<String>()
        .where((category) => category.isNotEmpty)
        .toSet();
    const Map<String, int> severityOrder = {
      'Baja': 1,
      'Media': 2,
      'Alta': 3,
      'Crítica': 4,
    };
    String? highestSeverity;

    for (final RoundHistoryPoint point in noveltyPoints) {
      final String? severity = point.noveltySeverity;

      if (severity == null) {
        continue;
      }

      if (highestSeverity == null ||
          (severityOrder[severity] ?? 0) >
              (severityOrder[highestSeverity] ?? 0)) {
        highestSeverity = severity;
      }
    }

    final List<String> details = [];

    if (categories.isNotEmpty) {
      details.add(categories.join(', '));
    }

    if (highestSeverity != null) {
      details.add('Gravedad máxima: $highestSeverity');
    }

    return details.isEmpty ? null : details.join(' · ');
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
    final SessionStore sessionStore = SessionStore.instance;
    final UserAccountStore userStore = UserAccountStore.instance;
    final WorkShiftStore shiftStore = WorkShiftStore.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        historyStore,
        configurationStore,
        sessionStore,
        userStore,
        shiftStore,
      ]),
      builder: (context, _) {
        final UserConfiguration configuration =
            configurationStore.configuration;
        final String currentUserName =
            sessionStore.currentUser?.displayName ?? 'Administrador';
        final bool onlineMode = SupabaseService.instance.onlineMode;
        final List<RoundHistoryItem> allRounds = historyStore.rounds;
        final List<WorkShiftRecord> allShifts = _allShiftRecords(shiftStore);
        final bool hasReportData = allRounds.isNotEmpty || allShifts.isNotEmpty;
        final List<RoundHistoryItem> rondas = _filters.apply(allRounds);

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
                  child: RefreshIndicator(
                    onRefresh: _refreshReports,
                    child:
                        onlineMode &&
                            !_onlineRoundsLoaded &&
                            _loadingOnlineRounds
                        ? const _ReportsLoading()
                        : _onlineRoundsError != null
                        ? _ReportsLoadError(
                            message: _onlineRoundsError!,
                            technicalDetail: _onlineRoundsTechnicalDetail,
                            onRetry: _loadOnlineReportRounds,
                          )
                        : !hasReportData
                        ? const _ReportsScrollablePlaceholder(
                            child: _EmptyReports(),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _PdfReportPanel(
                                baseDate: _reportBaseDate,
                                selectedGuardId: _reportGuardId,
                                selectedShiftId: _reportShiftId,
                                onlyWithNovelties: _reportOnlyWithNovelties,
                                generating: _generatingPdf,
                                lastGeneratedPdf: _lastGeneratedPdf,
                                userStore: userStore,
                                shiftStore: shiftStore,
                                formatDate: formatearFecha,
                                onPickDate: _pickReportBaseDate,
                                onGuardChanged: (value) {
                                  setState(() {
                                    _reportGuardId = value ?? '';
                                    _lastGeneratedPdf = null;
                                  });
                                },
                                onShiftChanged: (value) {
                                  setState(() {
                                    _reportShiftId = value ?? '';
                                    _lastGeneratedPdf = null;
                                  });
                                },
                                onOnlyNoveltiesChanged: (value) {
                                  setState(() {
                                    _reportOnlyWithNovelties = value;
                                    _lastGeneratedPdf = null;
                                  });
                                },
                                onGenerateWeekly: () => _generateReportPdf(
                                  type: ReportPdfPeriodType.weekly,
                                  configuration: configuration,
                                  userStore: userStore,
                                  shiftStore: shiftStore,
                                  rounds: allRounds,
                                ),
                                onGenerateMonthly: () => _generateReportPdf(
                                  type: ReportPdfPeriodType.monthly,
                                  configuration: configuration,
                                  userStore: userStore,
                                  shiftStore: shiftStore,
                                  rounds: allRounds,
                                ),
                                onShowSavedPath: _showSavedPdfPath,
                                onShare: _shareLastPdf,
                              ),
                              const SizedBox(height: 18),
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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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
                                              configuration
                                                  .installationNameDisplay,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${configuration.companyDisplay} · $currentUserName',
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
                                        backgroundColor: const Color(
                                          0xFFEAF2FF,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'Puntos',
                                        value: '$totalPuntos',
                                        icon: Icons.location_on_rounded,
                                        color: _verde,
                                        backgroundColor: const Color(
                                          0xFFE8F8F0,
                                        ),
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
                                        backgroundColor: const Color(
                                          0xFFFFF4E5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ReportStatCard(
                                        title: 'Tiempo promedio',
                                        value: formatearDuracion(
                                          duracionPromedio,
                                        ),
                                        icon: Icons.timer_outlined,
                                        color: const Color(0xFF7A5AF8),
                                        backgroundColor: const Color(
                                          0xFFF2F0FF,
                                        ),
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
                                            final int maximo = reporteSemanal
                                                .fold(1, (maximoActual, item) {
                                                  return item.totalRounds >
                                                          maximoActual
                                                      ? item.totalRounds
                                                      : maximoActual;
                                                });

                                            final double altura =
                                                dia.totalRounds == 0
                                                ? 8
                                                : 130 *
                                                      (dia.totalRounds /
                                                          maximo);

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                    shiftName: ronda.shiftName,
                                    status: ronda.status,
                                    points:
                                        '${ronda.completedPoints}/${ronda.totalPoints}',
                                    noveltyCount: ronda.noveltyCount,
                                    noveltyDetail: obtenerResumenNovedades(
                                      ronda,
                                    ),
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

class _ReportsScrollablePlaceholder extends StatelessWidget {
  final Widget child;

  const _ReportsScrollablePlaceholder({required this.child});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height - 160;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: height < 360 ? 360 : height, child: child)],
    );
  }
}

class _ReportsLoading extends StatelessWidget {
  const _ReportsLoading();

  @override
  Widget build(BuildContext context) {
    return const _ReportsScrollablePlaceholder(
      child: Center(child: CircularProgressIndicator(color: _azulPrincipal)),
    );
  }
}

class _ReportsLoadError extends StatelessWidget {
  final String message;
  final String? technicalDetail;
  final Future<void> Function() onRetry;

  const _ReportsLoadError({
    required this.message,
    required this.technicalDetail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportsScrollablePlaceholder(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, color: _rojo, size: 58),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _azulOscuro,
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
                    color: _grisTexto,
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

class _PdfReportPanel extends StatelessWidget {
  final DateTime baseDate;
  final String selectedGuardId;
  final String selectedShiftId;
  final bool onlyWithNovelties;
  final bool generating;
  final GeneratedReportPdf? lastGeneratedPdf;
  final UserAccountStore userStore;
  final WorkShiftStore shiftStore;
  final String Function(DateTime) formatDate;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onGuardChanged;
  final ValueChanged<String?> onShiftChanged;
  final ValueChanged<bool> onOnlyNoveltiesChanged;
  final VoidCallback onGenerateWeekly;
  final VoidCallback onGenerateMonthly;
  final VoidCallback onShowSavedPath;
  final VoidCallback onShare;

  const _PdfReportPanel({
    required this.baseDate,
    required this.selectedGuardId,
    required this.selectedShiftId,
    required this.onlyWithNovelties,
    required this.generating,
    required this.lastGeneratedPdf,
    required this.userStore,
    required this.shiftStore,
    required this.formatDate,
    required this.onPickDate,
    required this.onGuardChanged,
    required this.onShiftChanged,
    required this.onOnlyNoveltiesChanged,
    required this.onGenerateWeekly,
    required this.onGenerateMonthly,
    required this.onShowSavedPath,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final List<LocalUserAccount> guards = userStore.accounts
        .where((account) => account.user.role == AppRole.guard)
        .toList(growable: false);
    final List<ShiftDefinition> shifts = shiftStore.definitions;
    final GeneratedReportPdf? generated = lastGeneratedPdf;
    final String guardValue =
        guards.any((account) => account.user.id == selectedGuardId)
        ? selectedGuardId
        : '';
    final String shiftValue = shifts.any((shift) => shift.id == selectedShiftId)
        ? selectedShiftId
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: _azulPrincipal,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes PDF',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Semanal o mensual, listo para compartir.',
                      style: TextStyle(color: _grisTexto, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: generating ? null : onPickDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text('Fecha base: ${formatDate(baseDate)}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _azulPrincipal,
              side: const BorderSide(color: _azulPrincipal),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: guardValue,
            decoration: _pdfInputDecoration(
              label: 'Guardia',
              icon: Icons.person_outline_rounded,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos')),
              ...guards.map((account) {
                return DropdownMenuItem(
                  value: account.user.id,
                  child: Text(account.user.displayName),
                );
              }),
            ],
            onChanged: generating ? null : onGuardChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: shiftValue,
            decoration: _pdfInputDecoration(
              label: 'Turno',
              icon: Icons.schedule_rounded,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos')),
              ...shifts.map((shift) {
                return DropdownMenuItem(
                  value: shift.id,
                  child: Text('${shift.name} ${shift.schedule}'),
                );
              }),
            ],
            onChanged: generating ? null : onShiftChanged,
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: onlyWithNovelties,
            activeThumbColor: _azulPrincipal,
            title: const Text(
              'Solo con novedades',
              style: TextStyle(color: _azulOscuro, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Incluye solo rondas o turnos con novedades registradas.',
            ),
            onChanged: generating ? null : onOnlyNoveltiesChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: generating ? null : onGenerateWeekly,
                  icon: generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.date_range_rounded),
                  label: const Text('Generar semanal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulPrincipal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: generating ? null : onGenerateMonthly,
                  icon: const Icon(Icons.calendar_view_month_rounded),
                  label: const Text('Generar mensual'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulPrincipal,
                    side: const BorderSide(color: _azulPrincipal),
                  ),
                ),
              ),
            ],
          ),
          if (generated != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Último PDF: ${generated.periodLabel} · '
                '${generated.roundCount} rondas · '
                '${generated.shiftCount} turnos · '
                '${generated.noveltyCount} novedades',
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShowSavedPath,
                    icon: const Icon(Icons.download_done_rounded),
                    label: const Text('Descargar PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _verde,
                      side: const BorderSide(color: _verde),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _pdfInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _fondo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
  final String shiftName;
  final String status;
  final String points;
  final int noveltyCount;
  final String? noveltyDetail;
  final Color statusColor;
  final Color statusBackground;
  final IconData statusIcon;

  const _RecentRoundCard({
    required this.date,
    required this.schedule,
    required this.guardName,
    required this.installation,
    required this.shiftName,
    required this.status,
    required this.points,
    required this.noveltyCount,
    required this.noveltyDetail,
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
                  '$installation · $guardName'
                  '${shiftName.isEmpty ? '' : ' · $shiftName'}',
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
                if (noveltyDetail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    noveltyDetail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _naranja,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
