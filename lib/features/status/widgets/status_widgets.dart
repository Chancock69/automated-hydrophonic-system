part of '../screen_status.dart';

class _Header extends StatelessWidget {
  final PlantModel plant;
  final bool alarmOn;
  final bool deviceOnline;
  final DateTime? lastSeen;
  final AnimationController alarmCtrl;
  final double batteryPercent;
  final VoidCallback? onBack;
  final VoidCallback onStopAlarm;
  final VoidCallback onBatteryTap;

  const _Header({
    required this.plant,
    required this.alarmOn,
    required this.deviceOnline,
    required this.lastSeen,
    required this.alarmCtrl,
    required this.batteryPercent,
    required this.onBack,
    required this.onStopAlarm,
    required this.onBatteryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AhsPageHeader(
            title: 'Live Status',
            subtitle: plant.name,
            onBack: onBack,
            action: Tooltip(
              message: 'Device battery',
              child: GestureDetector(
                onTap: onBatteryTap,
                child: _BatteryWidget(percent: batteryPercent, size: 'small'),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: deviceOnline
                  ? AHSColors.stableGlow
                  : AHSColors.warningGlow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (deviceOnline ? AHSColors.stable : AHSColors.warning)
                    .withAlpha(80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  deviceOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: deviceOnline ? AHSColors.stable : AHSColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    deviceOnline
                        ? 'ESP32 online - receiving live Firebase readings'
                        : lastSeen == null
                        ? 'ESP32 offline - waiting for Firebase readings'
                        : 'ESP32 offline - last online ${DateFormat('MMM d, HH:mm').format(lastSeen!)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: deviceOnline
                          ? AHSColors.stable
                          : AHSColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alarm banner
          if (alarmOn && deviceOnline)
            AnimatedBuilder(
              animation: alarmCtrl,
              builder: (_, _) {
                final p = alarmCtrl.value;
                return GestureDetector(
                  onTap: onStopAlarm,
                  child: Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AHSColors.critical.withAlpha(
                        ((0.08 + 0.08 * p) * 255).round(),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AHSColors.critical.withAlpha(
                          ((0.4 + 0.4 * p) * 255).round(),
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AHSColors.criticalGlow.withAlpha(
                            ((0.25 * p) * 255).round(),
                          ),
                          blurRadius: 20 * p,
                          spreadRadius: 4 * p,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AHSColors.critical,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚠️ Anomaly Detected!  Tap to stop alarm.',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AHSColors.critical,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Temp & Humidity Neon Line Chart
// ─────────────────────────────────────────────
class _TempHumidChart extends StatelessWidget {
  final List<SensorSnapshot> history;
  final bool compact;
  const _TempHumidChart({required this.history, this.compact = false});

  List<FlSpot> _spots(double Function(SensorSnapshot) fn) => history
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), fn(e.value)))
      .toList();

  @override
  Widget build(BuildContext context) {
    final Widget chart = history.isEmpty
        ? const Center(
            child: Text(
              'Waiting for data...',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AHSColors.textHint,
                fontSize: 13,
              ),
            ),
          )
        : LineChart(_chartData());

    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 12 : 18, 16, 10),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AHSColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Temperature & Humidity',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              _ChartLegend(color: AHSColors.neonCyan, label: 'Temp °C'),
              const SizedBox(width: 14),
              _ChartLegend(color: AHSColors.neonGreen, label: 'Humid %'),
            ],
          ),
          SizedBox(height: compact ? 8 : 18),

          if (compact)
            Expanded(child: chart)
          else
            SizedBox(height: 195, child: chart),
        ],
      ),
    );
  }

  LineChartData _chartData() {
    final count = history.length.toDouble();

    return LineChartData(
      minY: 0,
      maxY: 100,
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
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Value',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: AHSColors.textSoft,
              ),
            ),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
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

        bottomTitles: AxisTitles(
          axisNameWidget: const Text(
            'Time',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: AHSColors.textSoft,
            ),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: max(1, (count / 4).floorToDouble()),
            getTitlesWidget: (v, _) {
              final i = v.toInt().clamp(0, history.length - 1);
              return Text(
                DateFormat('HH:mm').format(history[i].timestamp),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 9,
                  color: AHSColors.textSoft,
                ),
              );
            },
          ),
        ),
      ),

      lineBarsData: [
        // Temperature — cyan neon
        LineChartBarData(
          spots: _spots((s) => s.temperature),
          isCurved: true,
          preventCurveOverShooting: true,
          color: AHSColors.neonCyan,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AHSColors.neonCyan.withAlpha(46),
                AHSColors.neonCyan.withAlpha(0),
              ],
            ),
          ),
        ),
        // Humidity — green neon
        LineChartBarData(
          spots: _spots((s) => s.humidity),
          isCurved: true,
          preventCurveOverShooting: true,
          color: AHSColors.neonGreen,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AHSColors.neonGreen.withAlpha(36),
                AHSColors.neonGreen.withAlpha(0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
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

// ─────────────────────────────────────────────
//  Sensor Panel  (compact card)
// ─────────────────────────────────────────────
class _SensorPanel extends StatefulWidget {
  final String emoji;
  final IconData icon;
  final String label;
  final String display;
  final String unit;
  final double min, max;
  final bool isCritical;
  final String? note;

  const _SensorPanel({
    required this.emoji,
    required this.icon,
    required this.label,
    required this.display,
    required this.unit,
    required this.min,
    required this.max,
    required this.isCritical,
    this.note,
  });

  @override
  State<_SensorPanel> createState() => _SensorPanelState();
}

class _SensorPanelState extends State<_SensorPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: 1400.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Color get _statusC =>
      widget.isCritical ? AHSColors.critical : AHSColors.stable;
  Color get _glowC =>
      widget.isCritical ? AHSColors.criticalGlow : AHSColors.stableGlow;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (_, _) {
      final g = Curves.easeInOut.transform(_glow.value);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AHSColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _statusC.withAlpha(((0.24 + 0.28 * g) * 255).round()),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _glowC.withAlpha(((0.14 * g) * 255).round()),
              blurRadius: 16 * g,
              spreadRadius: 2 * g,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusC.withAlpha(22),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon, color: _statusC, size: 20),
            ),
            const SizedBox(width: 12),
            // Value + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.display,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AHSColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AHSColors.textMid,
                    ),
                  ),
                  Text(
                    widget.note ??
                        'Safe range: ${widget.min}–${widget.max} ${widget.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      color: AHSColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusC.withAlpha(22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusC,
                      boxShadow: [
                        BoxShadow(
                          color: _statusC.withAlpha(((0.8 * g) * 255).round()),
                          blurRadius: 6 * g,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isCritical ? 'CRIT' : 'OK',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _statusC,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
//  Last-update timestamp panel
// ─────────────────────────────────────────────
class _TimestampPanel extends StatelessWidget {
  final DateTime ts;
  final bool online;
  const _TimestampPanel({required this.ts, required this.online});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: online
            ? const [AHSColors.primary, AHSColors.primaryMid]
            : const [AHSColors.warning, Color(0xFFD97706)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AHSColors.primary.withAlpha(89),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.update_rounded, color: Colors.white60, size: 26),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('HH:mm:ss').format(ts),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              DateFormat('MMM d, y').format(ts),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              online ? 'LIVE UPDATE' : 'LAST ONLINE',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 9,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
//  Floating Logs FAB
// ─────────────────────────────────────────────
class _LogsFAB extends StatefulWidget {
  final PlantModel plant;
  const _LogsFAB({required this.plant});
  @override
  State<_LogsFAB> createState() => _LogsFABState();
}

class _LogsFABState extends State<_LogsFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: 2200.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final g = Curves.easeInOut.transform(_c.value);
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LogsScreen(plant: widget.plant)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AHSColors.primary, AHSColors.primaryMid],
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: AHSColors.primary.withAlpha(
                  ((0.28 + 0.22 * g) * 255).round(),
                ),
                blurRadius: 18 + 12 * g,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Logs',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
//  Misc helpers
// ─────────────────────────────────────────────
class _NoData extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('📡', style: TextStyle(fontSize: 58)),
          SizedBox(height: 18),
          Text(
            'No sensor data found',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AHSColors.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Make sure the ESP32 is powered on\nand connected to Wi-Fi.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _RefreshDot extends StatefulWidget {
  final bool active;

  const _RefreshDot({this.active = true});

  @override
  State<_RefreshDot> createState() => _RefreshDotState();
}

class _RefreshDotState extends State<_RefreshDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: 1000.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final color = widget.active ? AHSColors.stable : AHSColors.warning;
      final glow = widget.active ? AHSColors.stableGlow : AHSColors.warningGlow;
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: glow.withAlpha(((0.8 * _c.value) * 255).round()),
              blurRadius: widget.active ? 8 * _c.value : 0,
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
//  Battery Widget
//  Draws a classic battery icon filled proportionally.
//  size: 'small' = compact header use, 'large' = settings dialog
// ─────────────────────────────────────────────
class _BatteryWidget extends StatelessWidget {
  final double percent; // 0..100
  final String size; // 'small' | 'large'

  const _BatteryWidget({required this.percent, this.size = 'small'});

  Color get _fillColor {
    if (percent > 50) return AHSColors.stable;
    if (percent > 20) return AHSColors.warning;
    return AHSColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = size == 'small';
    final w = isSmall ? 28.0 : 52.0;
    final h = isSmall ? 14.0 : 26.0;
    final capW = isSmall ? 3.0 : 5.0;
    final capH = isSmall ? 6.0 : 11.0;
    final radius = isSmall ? 3.0 : 5.0;
    final border = isSmall ? 1.5 : 2.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Body
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _fillColor, width: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - border),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  color: _fillColor.withAlpha(200),
                ),
              ),
            ),
          ),
        ),
        // Cap (positive terminal nub)
        Container(
          width: capW,
          height: capH,
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(radius / 2),
              bottomRight: Radius.circular(radius / 2),
            ),
          ),
        ),
      ],
    );
  }
}
