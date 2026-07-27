import 'dart:async';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/sensor_thresholds.dart';
import 'package:ahs/data/remote/firebase_http.dart';
import 'package:ahs/shared/widgets/app_ui.dart';

part 'widgets/logs_widgets.dart';

enum _LogSource { none, sqlite, firebase }

// ─────────────────────────────────────────────
//  Logs Screen
// ─────────────────────────────────────────────
class LogsScreen extends StatefulWidget {
  final PlantModel plant;
  const LogsScreen({super.key, required this.plant});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // dropdown state  (SQLite + Firebase sourced)
  List<String> _years = [];
  List<String> _months = [];
  List<String> _days = [];
  List<DateTime> _localDates = [];
  List<DateTime> _firebaseDates = [];

  String? _selYear;
  String? _selMonth;
  String? _selDay;

  // table data
  List<Map<String, dynamic>> _rows = [];
  bool _metaLoading = true;
  bool _rowsLoading = false;
  bool _exporting = false;
  bool _leaving = false;
  _LogSource _source = _LogSource.none;
  String? _loadError;
  int _metadataRequest = 0;
  int _rowsRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadYears());
  }

  // ── fetch helpers ─────────────────────────
  List<DateTime> get _availableDates {
    final unique = <String, DateTime>{};
    for (final date in [..._localDates, ..._firebaseDates]) {
      final clean = DateUtils.dateOnly(date);
      unique[DateFormat('yyyy-MM-dd').format(clean)] = clean;
    }
    final dates = unique.values.toList()..sort((a, b) => b.compareTo(a));
    return dates;
  }

  List<String> _monthsFor(String year) {
    final values = _availableDates
        .where((date) => date.year.toString() == year)
        .map((date) => date.month.toString().padLeft(2, '0'))
        .toSet()
        .toList();
    values.sort(_sortNumericDesc);
    return values;
  }

  List<String> _daysFor(String year, String month) {
    final values = _availableDates
        .where(
          (date) =>
              date.year.toString() == year &&
              date.month.toString().padLeft(2, '0') == month,
        )
        .map((date) => date.day.toString().padLeft(2, '0'))
        .toSet()
        .toList();
    values.sort(_sortNumericDesc);
    return values;
  }

  int _sortNumericDesc(String a, String b) {
    return (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0);
  }

  String? _preferredValue(List<String> values, String preferred) {
    if (values.contains(preferred)) return preferred;
    return values.isEmpty ? null : values.first;
  }

  Future<void> _loadYears() async {
    try {
      final plantId = widget.plant.id;
      final localDates = plantId == null
          ? <DateTime>[]
          : await DatabaseHelper.instance.getLogDatesForPlant(plantId);
      final firebaseDates = await FirebaseHttp.instance.fetchAvailableDates();
      if (!mounted) return;

      _localDates = localDates;
      _firebaseDates = firebaseDates;
      final dates = _availableDates;
      final preferred = dates.isNotEmpty ? dates.first : DateTime.now();
      final years = dates.map((date) => date.year.toString()).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final year = _preferredValue(years, preferred.year.toString());
      final months = year == null ? <String>[] : _monthsFor(year);
      final month = _preferredValue(
        months,
        preferred.month.toString().padLeft(2, '0'),
      );
      final days = year == null || month == null
          ? <String>[]
          : _daysFor(year, month);
      final day = _preferredValue(
        days,
        preferred.day.toString().padLeft(2, '0'),
      );

      setState(() {
        _years = years;
        _selYear = year;
        _months = months;
        _selMonth = month;
        _days = days;
        _selDay = day;
        _metaLoading = false;
        _loadError = null;
      });
      if (year != null && month != null && day != null) {
        unawaited(_loadRows());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _metaLoading = false;
        _loadError = 'Unable to load the available sensor log dates.';
      });
    }
  }

  Future<void> _mergeFirebaseMonths(String year) async {
    final request = _metadataRequest;
    final remote = await FirebaseHttp.instance.fetchMonths(year);
    if (!mounted || request != _metadataRequest || _selYear != year) return;
    final valid = remote.where((value) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed >= 1 && parsed <= 12;
    });
    final months = {..._months, ...valid.map((v) => v.padLeft(2, '0'))}.toList()
      ..sort(_sortNumericDesc);
    final selectedMonth = _selMonth ?? (months.isEmpty ? null : months.first);
    setState(() {
      _months = months;
      _selMonth = selectedMonth;
    });
    if (selectedMonth != null && _days.isEmpty) {
      unawaited(_mergeFirebaseDays(year, selectedMonth));
    }
  }

  Future<void> _mergeFirebaseDays(String year, String month) async {
    final request = _metadataRequest;
    final remote = await FirebaseHttp.instance.fetchDays(year, month);
    if (!mounted ||
        request != _metadataRequest ||
        _selYear != year ||
        _selMonth != month) {
      return;
    }
    final selectedYear = int.tryParse(year);
    final selectedMonth = int.tryParse(month);
    if (selectedYear == null || selectedMonth == null) return;
    final maxDay = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    final valid = remote.where((value) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed >= 1 && parsed <= maxDay;
    });
    final remoteDates = valid.map((value) {
      final parsed = int.tryParse(value) ?? 1;
      return DateTime(selectedYear, selectedMonth, parsed);
    });
    final days = {..._days, ...valid.map((v) => v.padLeft(2, '0'))}.toList()
      ..sort(_sortNumericDesc);
    final selectedDay = _selDay ?? (days.isEmpty ? null : days.first);
    setState(() {
      _firebaseDates = [..._firebaseDates, ...remoteDates];
      _days = days;
      _selDay = selectedDay;
    });
    if (selectedDay != null && _rows.isEmpty) {
      unawaited(_loadRows());
    }
  }

  void _selectYear(String? year) {
    if (year == null || year == _selYear) return;
    _metadataRequest++;
    final months = _monthsFor(year);
    final month = months.isEmpty ? null : months.first;
    final days = month == null ? <String>[] : _daysFor(year, month);
    setState(() {
      _selYear = year;
      _months = months;
      _selMonth = month;
      _days = days;
      _selDay = days.isEmpty ? null : days.first;
      _rows = [];
      _source = _LogSource.none;
      _loadError = null;
    });
    if (_selDay != null) unawaited(_loadRows());
    unawaited(_mergeFirebaseMonths(year));
    if (month != null) unawaited(_mergeFirebaseDays(year, month));
  }

  void _selectMonth(String? month) {
    final year = _selYear;
    if (year == null || month == null || month == _selMonth) return;
    _metadataRequest++;
    final days = _daysFor(year, month);
    setState(() {
      _selMonth = month;
      _days = days;
      _selDay = days.isEmpty ? null : days.first;
      _rows = [];
      _source = _LogSource.none;
      _loadError = null;
    });
    if (_selDay != null) unawaited(_loadRows());
    unawaited(_mergeFirebaseDays(year, month));
  }

  void _selectDay(String? day) {
    if (day == null || day == _selDay) return;
    _metadataRequest++;
    setState(() {
      _selDay = day;
      _rows = [];
      _source = _LogSource.none;
      _loadError = null;
    });
    unawaited(_loadRows());
  }

  Future<void> _loadRows() async {
    if (_selYear == null || _selMonth == null || _selDay == null) return;
    final request = ++_rowsRequest;
    final year = _selYear!;
    final month = _selMonth!;
    final day = _selDay!;
    setState(() {
      _rowsLoading = true;
      _loadError = null;
    });

    try {
      final y = int.tryParse(year);
      final m = int.tryParse(month);
      final d = int.tryParse(day);
      if (y == null || m == null || d == null) {
        throw const FormatException('Invalid selected log date');
      }
      final maxDay = m < 1 || m > 12 ? 0 : DateUtils.getDaysInMonth(y, m);
      if (d < 1 || d > maxDay) {
        throw const FormatException('Selected log date is out of range');
      }
      final plantId = widget.plant.id;
      List<Map<String, dynamic>> rows = plantId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseHelper.instance.getLogsForDay(
              y,
              m,
              d,
              plantId: plantId,
            );
      var source = rows.isEmpty ? _LogSource.none : _LogSource.sqlite;

      if (rows.isEmpty) {
        final snap = await FirebaseHttp.instance.fetchDay(DateTime(y, m, d));
        rows =
            snap.entries
                .map(
                  (entry) => entry.value.toSqlMap(
                    plantId: widget.plant.id,
                    plantName: widget.plant.name,
                  ),
                )
                .toList()
              ..sort((a, b) {
                final aTs = DateTime.tryParse(a['timestamp']?.toString() ?? '');
                final bTs = DateTime.tryParse(b['timestamp']?.toString() ?? '');
                return (aTs ?? DateTime(0)).compareTo(bTs ?? DateTime(0));
              });
        source = rows.isEmpty ? _LogSource.none : _LogSource.firebase;
      }

      if (!mounted ||
          request != _rowsRequest ||
          year != _selYear ||
          month != _selMonth ||
          day != _selDay) {
        return;
      }
      setState(() {
        _rows = rows;
        _rowsLoading = false;
        _source = source;
      });
    } catch (_) {
      if (!mounted || request != _rowsRequest) return;
      setState(() {
        _rows = [];
        _rowsLoading = false;
        _source = _LogSource.none;
        _loadError = 'The sensor records could not be loaded. Please retry.';
      });
    }
  }

  // ── PDF export ────────────────────────────
  // Uses Printing.layoutPdf (renders inline preview + share)
  // matching the pattern from the working reference implementation.
  String get _sourceLabel {
    switch (_source) {
      case _LogSource.sqlite:
        return 'SQLite';
      case _LogSource.firebase:
        return 'Firebase';
      case _LogSource.none:
        return 'No source';
    }
  }

  Color get _sourceColor {
    switch (_source) {
      case _LogSource.sqlite:
        return AHSColors.primary;
      case _LogSource.firebase:
        return AHSColors.warning;
      case _LogSource.none:
        return AHSColors.textHint;
    }
  }

  Future<void> _openPdfPreview() async {
    if (_exporting || _rows.isEmpty) return;
    final dateLabel = '$_selYear-$_selMonth-$_selDay';
    final fileName = 'sensor_logs_$dateLabel.pdf';
    final rows = _rows.map((row) => Map<String, dynamic>.from(row)).toList();
    setState(() => _exporting = true);

    try {
      final bytes = await _createPreviewPdf(rows, dateLabel);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SensorLogPdfPreview(
            bytes: bytes,
            fileName: fileName,
            plantName: widget.plant.name,
            dateLabel: dateLabel,
            onPrint: _exportPdf,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create the PDF report. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _createPreviewPdf(
    List<Map<String, dynamic>> rows,
    String dateLabel,
  ) async {
    final dataRows = rows.map(_toPdfRow).toList();
    final outOfRange = dataRows.where((row) => row.hasAnomaly).length;
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 22),
        header: (_) => pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.green900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Automated Hydrophonic System',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Daily Sensor Monitoring Report',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.green100,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    dateLabel,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: _pdfSummaryBox(
                    label: 'Plant',
                    value: widget.plant.name,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _pdfSummaryBox(
                    label: 'Records',
                    value: rows.length.toString(),
                    color: PdfColors.green700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _pdfSummaryBox(
                    label: 'Source',
                    value: _sourceLabel,
                    color: PdfColors.teal700,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _pdfSummaryBox(
                    label: 'Out of range',
                    value: outOfRange.toString(),
                    color: outOfRange == 0
                        ? PdfColors.green700
                        : PdfColors.red700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: .5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated ${DateFormat('MMM d, yyyy - HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (_) => [
          _pdfTable(dataRows),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Container(
                width: 7,
                height: 7,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.red700,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                'Red values are outside the configured safe sensor range.',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  _PdfRow _toPdfRow(Map<String, dynamic> row) {
    final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
    final temperature = (row['temperature'] as num?)?.toDouble();
    final humidity = (row['humidity'] as num?)?.toDouble();
    final ph = (row['ph'] as num?)?.toDouble();
    final tds = (row['tds'] as num?)?.toDouble();
    final water = (row['waterLevel'] as num?)?.toDouble();
    return _PdfRow(
      time: timestamp == null ? '-' : DateFormat('HH:mm:ss').format(timestamp),
      temp: temperature?.toStringAsFixed(1) ?? '-',
      humid: humidity?.toStringAsFixed(0) ?? '-',
      ph: ph?.toStringAsFixed(2) ?? '-',
      tds: tds?.toStringAsFixed(0) ?? '-',
      water: water?.toStringAsFixed(1) ?? '-',
      tmpBad:
          temperature != null && SensorThresholds.isTempCritical(temperature),
      humBad: humidity != null && SensorThresholds.isHumidCritical(humidity),
      phBad: ph != null && SensorThresholds.isPhCritical(ph),
      tdsBad: tds != null && SensorThresholds.isTdsCritical(tds),
      wlBad: water != null && SensorThresholds.isWaterCritical(water),
    );
  }

  pw.Widget _pdfSummaryBox({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: .5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfTable(List<_PdfRow> rows) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: const pw.BorderSide(
          color: PdfColors.grey300,
          width: .45,
        ),
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: .45),
        left: const pw.BorderSide(color: PdfColors.grey300, width: .45),
        right: const pw.BorderSide(color: PdfColors.grey300, width: .45),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.1),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(.9),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green800),
          children:
              [
                    'Time',
                    'Temp (C)',
                    'Humidity (%)',
                    'pH',
                    'TDS (ppm)',
                    'Water (cm)',
                  ]
                  .map(
                    (heading) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        heading,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final row = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: entry.key.isOdd ? PdfColors.green50 : PdfColors.white,
            ),
            children: [
              _pdfCell(row.time, false),
              _pdfCell(row.temp, row.tmpBad),
              _pdfCell(row.humid, row.humBad),
              _pdfCell(row.ph, row.phBad),
              _pdfCell(row.tds, row.tdsBad),
              _pdfCell(row.water, row.wlBad),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _exportPdf() async {
    final dateLabel = '$_selYear-$_selMonth-$_selDay';

    await Printing.layoutPdf(
      name: 'AHS_Logs_$dateLabel.pdf',
      onLayout: (_) async {
        final doc = pw.Document();

        // Build table rows from _rows
        final dataRows = _rows.map((r) {
          final ts = DateTime.tryParse(r['timestamp'] as String? ?? '');
          final timeStr = ts != null
              ? DateFormat('HH:mm:ss').format(ts)
              : (r['timestamp'] ?? '–').toString();

          // flag anomalies
          final tmp = (r['temperature'] as num?)?.toDouble();
          final hum = (r['humidity'] as num?)?.toDouble();
          final ph = (r['ph'] as num?)?.toDouble();
          final tds = (r['tds'] as num?)?.toDouble();
          final wl = (r['waterLevel'] as num?)?.toDouble();

          final tmpBad = tmp != null && SensorThresholds.isTempCritical(tmp);
          final humBad = hum != null && SensorThresholds.isHumidCritical(hum);
          final phBad = ph != null && SensorThresholds.isPhCritical(ph);
          final tdsBad = tds != null && SensorThresholds.isTdsCritical(tds);
          final wlBad = wl != null && SensorThresholds.isWaterCritical(wl);

          return _PdfRow(
            time: timeStr,
            temp: tmp != null ? tmp.toStringAsFixed(1) : '–',
            humid: hum != null ? hum.toStringAsFixed(0) : '–',
            ph: ph != null ? ph.toStringAsFixed(2) : '–',
            tds: tds != null ? tds.toStringAsFixed(0) : '–',
            water: wl != null ? wl.toStringAsFixed(1) : '–',
            tmpBad: tmpBad,
            humBad: humBad,
            phBad: phBad,
            tdsBad: tdsBad,
            wlBad: wlBad,
          );
        }).toList();

        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            header: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AHS – Sensor Logs',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Plant: ${widget.plant.name}   |   '
                  'Date: $dateLabel   |   '
                  'Records: ${_rows.length}   |   '
                  'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(color: PdfColors.green800, thickness: 1),
                pw.SizedBox(height: 4),
              ],
            ),
            footer: (ctx) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'AHS – Automated Hydroponics System',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
            build: (_) => [
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60), // Time
                  1: const pw.FixedColumnWidth(65), // Temp
                  2: const pw.FixedColumnWidth(65), // Humidity
                  3: const pw.FixedColumnWidth(50), // pH
                  4: const pw.FixedColumnWidth(65), // TDS
                  5: const pw.FixedColumnWidth(60), // Water
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green800,
                    ),
                    children:
                        [
                              'TIME',
                              'TEMP (°C)',
                              'HUMID (%)',
                              'pH',
                              'TDS (ppm)',
                              'WATER (cm)',
                            ]
                            .map(
                              (h) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 5,
                                ),
                                child: pw.Text(
                                  h,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  // Data rows
                  ...dataRows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: idx.isOdd ? PdfColors.green50 : PdfColors.white,
                      ),
                      children: [
                        _pdfCell(row.time, false),
                        _pdfCell(row.temp, row.tmpBad),
                        _pdfCell(row.humid, row.humBad),
                        _pdfCell(row.ph, row.phBad),
                        _pdfCell(row.tds, row.tdsBad),
                        _pdfCell(row.water, row.wlBad),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '* Red values indicate sensor anomaly (outside safe range)',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.red700),
              ),
            ],
          ),
        );

        return doc.save();
      },
    );
  }

  pw.Widget _pdfCell(String text, bool isRed) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8,
        color: isRed ? PdfColors.red700 : PdfColors.black,
      ),
    ),
  );

  void _closeScreen() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).maybePop().then((_) {
      if (mounted) _leaving = false;
    });
  }

  // ── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AhsPageHeader(
                title: 'Sensor Logs',
                subtitle: widget.plant.name,
                onBack: _closeScreen,
                action: _rows.isEmpty
                    ? null
                    : IconButton.filled(
                        onPressed: _exporting ? null : _openPdfPreview,
                        tooltip: 'Export PDF',
                        style: IconButton.styleFrom(
                          backgroundColor: AHSColors.critical,
                          foregroundColor: Colors.white,
                        ),
                        icon: _exporting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded),
                      ).animate().fadeIn(duration: 250.ms),
              ),
            ),

            const SizedBox(height: 18),

            // ── Dropdowns ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _metaLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _years.isEmpty
                  ? const _MetaEmpty()
                  : Row(
                      children: [
                        Expanded(
                          child: _DD<String>(
                            label: 'Year',
                            value: _selYear,
                            items: _years,
                            display: (v) => v,
                            onChanged: _selectYear,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DD<String>(
                            label: 'Month',
                            value: _selMonth,
                            items: _months,
                            display: (v) {
                              final n = int.tryParse(v) ?? 1;
                              return DateFormat('MMM').format(DateTime(0, n));
                            },
                            onChanged: _selectMonth,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DD<String>(
                            label: 'Day',
                            value: _selDay,
                            items: _days,
                            display: (v) => v.padLeft(2, '0'),
                            onChanged: _selectDay,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 14),

            // records badge
            if (_rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _LogInfoChip(
                      label: '${_rows.length} records',
                      color: AHSColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _LogInfoChip(label: _sourceLabel, color: _sourceColor),
                  ],
                ),
              ),

            // ── Table ──────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: _rowsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? _LogLoadError(
                        message: _loadError!,
                        onRetry: _selDay == null ? _loadYears : _loadRows,
                      )
                    : _rows.isEmpty
                    ? _EmptyRows(
                        hasSelection:
                            _selYear != null &&
                            _selMonth != null &&
                            _selDay != null,
                        plantName: widget.plant.name,
                      )
                    : _LogTable(rows: _rows),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorLogPdfPreview extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final String plantName;
  final String dateLabel;
  final Future<void> Function() onPrint;

  const _SensorLogPdfPreview({
    required this.bytes,
    required this.fileName,
    required this.plantName,
    required this.dateLabel,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      appBar: AppBar(
        backgroundColor: AHSColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Preview',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            Text(
              '$plantName - $dateLabel',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: AHSColors.textSoft,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Print report',
            onPressed: onPrint,
            icon: const Icon(Icons.print_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        initialPageFormat: PdfPageFormat.a4.landscape,
        pdfFileName: fileName,
        allowPrinting: false,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        dynamicLayout: false,
        maxPageWidth: 760,
        scrollViewDecoration: const BoxDecoration(color: AHSColors.bg),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A103B27),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Generic dropdown
// ─────────────────────────────────────────────
