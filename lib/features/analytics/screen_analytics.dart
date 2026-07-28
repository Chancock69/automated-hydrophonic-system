import 'dart:math';
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
import 'package:ahs/data/models/analytics_summary.dart';
import 'package:ahs/data/models/harvest_event.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:ahs/shared/widgets/app_ui.dart';

class AnalyticsScreen extends StatefulWidget {
  final PlantModel plant;

  const AnalyticsScreen({super.key, required this.plant});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _future;
  _AnalyticsRange _range = _AnalyticsRange.all;
  _AnalyticsMetric _metric = _AnalyticsMetric.temperature;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final plantId = widget.plant.id;
    if (plantId == null) {
      return _AnalyticsData(
        rows: const [],
        summary: AnalyticsSummary.fromRows(const []),
        hasAnyRows: false,
      );
    }

    final rows = await DatabaseHelper.instance.getLogsForPlant(plantId);
    final harvestEvents = await DatabaseHelper.instance.getHarvestEvents(
      plantId: plantId,
    );
    final filteredRows = _selectedDate == null
        ? _range.filter(rows)
        : _filterRowsForDate(rows, _selectedDate!);
    return _AnalyticsData(
      rows: filteredRows,
      harvestEvents: harvestEvents,
      summary: AnalyticsSummary.fromRows(filteredRows),
      hasAnyRows: rows.isNotEmpty,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  List<Map<String, dynamic>> _filterRowsForDate(
    List<Map<String, dynamic>> rows,
    DateTime selected,
  ) {
    final day = DateUtils.dateOnly(selected);
    return rows.where((row) {
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      return timestamp != null && DateUtils.isSameDay(timestamp, day);
    }).toList();
  }

  Future<void> _pickTimelineDate() async {
    final now = DateTime.now();
    final plantId = widget.plant.id;
    final logDates = plantId == null
        ? <DateTime>[]
        : await DatabaseHelper.instance.getLogDatesForPlant(plantId);
    if (!mounted) return;

    final startCandidates = [
      DateUtils.dateOnly(widget.plant.addedDate),
      ...logDates.map(DateUtils.dateOnly),
    ]..sort();
    final endCandidates = [
      DateUtils.dateOnly(widget.plant.addedDate),
      if (widget.plant.harvestDate != null)
        DateUtils.dateOnly(widget.plant.harvestDate!),
      if (widget.plant.actualHarvestDate != null)
        DateUtils.dateOnly(widget.plant.actualHarvestDate!),
      if (!widget.plant.isHarvested) DateUtils.dateOnly(now),
      ...logDates.map(DateUtils.dateOnly),
    ]..sort();
    final firstDate = startCandidates.first;
    final lastDate = endCandidates.last.isBefore(firstDate)
        ? firstDate
        : endCandidates.last;
    final preferred =
        _selectedDate ??
        (logDates.isEmpty
            ? widget.plant.actualHarvestDate ?? now
            : logDates.first);
    final initial = DateUtils.dateOnly(preferred);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) || initial.isAfter(lastDate)
          ? lastDate
          : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select a plant timeline date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _future = _load();
    });
  }

  void _clearTimelineDate() {
    setState(() {
      _selectedDate = null;
      _future = _load();
    });
  }

  Future<void> _exportPdf() async {
    final data = await _future;
    final bytes = await _buildAnalyticsPdf(data);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AnalyticsPdfPreview(
          bytes: bytes,
          fileName: '${widget.plant.name}-analytics.pdf',
          plantName: widget.plant.name,
        ),
      ),
    );
  }

  Future<Uint8List> _buildAnalyticsPdf(_AnalyticsData data) async {
    final doc = pw.Document();
    final summary = data.summary;
    String metricLine(String label, MetricStats? stats, String unit) {
      if (stats == null) return '$label: no readings';
      return '$label: latest ${stats.latest.toStringAsFixed(1)}$unit | avg ${stats.average.toStringAsFixed(1)}$unit | min ${stats.min.toStringAsFixed(1)}$unit | max ${stats.max.toStringAsFixed(1)}$unit';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColors.green900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Plant Analytics Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  widget.plant.name,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.green100,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Generated ${DateFormat('MM-dd-yyyy h:mm a').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Timeline',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Planted: ${DateFormat('MM-dd-yyyy').format(widget.plant.addedDate)}',
          ),
          pw.Text(
            'Monitoring days: ${DateTime.now().difference(widget.plant.addedDate).inDays.clamp(0, 9999)}',
          ),
          pw.Text(
            'Planned harvest: ${widget.plant.harvestDate == null ? 'Not set' : DateFormat('MM-dd-yyyy').format(widget.plant.harvestDate!)}',
          ),
          pw.Text(
            'Actual harvest: ${widget.plant.actualHarvestDate == null ? 'Not harvested' : DateFormat('MM-dd-yyyy').format(widget.plant.actualHarvestDate!)}',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Sensor Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Records: ${summary.totalRecords}'),
          pw.Text(
            'Anomalies: ${summary.anomalyCount} (${summary.anomalyRate.toStringAsFixed(0)}%)',
          ),
          pw.Text(metricLine('Temperature', summary.temperature, ' C')),
          pw.Text(metricLine('Humidity', summary.humidity, '%')),
          pw.Text(metricLine('pH', summary.ph, '')),
          pw.Text(metricLine('TDS', summary.tds, ' ppm')),
          pw.Text(metricLine('Water level', summary.waterLevel, ' cm')),
          pw.SizedBox(height: 18),
          pw.Text(
            'Harvest History',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (data.harvestEvents.isEmpty)
            pw.Text('No harvest records yet')
          else
            ...data.harvestEvents.map(
              (event) => pw.Text(
                '${DateFormat('MM-dd-yyyy').format(event.harvestedAt)} - ${event.weightKg.toStringAsFixed(1)} kg - ${event.lifeRate.toStringAsFixed(0)}% survival',
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: FutureBuilder<_AnalyticsData>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final data = snap.data;

            return RefreshIndicator(
              color: AHSColors.primary,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _AnalyticsHeader(
                      plant: widget.plant,
                      onBack: () => Navigator.pop(context),
                      onExport: data == null ? null : _exportPdf,
                    ),
                  ),
                  if (loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data == null ||
                      (!data.hasAnyRows &&
                          data.harvestEvents.isEmpty &&
                          _selectedDate == null))
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _AnalyticsEmpty(plantName: widget.plant.name),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _AnalyticsFilters(
                          range: _range,
                          metric: _metric,
                          selectedDate: _selectedDate,
                          onRangeChanged: (range) {
                            setState(() {
                              _range = range;
                              _selectedDate = null;
                              _future = _load();
                            });
                          },
                          onMetricChanged: (metric) {
                            setState(() => _metric = metric);
                          },
                          onPickDate: _pickTimelineDate,
                          onClearDate: _clearTimelineDate,
                        ),
                      ),
                    ),
                    if (data.summary.hasData) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: _SummaryBand(summary: data.summary),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _MetricTrendChart(
                            rows: data.rows,
                            metric: _metric,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _MetricInsight(
                            summary: data.summary,
                            rows: data.rows,
                            metric: _metric,
                          ),
                        ),
                      ),
                    ],
                    if (!data.summary.hasData)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _NoReadingsForDate(
                            selectedDate: _selectedDate,
                            onClear: _clearTimelineDate,
                          ),
                        ),
                      ),
                    if (data.harvestEvents.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _HarvestAnalyticsCard(
                            events: data.harvestEvents,
                            plant: widget.plant,
                          ),
                        ),
                      ),
                    if (data.summary.hasData)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.list(
                          children: [
                            _MetricCard(
                              label: 'Temperature',
                              unit: 'C',
                              icon: Icons.thermostat_rounded,
                              color: AHSColors.neonCyan,
                              stats: data.summary.temperature,
                              decimals: 1,
                            ),
                            const SizedBox(height: 10),
                            _MetricCard(
                              label: 'Humidity',
                              unit: '%',
                              icon: Icons.water_drop_rounded,
                              color: AHSColors.neonGreen,
                              stats: data.summary.humidity,
                              decimals: 0,
                            ),
                            const SizedBox(height: 10),
                            _MetricCard(
                              label: 'pH Level',
                              unit: '',
                              icon: Icons.science_rounded,
                              color: AHSColors.warning,
                              stats: data.summary.ph,
                              decimals: 2,
                            ),
                            const SizedBox(height: 10),
                            _MetricCard(
                              label: 'TDS',
                              unit: 'ppm',
                              icon: Icons.bubble_chart_rounded,
                              color: AHSColors.primaryMid,
                              stats: data.summary.tds,
                              decimals: 0,
                            ),
                            const SizedBox(height: 10),
                            _MetricCard(
                              label: 'Water Level',
                              unit: 'cm',
                              icon: Icons.waves_rounded,
                              color: AHSColors.neonLime,
                              stats: data.summary.waterLevel,
                              decimals: 1,
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsData {
  final List<Map<String, dynamic>> rows;
  final List<HarvestEvent> harvestEvents;
  final AnalyticsSummary summary;
  final bool hasAnyRows;

  const _AnalyticsData({
    required this.rows,
    this.harvestEvents = const [],
    required this.summary,
    required this.hasAnyRows,
  });
}

enum _AnalyticsRange {
  today('Today', Duration(days: 1)),
  sevenDays('7 Days', Duration(days: 7)),
  thirtyDays('30 Days', Duration(days: 30)),
  all('All', null);

  final String label;
  final Duration? duration;

  const _AnalyticsRange(this.label, this.duration);

  List<Map<String, dynamic>> filter(List<Map<String, dynamic>> rows) {
    final range = duration;
    if (range == null) return rows;

    final cutoff = DateTime.now().subtract(range);
    return rows.where((row) {
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      return timestamp != null && !timestamp.isBefore(cutoff);
    }).toList();
  }
}

enum _AnalyticsMetric {
  temperature(
    label: 'Temperature',
    key: 'temperature',
    unit: 'C',
    decimals: 1,
    icon: Icons.thermostat_rounded,
    color: AHSColors.neonCyan,
    min: 18,
    max: 30,
  ),
  humidity(
    label: 'Humidity',
    key: 'humidity',
    unit: '%',
    decimals: 0,
    icon: Icons.water_drop_rounded,
    color: AHSColors.neonGreen,
    min: 50,
    max: 90,
  ),
  ph(
    label: 'pH Level',
    key: 'ph',
    unit: 'pH',
    decimals: 2,
    icon: Icons.science_rounded,
    color: AHSColors.warning,
    min: 5.5,
    max: 7.5,
  ),
  tds(
    label: 'TDS',
    key: 'tds',
    unit: 'ppm',
    decimals: 0,
    icon: Icons.bubble_chart_rounded,
    color: AHSColors.primaryMid,
    min: 200,
    max: 2000,
  ),
  waterLevel(
    label: 'Water Level',
    key: 'waterLevel',
    unit: 'cm',
    decimals: 1,
    icon: Icons.waves_rounded,
    color: AHSColors.neonLime,
    min: 0,
    max: 20,
  );

  final String label;
  final String key;
  final String unit;
  final int decimals;
  final IconData icon;
  final Color color;
  final double min;
  final double max;

  const _AnalyticsMetric({
    required this.label,
    required this.key,
    required this.unit,
    required this.decimals,
    required this.icon,
    required this.color,
    required this.min,
    required this.max,
  });

  bool isAnomaly(double value) {
    if (this == _AnalyticsMetric.waterLevel) return value > max;
    return value < min || value > max;
  }

  MetricStats? statsOf(AnalyticsSummary summary) {
    switch (this) {
      case _AnalyticsMetric.temperature:
        return summary.temperature;
      case _AnalyticsMetric.humidity:
        return summary.humidity;
      case _AnalyticsMetric.ph:
        return summary.ph;
      case _AnalyticsMetric.tds:
        return summary.tds;
      case _AnalyticsMetric.waterLevel:
        return summary.waterLevel;
    }
  }
}

class _AnalyticsHeader extends StatelessWidget {
  final PlantModel plant;
  final VoidCallback onBack;
  final VoidCallback? onExport;

  const _AnalyticsHeader({
    required this.plant,
    required this.onBack,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: AhsPageHeader(
        title: 'Analytics',
        subtitle: plant.name,
        onBack: onBack,
        action: IconButton.filled(
          tooltip: 'Export PDF report',
          onPressed: onExport,
          style: IconButton.styleFrom(
            backgroundColor: AHSColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 21),
        ),
      ),
    );
  }
}

class _AnalyticsPdfPreview extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final String plantName;

  const _AnalyticsPdfPreview({
    required this.bytes,
    required this.fileName,
    required this.plantName,
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
              'Analytics PDF',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            Text(
              plantName,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: AHSColors.textSoft,
              ),
            ),
          ],
        ),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: fileName,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        dynamicLayout: false,
        maxPageWidth: 720,
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

class _AnalyticsFilters extends StatelessWidget {
  final _AnalyticsRange range;
  final _AnalyticsMetric metric;
  final DateTime? selectedDate;
  final ValueChanged<_AnalyticsRange> onRangeChanged;
  final ValueChanged<_AnalyticsMetric> onMetricChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  const _AnalyticsFilters({
    required this.range,
    required this.metric,
    required this.selectedDate,
    required this.onRangeChanged,
    required this.onMetricChanged,
    required this.onPickDate,
    required this.onClearDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _AnalyticsRange.values
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.label),
                      selected: item == range,
                      onSelected: (_) => onRangeChanged(item),
                      selectedColor: AHSColors.primary.withAlpha(28),
                      labelStyle: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: item == range
                            ? AHSColors.primary
                            : AHSColors.textSoft,
                      ),
                      side: BorderSide(
                        color: item == range
                            ? AHSColors.primaryLight
                            : AHSColors.border,
                      ),
                      backgroundColor: AHSColors.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onPickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AHSColors.bgCard,
                    borderRadius: BorderRadius.circular(AHSTheme.controlRadius),
                    border: Border.all(color: AHSColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        color: AHSColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'Pick timeline date'
                              : DateFormat('MM-dd-yyyy').format(selectedDate!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AHSColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selectedDate != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClearDate,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AHSColors.bgCard,
                    borderRadius: BorderRadius.circular(AHSTheme.controlRadius),
                    border: Border.all(color: AHSColors.border),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AHSColors.textSoft,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AHSColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AHSColors.border, width: 1.5),
          ),
          child: DropdownButton<_AnalyticsMetric>(
            value: metric,
            isExpanded: true,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AHSColors.textSoft,
            ),
            items: _AnalyticsMetric.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Row(
                      children: [
                        Icon(item.icon, color: item.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AHSColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onMetricChanged(value);
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final AnalyticsSummary summary;

  const _SummaryBand({required this.summary});

  @override
  Widget build(BuildContext context) {
    final range = _dateRange(summary.firstTimestamp, summary.lastTimestamp);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AHSColors.primary, AHSColors.primaryMid, Color(0xFF58D989)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AHSColors.primary.withAlpha(70),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            range,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Records',
                  value: summary.totalRecords.toString(),
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Out of Range',
                  value: summary.anomalyCount.toString(),
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Outlier Rate',
                  value: '${summary.anomalyRate.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  String _dateRange(DateTime? first, DateTime? last) {
    if (first == null || last == null) return 'No date range';
    final fmt = DateFormat('MM-dd HH:mm');
    if (DateUtils.isSameDay(first, last)) {
      return '${DateFormat('MM-dd-yyyy').format(first)}  ${DateFormat('HH:mm').format(first)}-${DateFormat('HH:mm').format(last)}';
    }
    return '${fmt.format(first)} - ${fmt.format(last)}';
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white60,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MetricTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final _AnalyticsMetric metric;

  const _MetricTrendChart({required this.rows, required this.metric});

  @override
  Widget build(BuildContext context) {
    final recent = rows.length > 36 ? rows.sublist(rows.length - 36) : rows;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${metric.label} Trend',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              _ChartLegend(color: metric.color, label: metric.unit),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: _AxisChartFrame(
              yLabel: metric.unit.isEmpty ? metric.label : metric.unit,
              xLabel: 'Readings over time',
              child: LineChart(_chartData(recent)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  LineChartData _chartData(List<Map<String, dynamic>> data) {
    return LineChartData(
      minY: _chartMin(data),
      maxY: _chartMax(data),
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AHSColors.divider, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 20,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: AHSColors.textSoft,
              ),
            ),
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineBarsData: [_line(data, metric.key, metric.color)],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: metric.min,
            color: AHSColors.stable.withAlpha(95),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
          HorizontalLine(
            y: metric.max,
            color: AHSColors.warning.withAlpha(110),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ],
      ),
    );
  }

  double _chartMin(List<Map<String, dynamic>> data) {
    final values = data.map((row) => _metricValue(row)).nonNulls;
    final minValue = values.isEmpty
        ? metric.min
        : values.reduce((a, b) => a < b ? a : b);
    return (minValue < metric.min ? minValue : metric.min) - 2;
  }

  double _chartMax(List<Map<String, dynamic>> data) {
    final values = data.map((row) => _metricValue(row)).nonNulls;
    final maxValue = values.isEmpty
        ? metric.max
        : values.reduce((a, b) => a > b ? a : b);
    return (maxValue > metric.max ? maxValue : metric.max) + 2;
  }

  LineChartBarData _line(
    List<Map<String, dynamic>> data,
    String key,
    Color color,
  ) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        final raw = _double(entry.value[key]) ?? 0;
        final value = key == 'ph' ? SensorSnapshot.normalizePh(raw) : raw;
        return FlSpot(entry.key.toDouble(), value);
      }).toList(),
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.6,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(22)),
    );
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _metricValue(Map<String, dynamic> row) {
    final value = _double(row[metric.key]);
    if (value == null) return null;
    return metric == _AnalyticsMetric.ph
        ? SensorSnapshot.normalizePh(value)
        : value;
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: AHSColors.textMid,
          ),
        ),
      ],
    );
  }
}

