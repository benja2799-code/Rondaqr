import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../round_history.dart';
import '../work_shifts.dart';

enum ReportPdfPeriodType { weekly, monthly }

class ReportPdfRequest {
  final ReportPdfPeriodType type;
  final DateTime baseDate;
  final String guardId;
  final String guardName;
  final String shiftId;
  final String shiftName;
  final bool onlyWithNovelties;

  const ReportPdfRequest({
    required this.type,
    required this.baseDate,
    this.guardId = '',
    this.guardName = '',
    this.shiftId = '',
    this.shiftName = '',
    this.onlyWithNovelties = false,
  });
}

class GeneratedReportPdf {
  final File file;
  final DateTime from;
  final DateTime to;
  final String periodLabel;
  final int shiftCount;
  final int roundCount;
  final int noveltyCount;

  const GeneratedReportPdf({
    required this.file,
    required this.from,
    required this.to,
    required this.periodLabel,
    required this.shiftCount,
    required this.roundCount,
    required this.noveltyCount,
  });
}

class ReportPdfService {
  const ReportPdfService();

  Future<GeneratedReportPdf> generateReport({
    required ReportPdfRequest request,
    required String company,
    required String installation,
    required List<WorkShiftRecord> shifts,
    required List<RoundHistoryItem> rounds,
  }) async {
    final _ReportPeriod period = _periodFor(request);
    final List<RoundHistoryItem> filteredRounds = _filterRounds(
      rounds,
      period,
      request,
    );
    final List<WorkShiftRecord> filteredShifts = _filterShifts(
      shifts,
      filteredRounds,
      period,
      request,
    );
    final int totalNovelties = filteredRounds.fold(
      0,
      (total, round) => total + round.noveltyCount,
    );
    final int totalPoints = filteredRounds.fold(
      0,
      (total, round) => total + round.completedPoints,
    );
    final Set<String> guards = {
      ...filteredRounds.map((round) => round.guardName),
      ...filteredShifts.map((shift) => shift.guardName),
    }..removeWhere((guard) => guard.trim().isEmpty);

    final pw.Document document = pw.Document();
    final PdfColor blue = PdfColor.fromHex('#061B44');
    final PdfColor mediumBlue = PdfColor.fromHex('#073C85');
    final PdfColor lightBlue = PdfColor.fromHex('#EAF2FF');
    final PdfColor orange = PdfColor.fromHex('#F59E0B');

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        header: (_) => _header(
          blue: blue,
          mediumBlue: mediumBlue,
          title: 'Reporte de Rondas y Turnos - RondaQR',
          company: company.trim().isEmpty ? 'LG Seguridad SPA' : company,
          installation: installation,
          period: period.label,
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) {
          return [
            pw.SizedBox(height: 12),
            _sectionTitle('Resumen ejecutivo', blue),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryBox('Turnos', '${filteredShifts.length}', lightBlue),
                _summaryBox('Rondas', '${filteredRounds.length}', lightBlue),
                _summaryBox('Novedades', '$totalNovelties', lightBlue),
                _summaryBox('Puntos escaneados', '$totalPoints', lightBlue),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Guardias incluidos: ${guards.isEmpty ? 'Sin registros' : guards.join(', ')}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Fecha de generación: ${_formatDateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 18),
            _sectionTitle('Tabla de turnos', blue),
            pw.SizedBox(height: 8),
            _buildShiftTable(filteredShifts),
            pw.SizedBox(height: 18),
            _sectionTitle('Tabla de rondas', blue),
            pw.SizedBox(height: 8),
            _buildRoundTable(filteredRounds),
            pw.SizedBox(height: 18),
            _sectionTitle('Tabla de novedades', blue),
            pw.SizedBox(height: 8),
            _buildNoveltyTable(filteredRounds, orange),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Durante el periodo seleccionado se registraron '
                '${filteredRounds.length} rondas, ${filteredShifts.length} turnos '
                'y $totalNovelties novedades.',
                style: pw.TextStyle(
                  color: blue,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ];
        },
      ),
    );

    final Directory directory = await getApplicationDocumentsDirectory();
    final String fileName =
        'RondaQR_${request.type == ReportPdfPeriodType.weekly ? 'semanal' : 'mensual'}_${_fileDate(period.from)}_${_fileDate(period.to)}.pdf';
    final File file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(await document.save(), flush: true);

