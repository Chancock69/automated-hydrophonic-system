part of '../screen_logs.dart';

class _LogDatePickerPanel extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onPick;

  const _LogDatePickerPanel({required this.selectedDate, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final label = selectedDate == null
        ? 'Select log date'
        : DateFormat('MM-dd-yyyy').format(selectedDate!);
    return AhsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AHSColors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: AHSColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sensor log date',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: const Text('Pick date'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Log table
// ─────────────────────────────────────────────
class _LogInfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LogInfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LogTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _LogTable({required this.rows});

  Color _tc(dynamic v, bool Function(double) crit) {
    if (v == null) return AHSColors.textHint;
    final value = v is num ? v.toDouble() : double.tryParse(v.toString());
    if (value == null) return AHSColors.textHint;
    return crit(value) ? AHSColors.critical : AHSColors.stable;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LogTrendChart(rows: rows),
        const SizedBox(height: 12),
        // ── Sticky header ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AHSColors.primary, AHSColors.primaryMid],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(
            children: const [
              _HC(label: 'Time', flex: 3),
              _HC(label: 'Tmp°', flex: 2),
              _HC(label: 'Hum%', flex: 2),
              _HC(label: 'pH', flex: 2),
              _HC(label: 'TDS', flex: 2),
              _HC(label: 'H₂O', flex: 2),
            ],
          ),
        ),

        // ── Rows ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: AHSColors.bgCard,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              border: Border.all(color: AHSColors.border, width: 1.5),
            ),
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AHSColors.divider),
              itemBuilder: (_, i) {
                final r = rows[i];
                final ts = DateTime.tryParse(r['timestamp'] as String? ?? '');
                final tmp = r['temperature'];
                final hum = r['humidity'];
                final phRaw = r['ph'];
                final phValue = phRaw is num
                    ? phRaw.toDouble()
                    : double.tryParse(phRaw?.toString() ?? '');
                final ph = phValue == null
                    ? null
                    : SensorSnapshot.normalizePh(phValue);
                final tds = r['tds'];
                final wl = r['waterLevel'];

                return Container(
                  color: i.isEven ? Colors.white : AHSColors.bgCardAlt,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _DC(
                        flex: 3,
                        color: AHSColors.textDark,
                        text: ts != null ? DateFormat('HH:mm').format(ts) : '–',
                      ),
                      _DC(
                        flex: 2,
                        text: tmp != null
                            ? '${(tmp as num).toStringAsFixed(1)}°'
                            : '–',
                        color: _tc(tmp, SensorThresholds.isTempCritical),
                      ),
                      _DC(
                        flex: 2,
                        text: hum != null
                            ? '${(hum as num).toStringAsFixed(0)}%'
                            : '–',
                        color: _tc(hum, SensorThresholds.isHumidCritical),
                      ),
                      _DC(
                        flex: 2,
                        text: ph != null ? (ph as num).toStringAsFixed(2) : '–',
                        color: _tc(ph, SensorThresholds.isPhCritical),
                      ),
                      _DC(
                        flex: 2,
                        text: tds != null
                            ? (tds as num).toStringAsFixed(0)
                            : '–',
                        color: _tc(tds, SensorThresholds.isTdsCritical),
                      ),
                      _DC(
                        flex: 2,
                        text: wl != null ? (wl as num).toStringAsFixed(1) : '–',
                        color: _tc(wl, SensorThresholds.isWaterCritical),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── table header cell ─────────────────────────
class _LogTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _LogTrendChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final chartRows = rows.length > 48 ? rows.sublist(rows.length - 48) : rows;
    return Container(
      height: 238,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Daily Sensor Graph',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _GraphLegend(color: AHSColors.neonCyan, label: 'Temp'),
                  _GraphLegend(color: AHSColors.neonGreen, label: 'Hum'),
                  _GraphLegend(color: AHSColors.warning, label: 'pH x10'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(child: LineChart(_chartData(chartRows))),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(List<Map<String, dynamic>> data) {
    return LineChartData(
      minY: 0,
      maxY: 100,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
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
            reservedSize: 34,
            interval: 25,
            getTitlesWidget: (value, _) => Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9,
                color: AHSColors.textSoft,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: data.length <= 1 ? 1 : (data.length - 1) / 2,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              if (index != 0 &&
                  index != data.length ~/ 2 &&
                  index != data.length - 1) {
                return const SizedBox.shrink();
              }
              final ts = DateTime.tryParse(
                data[index]['timestamp']?.toString() ?? '',
              );
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  ts == null ? '' : DateFormat('HH:mm').format(ts),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 9,
                    color: AHSColors.textSoft,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        _line(data, 'temperature', AHSColors.neonCyan),
        _line(data, 'humidity', AHSColors.neonGreen),
        _line(data, 'ph', AHSColors.warning, scale: 10),
      ],
    );
  }

  LineChartBarData _line(
    List<Map<String, dynamic>> data,
    String key,
    Color color, {
    double scale = 1,
  }) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        final raw = _num(entry.value[key]) ?? 0;
        final value = key == 'ph' ? SensorSnapshot.normalizePh(raw) : raw;
        return FlSpot(entry.key.toDouble(), value * scale);
      }).toList(),
      isCurved: false,
      color: color,
      barWidth: 2.4,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double? _num(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _GraphLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _GraphLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            color: AHSColors.textSoft,
          ),
        ),
      ],
    );
  }
}

class _HC extends StatelessWidget {
  final String label;
  final int flex;
  const _HC({required this.label, required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ── table data cell ───────────────────────────
class _DC extends StatelessWidget {
  final String text;
  final Color color;
  final int flex;
  const _DC({required this.text, required this.color, required this.flex});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

// ── empty states ──────────────────────────────
class _MetaEmpty extends StatelessWidget {
  const _MetaEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'No local or Firebase log dates found.\nOpen Status while readings are available to save real sensor logs.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: AHSColors.textSoft,
        ),
      ),
    ),
  );
}

class _EmptyRows extends StatelessWidget {
  final bool hasSelection;
  final String plantName;
  const _EmptyRows({required this.hasSelection, required this.plantName});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📋', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 16),
          Text(
            hasSelection ? 'No logs for this date' : 'Select a date above',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AHSColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSelection
                ? 'No SQLite rows for "$plantName" on this date, and Firebase fallback did not return records.'
                : 'Choose year, month, and day to view sensor history.',
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

class _LogLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LogLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AHSColors.textSoft,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AHSColors.textMid,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PDF row data holder ───────────────────────
class _PdfRow {
  final String time, temp, humid, ph, tds, water;
  final bool tmpBad, humBad, phBad, tdsBad, wlBad;
  const _PdfRow({
    required this.time,
    required this.temp,
    required this.humid,
    required this.ph,
    required this.tds,
    required this.water,
    required this.tmpBad,
    required this.humBad,
    required this.phBad,
    required this.tdsBad,
    required this.wlBad,
  });

  bool get hasAnomaly => tmpBad || humBad || phBad || tdsBad || wlBad;
}