class _MetricInsight extends StatelessWidget {
  final AnalyticsSummary summary;
  final List<Map<String, dynamic>> rows;
  final _AnalyticsMetric metric;

  const _MetricInsight({
    required this.summary,
    required this.rows,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final stats = metric.statsOf(summary);
    final anomalyCount = rows.where((row) {
      final raw = _double(row[metric.key]);
      final value = raw == null
          ? null
          : metric == _AnalyticsMetric.ph
          ? SensorSnapshot.normalizePh(raw)
          : raw;
      return value != null && metric.isAnomaly(value);
    }).length;
    final latest = stats == null
        ? '--'
        : stats.latest.toStringAsFixed(metric.decimals);
    final isLatestBad = stats != null && metric.isAnomaly(stats.latest);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLatestBad
              ? AHSColors.critical.withAlpha(120)
              : AHSColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: metric.color.withAlpha(28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$latest ${metric.unit}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Safe range: ${metric.min.toStringAsFixed(metric.decimals)}-${metric.max.toStringAsFixed(metric.decimals)} ${metric.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AHSColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (anomalyCount > 0 ? AHSColors.critical : AHSColors.stable)
                  .withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$anomalyCount out of range',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: anomalyCount > 0 ? AHSColors.critical : AHSColors.stable,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _HarvestAnalyticsCard extends StatelessWidget {
  final List<HarvestEvent> events;
  final PlantModel plant;

  const _HarvestAnalyticsCard({required this.events, required this.plant});

  @override
  Widget build(BuildContext context) {
    final totalWeight = events.fold<double>(
      0,
      (total, event) => total + event.weightKg,
    );
    final avgLifeRate =
        events.fold<double>(0, (total, event) => total + event.lifeRate) /
        events.length;
    final recentEvents = events.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.agriculture_rounded,
                color: AHSColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Harvest Productivity',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              Text(
                '${events.length} batch${events.length == 1 ? '' : 'es'}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HarvestMiniStat(
                label: 'Weight',
                value: totalWeight.toStringAsFixed(1),
                unit: 'kg',
                color: AHSColors.primaryMid,
              ),
              const SizedBox(width: 8),
              _HarvestMiniStat(
                label: 'Life Rate',
                value: avgLifeRate.toStringAsFixed(0),
                unit: '%',
                color: AHSColors.stable,
              ),
              const SizedBox(width: 8),
              _HarvestMiniStat(
                label: 'Batches',
                value: events.length.toString(),
                unit: '',
                color: AHSColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HarvestBatchSummary(events: recentEvents),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _HarvestBatchSummary extends StatelessWidget {
  final List<HarvestEvent> events;

  const _HarvestBatchSummary({required this.events});

  @override
  Widget build(BuildContext context) {
    final maxWeight = events.fold<double>(
      1,
      (value, event) => max(value, event.weightKg),
    );

    return Column(
      children: events.map((event) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AHSColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AHSColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MM-dd-yyyy').format(event.harvestedAt),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AHSColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    event.markedDone ? 'Ended' : 'Continuing',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: event.markedDone
                          ? AHSColors.warning
                          : AHSColors.stable,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BatchProgressLine(
                label: 'Weight',
                value: '${event.weightKg.toStringAsFixed(1)} kg',
                ratio: (event.weightKg / maxWeight).clamp(0.04, 1.0),
                color: AHSColors.primaryMid,
              ),
              const SizedBox(height: 8),
              _BatchProgressLine(
                label: 'Life rate',
                value:
                    '${event.survivedCount}/${event.totalCount} plants - ${event.lifeRate.toStringAsFixed(0)}%',
                ratio: (event.lifeRate / 100).clamp(0.04, 1.0),
                color: event.lifeRate >= 70
                    ? AHSColors.stable
                    : AHSColors.warning,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BatchProgressLine extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _BatchProgressLine({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AHSColors.textSoft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: color.withAlpha(22),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _HarvestMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _HarvestMiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value$unit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AHSColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantDateMapCard extends StatefulWidget {
  final PlantModel plant;
  final List<HarvestEvent> events;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _PlantDateMapCard({
    required this.plant,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_PlantDateMapCard> createState() => _PlantDateMapCardState();
}

class _PlantDateMapCardState extends State<_PlantDateMapCard> {
  late DateTime _month = _calendarMonth();

  @override
  void didUpdateWidget(covariant _PlantDateMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plant.id != widget.plant.id) {
      _month = _calendarMonth();
    }
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final end =
        widget.plant.actualHarvestDate ??
        widget.plant.harvestDate ??
        DateTime.now();
    final growDays = DateUtils.dateOnly(end)
        .difference(DateUtils.dateOnly(widget.plant.addedDate))
        .inDays
        .clamp(0, 9999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AHSColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plant Calendar',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _AnalyticsCalendarMonthNav(
            month: _month,
            onPrevious: () => _moveMonth(-1),
            onNext: () => _moveMonth(1),
          ),
          const SizedBox(height: 10),
          if (widget.selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AHSColors.primary.withAlpha(14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Selected ${DateFormat('MM-dd-yyyy').format(widget.selectedDate!)}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 290,
            child: _SinglePlantCalendar(
              month: _month,
              plant: widget.plant,
              events: widget.events,
              selectedDate: widget.selectedDate,
              onDateSelected: widget.onDateSelected,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _dateStatusColor(widget.plant).withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${_dateStatusText(widget.plant)} - $growDays growth day${growDays == 1 ? '' : 's'} mapped',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _dateStatusColor(widget.plant),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  DateTime _calendarMonth() {
    final dates = <DateTime>[
      widget.plant.addedDate,
      if (widget.plant.harvestDate != null) widget.plant.harvestDate!,
      if (widget.plant.actualHarvestDate != null)
        widget.plant.actualHarvestDate!,
      for (final event in widget.events) event.harvestedAt,
    ]..sort((a, b) => b.compareTo(a));
    final selected = dates.isEmpty ? DateTime.now() : dates.first;
    return DateTime(selected.year, selected.month);
  }

  static Color _dateStatusColor(PlantModel plant) {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (actual == null) return AHSColors.textSoft;
    if (planned == null) return AHSColors.primary;
    final delta = DateUtils.dateOnly(
      actual,
    ).difference(DateUtils.dateOnly(planned)).inDays;
    if (delta < 0) return AHSColors.stable;
    if (delta > 0) return AHSColors.warning;
    return AHSColors.primaryMid;
  }

  static String _dateStatusText(PlantModel plant) {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (actual == null) return 'Still growing';
    if (planned == null) return 'Harvest completed';
    final delta = DateUtils.dateOnly(
      actual,
    ).difference(DateUtils.dateOnly(planned)).inDays;
    if (delta < 0) {
      final days = delta.abs();
      return 'Harvested $days day${days == 1 ? '' : 's'} early';
    }
    if (delta > 0) return 'Harvested $delta day${delta == 1 ? '' : 's'} late';
    return 'Harvested on schedule';
  }
}

class _SinglePlantCalendar extends StatelessWidget {
  final DateTime month;
  final PlantModel plant;
  final List<HarvestEvent> events;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _SinglePlantCalendar({
    required this.month,
    required this.plant,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    return Column(
      children: [
        Row(
          children: const [
            _CalendarLegend(color: Color(0xFF2563EB), label: 'Planted'),
            SizedBox(width: 8),
            _CalendarLegend(color: AHSColors.stable, label: 'Early'),
            SizedBox(width: 8),
            _CalendarLegend(color: AHSColors.warning, label: 'Ended'),
            SizedBox(width: 8),
            _CalendarLegend(color: AHSColors.neonCyan, label: 'Multi'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (day) => Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AHSColors.textSoft,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(month.year, month.month, dayNumber);
              return _CalendarDayCell(
                day: dayNumber,
                markers: _markersFor(date),
                inTimeline: _isInTimeline(date),
                selected:
                    selectedDate != null &&
                    DateUtils.isSameDay(selectedDate, date),
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Color> _markersFor(DateTime date) {
    final markers = <Color>[];
    if (_sameDate(date, plant.addedDate)) {
      markers.add(const Color(0xFF2563EB));
    }
    if (plant.harvestDate != null && _sameDate(date, plant.harvestDate!)) {
      markers.add(AHSColors.warning);
    }
    if (plant.actualHarvestDate != null &&
        _sameDate(date, plant.actualHarvestDate!)) {
      markers.add(_actualHarvestColor());
    }
    for (final event in events) {
      if (!_sameDate(date, event.harvestedAt)) continue;
      markers.add(event.markedDone ? AHSColors.warning : AHSColors.neonCyan);
    }
    return markers.take(4).toList();
  }

  bool _isInTimeline(DateTime date) {
    final day = DateUtils.dateOnly(date);
    final start = DateUtils.dateOnly(plant.addedDate);
    final end = DateUtils.dateOnly(
      plant.actualHarvestDate ?? plant.harvestDate ?? DateTime.now(),
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Color _actualHarvestColor() {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (plant.harvestType == PlantHarvestType.multiple) {
      return AHSColors.neonCyan;
    }
    if (planned != null && actual != null && actual.isBefore(planned)) {
      return AHSColors.stable;
    }
    return AHSColors.warning;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final List<Color> markers;
  final bool inTimeline;
  final bool selected;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.markers,
    required this.inTimeline,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMarker = markers.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected
              ? AHSColors.primary.withAlpha(20)
              : hasMarker
              ? AHSColors.primary.withAlpha(10)
              : inTimeline
              ? AHSColors.primaryGlow.withAlpha(36)
              : AHSColors.bgCardAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? AHSColors.primary
                : hasMarker
                ? AHSColors.primaryLight.withAlpha(90)
                : inTimeline
                ? AHSColors.primaryLight.withAlpha(55)
                : AHSColors.divider,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.toString(),
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected || hasMarker
                    ? AHSColors.textDark
                    : AHSColors.textSoft,
              ),
            ),
            const SizedBox(height: 2),
            if (inTimeline) ...[
              Container(
                width: 14,
                height: 2,
                decoration: BoxDecoration(
                  color: AHSColors.primaryLight.withAlpha(120),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 2),
            ],
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: markers
                    .map(
                      (color) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCalendarMonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _AnalyticsCalendarMonthNav({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AnalyticsCalendarNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AHSColors.primary,
            ),
          ),
        ),
        _AnalyticsCalendarNavButton(
          icon: Icons.chevron_right_rounded,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _AnalyticsCalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnalyticsCalendarNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AHSColors.bgCardAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AHSColors.border),
        ),
        child: Icon(icon, color: AHSColors.primary, size: 18),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AHSColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisChartFrame extends StatelessWidget {
  final String xLabel;
  final String yLabel;
  final Widget child;

  const _AxisChartFrame({
    required this.xLabel,
    required this.yLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    yLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AHSColors.textSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: child),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          xLabel,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AHSColors.textSoft,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final MetricStats? stats;
  final int decimals;

  const _MetricCard({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.stats,
    required this.decimals,
  });

  @override
  Widget build(BuildContext context) {
    final metric = stats;
    final latest = metric == null
        ? '--'
        : metric.latest.toStringAsFixed(decimals);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      unit.isEmpty ? 'Sensor reading' : unit,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricValue(label: 'Latest', value: latest, color: color),
              _MetricValue(
                label: 'Avg',
                value: metric == null
                    ? '--'
                    : metric.average.toStringAsFixed(decimals),
                color: AHSColors.textDark,
              ),
              _MetricValue(
                label: 'Min',
                value: metric == null
                    ? '--'
                    : metric.min.toStringAsFixed(decimals),
                color: AHSColors.textDark,
              ),
              _MetricValue(
                label: 'Max',
                value: metric == null
                    ? '--'
                    : metric.max.toStringAsFixed(decimals),
                color: AHSColors.textDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReadingsForDate extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onClear;

  const _NoReadingsForDate({required this.selectedDate, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final label = selectedDate == null
        ? 'No readings match this range'
        : 'No readings on ${DateFormat('MM-dd-yyyy').format(selectedDate!)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 34,
            color: AHSColors.textSoft,
          ),
          const SizedBox(height: 9),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AHSColors.textDark,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose another timeline date or clear the date filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: AHSColors.textSoft,
            ),
          ),
          if (selectedDate != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
              label: const Text('Clear date filter'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsEmpty extends StatelessWidget {
  final String plantName;

  const _AnalyticsEmpty({required this.plantName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📈', style: TextStyle(fontSize: 58)),
            const SizedBox(height: 18),
            const Text(
              'No analytics yet',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open Status for "$plantName" while sensor data is available. The app will save readings locally for analytics.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AHSColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