    return GeneratedReportPdf(
      file: file,
      from: period.from,
      to: period.to,
      periodLabel: period.label,
      shiftCount: filteredShifts.length,
      roundCount: filteredRounds.length,
      noveltyCount: totalNovelties,
    );
  }

  List<RoundHistoryItem> _filterRounds(
    List<RoundHistoryItem> rounds,
    _ReportPeriod period,
    ReportPdfRequest request,
  ) {
    return rounds
        .where((round) {
          if (round.finishedAt.isBefore(period.from) ||
              !round.finishedAt.isBefore(period.toExclusive)) {
            return false;
          }

          if (request.guardId.isNotEmpty && round.guardId != request.guardId) {
            return false;
          }

          if (request.guardId.isEmpty &&
              request.guardName.isNotEmpty &&
              round.guardName != request.guardName) {
            return false;
          }

          if (request.shiftId.isNotEmpty && round.shiftId != request.shiftId) {
            return false;
          }

          if (request.shiftId.isEmpty &&
              request.shiftName.isNotEmpty &&
              round.shiftName != request.shiftName) {
            return false;
          }

          if (request.onlyWithNovelties && !round.hasNovelty) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  List<WorkShiftRecord> _filterShifts(
    List<WorkShiftRecord> shifts,
    List<RoundHistoryItem> filteredRounds,
    _ReportPeriod period,
    ReportPdfRequest request,
  ) {
    final Set<String> noveltyShiftRecordIds = filteredRounds
        .where((round) => round.hasNovelty && round.shiftRecordId.isNotEmpty)
        .map((round) => round.shiftRecordId)
        .toSet();

    return shifts
        .where((shift) {
          if (shift.actualStartedAt.isBefore(period.from) ||
              !shift.actualStartedAt.isBefore(period.toExclusive)) {
            return false;
          }

          if (request.guardId.isNotEmpty && shift.userId != request.guardId) {
            return false;
          }

          if (request.guardId.isEmpty &&
              request.guardName.isNotEmpty &&
              shift.guardName != request.guardName) {
            return false;
          }

          if (request.shiftId.isNotEmpty && shift.shiftId != request.shiftId) {
            return false;
          }

          if (request.shiftId.isEmpty &&
              request.shiftName.isNotEmpty &&
              shift.shiftName != request.shiftName) {
            return false;
          }

          if (request.onlyWithNovelties &&
              shift.noveltyCount == 0 &&
              !noveltyShiftRecordIds.contains(shift.id)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  _ReportPeriod _periodFor(ReportPdfRequest request) {
    final DateTime day = DateTime(
      request.baseDate.year,
      request.baseDate.month,
      request.baseDate.day,
    );

    if (request.type == ReportPdfPeriodType.weekly) {
      final DateTime from = day.subtract(Duration(days: day.weekday - 1));
      final DateTime to = from.add(const Duration(days: 6));
      return _ReportPeriod(
        from: from,
        to: to,
        toExclusive: to.add(const Duration(days: 1)),
        label: 'Semana ${_formatDate(from)} al ${_formatDate(to)}',
      );
    }

    final DateTime from = DateTime(day.year, day.month);
    final DateTime toExclusive = DateTime(day.year, day.month + 1);
    final DateTime to = toExclusive.subtract(const Duration(days: 1));
    return _ReportPeriod(
      from: from,
      to: to,
      toExclusive: toExclusive,
      label: 'Mes ${day.month.toString().padLeft(2, '0')}/${day.year}',
    );
  }

  pw.Widget _header({
    required PdfColor blue,
    required PdfColor mediumBlue,
    required String title,
    required String company,
    required String installation,
    required String period,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: blue,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '$company · $installation',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
          pw.Text(
            period,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        color: color,
        fontWeight: pw.FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  pw.Widget _summaryBox(String label, String value, PdfColor background) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildShiftTable(List<WorkShiftRecord> shifts) {
    if (shifts.isEmpty) {
      return _emptyTable('No hay turnos para el periodo seleccionado.');
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headers: [
        'Fecha',
        'Guardia',
        'Turno',
        'Ingreso real',
        'Salida real',
        'Duración',
        'Estado',
      ],
      data: shifts.map((shift) {
        return [
          _formatDate(shift.actualStartedAt),
          shift.guardName,
          shift.shiftName,
          _formatTime(shift.actualStartedAt),
          shift.actualEndedAt == null
              ? 'Pendiente'
              : _formatTime(shift.actualEndedAt!),
          _formatDuration(shift.duration),
          shift.statusLabel,
        ];
      }).toList(),
    );
  }

  pw.Widget _buildRoundTable(List<RoundHistoryItem> rounds) {
    if (rounds.isEmpty) {
      return _emptyTable('No hay rondas para el periodo seleccionado.');
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headers: [
        'Fecha',
        'Guardia',
        'Turno',
        'Inicio',
        'Término',
        'Puntos',
        'Novedades',
      ],
      data: rounds.map((round) {
        return [
          _formatDate(round.finishedAt),
          round.guardName,
          round.shiftName.isEmpty ? 'No registrado' : round.shiftName,
          _formatTime(round.startedAt),
          _formatTime(round.finishedAt),
          '${round.completedPoints}/${round.totalPoints}',
          '${round.noveltyCount}',
        ];
      }).toList(),
    );
  }

  pw.Widget _buildNoveltyTable(
    List<RoundHistoryItem> rounds,
    PdfColor highlight,
  ) {
    final List<List<String>> rows = [];
    for (final RoundHistoryItem round in rounds) {
      for (final RoundHistoryPoint point in round.points) {
        if (!point.hasNovelty) {
          continue;
        }
        final DateTime noveltyDate = point.completedAt ?? round.finishedAt;
        rows.add([
          _formatDate(noveltyDate),
          _formatTime(noveltyDate),
          round.guardName,
          point.name,
          point.observation.trim().isEmpty
              ? 'Sin observación'
              : point.observation.trim(),
        ]);
      }
    }

    if (rows.isEmpty) {
      return _emptyTable('No hay novedades para el periodo seleccionado.');
    }

    return pw.TableHelper.fromTextArray(
      headerDecoration: pw.BoxDecoration(color: highlight),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Fecha', 'Hora', 'Guardia', 'Punto', 'Observación'],
      data: rows,
    );
  }

  pw.Widget _emptyTable(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatTime(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }

  static String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    if (minutes <= 0) {
      return '< 1 min';
    }
    return '$minutes min';
  }

  static String _fileDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}$month$day';
  }
}

class _ReportPeriod {
  final DateTime from;
  final DateTime to;
  final DateTime toExclusive;
  final String label;

  const _ReportPeriod({
    required this.from,
    required this.to,
    required this.toExclusive,
    required this.label,
  });
}
