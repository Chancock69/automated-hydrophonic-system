import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/app_notification.dart';
import 'package:ahs/data/models/plant_health.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:ahs/data/models/sensor_thresholds.dart';
import 'package:ahs/data/remote/firebase_http.dart';
import 'package:ahs/features/logs/screen_logs.dart';
import 'package:ahs/services/notification_service.dart';
import 'package:ahs/shared/widgets/app_ui.dart';

part 'widgets/status_widgets.dart';

// ─────────────────────────────────────────────
//  Status Screen
// ─────────────────────────────────────────────
class StatusScreen extends StatefulWidget {
  final PlantModel plant;
  final bool embedded;

  const StatusScreen({super.key, required this.plant, this.embedded = false});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  // data
  SensorSnapshot? _latest;
  final List<SensorSnapshot> _history = [];
  static const int _maxHistory = 24;
  static const Duration _onlineFreshness = Duration(minutes: 2);
  static const Duration _connectionGrace = Duration(seconds: 45);

  // state
  bool _loading = true;
  bool _hasError = false;
  bool _deviceOnline = false;
  bool _alarmOn = false;
  bool _fetching = false;
  bool _soundAlerts = true;
  String? _lastAlertSource;
  String? _lastReminderSource;
  DateTime? _lastSuccessfulFetchAt;
  int _consecutiveFetchFailures = 0;

  // battery
  double _batteryPercent = 100.0;
  Timer? _batteryTimer;

  // timer & audio
  Timer? _timer;
  final AudioPlayer _audio = AudioPlayer();

  // alarm pulse animation
  late final AnimationController _alarmCtrl;

  @override
  void initState() {
    super.initState();
    _alarmCtrl = AnimationController(vsync: this, duration: 700.ms)
      ..repeat(reverse: true);
    _alarmCtrl.stop();

    unawaited(_initializeMonitoring());

    _loadBattery();
    // Refresh battery every 60 seconds
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadBattery(),
    );
  }

  Future<void> _initializeMonitoring() async {
    try {
      final soundValue = await DatabaseHelper.instance.getAppSetting(
        'soundAlerts',
      );
      _soundAlerts = soundValue != 'false';
    } catch (_) {
      _soundAlerts = true;
    }
    if (!mounted) return;
    await _fetchNow();
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batteryTimer?.cancel();
    _alarmCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── battery ───────────────────────────────
  Future<void> _loadBattery() async {
    try {
      final pct = await DatabaseHelper.instance.getBatteryPercent();
      if (mounted) setState(() => _batteryPercent = pct);
    } catch (_) {
      if (mounted) setState(() => _batteryPercent = 100.0);
    }
  }

  Future<void> _showBatterySettings() async {
    final lastCharge = await DatabaseHelper.instance.getLastFullCharge();
    if (!mounted) return;
    final elapsed = DateTime.now().difference(lastCharge);
    final hh = elapsed.inHours;
    final mm = elapsed.inMinutes % 60;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Device Battery',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BatteryWidget(percent: _batteryPercent, size: 'large'),
            const SizedBox(height: 16),
            Text(
              'Last charged: $hh h $mm min ago',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AHSColors.textMid,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stored device battery estimate',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AHSColors.textSoft,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _batteryPercent < 20
                      ? Icons.warning_amber_rounded
                      : _batteryPercent >= 100
                      ? Icons.check_circle_outline_rounded
                      : Icons.battery_std_rounded,
                  size: 18,
                  color: _batteryPercent < 20
                      ? AHSColors.critical
                      : AHSColors.stable,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _batteryPercent < 20
                        ? 'Low battery. Charge the device soon.'
                        : _batteryPercent >= 100
                        ? 'Fully charged'
                        : 'Running on battery',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _batteryPercent < 20
                          ? AHSColors.critical
                          : AHSColors.stable,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.battery_charging_full_rounded, size: 16),
            label: const Text('Mark as Charged'),
            onPressed: () async {
              await DatabaseHelper.instance.resetBattery();
              await _loadBattery();
              if (mounted && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── fetch ─────────────────────────────────
  Future<void> _fetchNow() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final snap = await FirebaseHttp.instance.fetchLatest();
      if (!mounted) return;

      if (snap == null) {
        _consecutiveFetchFailures++;
        final keepShowingLastReading = _latest != null;
        final keepOnlineDuringDelay =
            keepShowingLastReading && _connectionStillRecoverable();
        setState(() {
          _loading = false;
          _hasError = !keepShowingLastReading;
          _deviceOnline = keepOnlineDuringDelay;
        });
        if (!keepOnlineDuringDelay) _stopAlarm();
        return;
      }

      _lastSuccessfulFetchAt = DateTime.now();
      final latestPath =
          '/${snap.timestamp.year}/${snap.timestamp.month.toString().padLeft(2, '0')}/${snap.timestamp.day.toString().padLeft(2, '0')}';
      await DatabaseHelper.instance.saveFirebaseSync(
        syncedAt: _lastSuccessfulFetchAt!,
        path: latestPath,
        online: _isFresh(snap),
      );
      _consecutiveFetchFailures = 0;
      final online = _isFresh(snap);
      final isNewReading = _latest?.timestamp != snap.timestamp;
      final stateChanged =
          _loading || _hasError || _deviceOnline != online || isNewReading;

      if (stateChanged) {
        setState(() {
          _latest = snap;
          _loading = false;
          _hasError = false;
          _deviceOnline = online;
          if (isNewReading) {
            _history.add(snap);
            if (_history.length > _maxHistory) _history.removeAt(0);
          }
        });
      }

      if (!online) {
        if (isNewReading || _alarmOn) {
          _stopAlarm();
        }
        return;
      }

      PlantModel? activePlant;
      try {
        activePlant = await DatabaseHelper.instance.getActivePlant();
        if (activePlant != null && isNewReading) {
          await DatabaseHelper.instance.insertLog(
            snap,
            plantId: activePlant.id,
            plantName: activePlant.name,
          );
        }
      } catch (_) {}

      final plant = activePlant ?? widget.plant;
      final ranges = SensorThresholds.forPlant(plant);
      final hasAnomaly =
          !ranges.temperature.contains(snap.temperature) ||
          !ranges.humidity.contains(snap.humidity) ||
          !ranges.ph.contains(snap.ph) ||
          !ranges.tds.contains(snap.tds) ||
          SensorThresholds.isWaterCritical(snap.waterLevel);
      if (hasAnomaly && isNewReading) {
        await _recordAlert(plant, snap);
        if (mounted && !_alarmOn) _startAlarm();
      }
      await _recordSmartReminders(plant, snap);
    } finally {
      _fetching = false;
    }
  }

  bool _isFresh(SensorSnapshot snapshot) {
    final now = DateTime.now();
    final age = now.difference(snapshot.timestamp);
    return !age.isNegative && age <= _onlineFreshness;
  }

  bool _connectionStillRecoverable() {
    final latest = _latest;
    final lastSuccess = _lastSuccessfulFetchAt;
    if (latest == null || lastSuccess == null) return false;
    final now = DateTime.now();
    final readingAge = now.difference(latest.timestamp);
    final connectionAge = now.difference(lastSuccess);
    return _consecutiveFetchFailures <= 3 &&
        !readingAge.isNegative &&
        readingAge <= _onlineFreshness + _connectionGrace &&
        connectionAge <= _connectionGrace;
  }

  Future<void> _recordAlert(PlantModel plant, SensorSnapshot snapshot) async {
    final source = snapshot.timestamp.toIso8601String();
    if (_lastAlertSource == source) return;
    _lastAlertSource = source;

    final ranges = SensorThresholds.forPlant(plant);
    final issues = <String>[
      if (!ranges.temperature.contains(snapshot.temperature))
        'temperature ${snapshot.temperature.toStringAsFixed(1)} C',
      if (!ranges.humidity.contains(snapshot.humidity))
        'humidity ${snapshot.humidity.toStringAsFixed(0)}%',
      if (!ranges.ph.contains(snapshot.ph))
        'pH ${snapshot.ph.toStringAsFixed(2)}',
      if (!ranges.tds.contains(snapshot.tds))
        'TDS ${snapshot.tds.toStringAsFixed(0)} ppm',
      if (SensorThresholds.isWaterCritical(snapshot.waterLevel))
        'water distance ${snapshot.waterLevel.toStringAsFixed(1)} cm',
    ];
    if (issues.isEmpty) return;

    final title = 'Sensor alert: ${plant.name}';
    final message = 'Out of range: ${issues.join(', ')}.';
    try {
      final id = await DatabaseHelper.instance.insertNotification(
        AppNotification(
          plantId: plant.id,
          title: title,
          message: message,
          type: 'sensor',
          createdAt: DateTime.now(),
          sourceTimestamp: source,
        ),
      );
      final enabled = await DatabaseHelper.instance.getAppSetting(
        'systemNotifications',
      );
      if (id != null && enabled != 'false') {
        await NotificationService.instance.showSensorAlert(
          id: id,
          title: title,
          body: message,
        );
      }
    } catch (_) {
      // Monitoring must continue even when notification delivery fails.
    }
  }

  Future<void> _recordSmartReminders(
    PlantModel plant,
    SensorSnapshot snapshot,
  ) async {
    final now = DateTime.now();
    final source = '${plant.id}-${DateTime(now.year, now.month, now.day)}';
    if (_lastReminderSource == source) return;

    final reminders = <({String title, String body, String type})>[];
    final lastNutrient = plant.lastNutrientAt ?? plant.addedDate;
    if (now.difference(lastNutrient).inDays >= 7) {
      reminders.add((
        title: 'Nutrient reminder: ${plant.name}',
        body: 'Add nutrient solution or review TDS for ${plant.name}.',
        type: 'nutrient',
      ));
    }
    final lastWater = plant.lastWaterChangeAt ?? plant.addedDate;
    if (now.difference(lastWater).inDays >= 14) {
      reminders.add((
        title: 'Water change reminder: ${plant.name}',
        body: 'Change the tank water or inspect water quality.',
        type: 'water_change',
      ));
    }
    final harvest = plant.harvestDate;
    if (harvest != null && !plant.isHarvested) {
      final days = DateUtils.dateOnly(
        harvest,
      ).difference(DateUtils.dateOnly(now)).inDays;
      if (days >= 0 && days <= 3) {
        reminders.add((
          title: 'Harvest soon: ${plant.name}',
          body: days == 0
              ? 'Planned harvest is today.'
              : 'Planned harvest is in $days day${days == 1 ? '' : 's'}.',
          type: 'harvest',
        ));
      }
    }
    if (_batteryPercent < 20) {
      reminders.add((
        title: 'Low battery',
        body: 'Device battery is ${_batteryPercent.round()}%. Charge soon.',
        type: 'battery',
      ));
    }

    for (final reminder in reminders) {
      final id = await DatabaseHelper.instance.insertNotification(
        AppNotification(
          plantId: plant.id,
          title: reminder.title,
          message: reminder.body,
          type: reminder.type,
          createdAt: now,
          sourceTimestamp: '${reminder.type}-$source',
        ),
      );
      final enabled = await DatabaseHelper.instance.getAppSetting(
        'systemNotifications',
      );
      if (id != null && enabled != 'false') {
        await NotificationService.instance.showReminder(
          id: id,
          title: reminder.title,
          body: reminder.body,
        );
      }
    }
    _lastReminderSource = source;
  }

  void _startAlarm() {
    _alarmOn = true;
    _alarmCtrl.repeat(reverse: true);
    if (_soundAlerts) {
      _audio.play(AssetSource('alarmsound.mp3')).catchError((_) {});
      _audio.onPlayerComplete.first.then((_) => _stopAlarm());
    }
  }

  void _stopAlarm() {
    if (!mounted) return;
    setState(() => _alarmOn = false);
    _alarmCtrl.stop();
    _alarmCtrl.reset();
    _audio.stop();
  }

  // ── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildEmbedded(context);

    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: _Header(
                    plant: widget.plant,
                    alarmOn: _alarmOn,
                    deviceOnline: _deviceOnline,
                    lastSeen: _latest?.timestamp,
                    alarmCtrl: _alarmCtrl,
                    batteryPercent: _batteryPercent,
                    onBack: widget.embedded
                        ? null
                        : () => Navigator.pop(context),
                    onStopAlarm: _stopAlarm,
                    onBatteryTap: _showBatterySettings,
                  ),
                ),

                if (_loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_hasError || _latest == null)
                  SliverFillRemaining(child: _NoData())
                else ...[
                  // ── Temp & Humidity chart ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _TempHumidChart(
                        history: _history,
                        plant: widget.plant,
                      ),
                    ),
                  ),

                  // ── Live sensor label ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            _deviceOnline ? 'Live Sensors' : 'Last Readings',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AHSColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _RefreshDot(active: _deviceOnline),
                        ],
                      ),
                    ),
                  ),

                  // ── Sensor panels compact list ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _SensorPanel(
                          emoji: '🌡',
                          icon: Icons.thermostat_rounded,
                          label: 'Temp',
                          display:
                              '${_latest!.temperature.toStringAsFixed(1)} C',
                          unit: 'C',
                          min: SensorThresholds.tempMin,
                          max: SensorThresholds.tempMax,
                          isCritical:
                              _deviceOnline &&
                              SensorThresholds.isTempCritical(
                                _latest!.temperature,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _SensorPanel(
                          emoji: '💦',
                          icon: Icons.water_drop_outlined,
                          label: 'Humidity',
                          display: '${_latest!.humidity.toStringAsFixed(0)}%',
                          unit: '%',
                          min: SensorThresholds.humidMin,
                          max: SensorThresholds.humidMax,
                          isCritical:
                              _deviceOnline &&
                              SensorThresholds.isHumidCritical(
                                _latest!.humidity,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _SensorPanel(
                          emoji: '🧪',
                          icon: Icons.science_outlined,
                          label: 'pH Level',
                          display: _latest!.ph.toStringAsFixed(2),
                          unit: 'pH',
                          min: SensorThresholds.phMin,
                          max: SensorThresholds.phMax,
                          isCritical:
                              _deviceOnline &&
                              SensorThresholds.isPhCritical(_latest!.ph),
                        ),
                        const SizedBox(height: 8),
                        _SensorPanel(
                          emoji: '💧',
                          icon: Icons.bubble_chart_outlined,
                          label: 'TDS',
                          display: _latest!.tds.toStringAsFixed(0),
                          unit: 'ppm',
                          min: SensorThresholds.tdsMin,
                          max: SensorThresholds.tdsMax,
                          isCritical:
                              _deviceOnline &&
                              SensorThresholds.isTdsCritical(_latest!.tds),
                        ),
                        const SizedBox(height: 8),
                        _SensorPanel(
                          emoji: '🌊',
                          icon: Icons.waves_outlined,
                          label: 'Water Level',
                          display:
                              '${_latest!.waterLevel.toStringAsFixed(1)} cm',
                          unit: 'distance',
                          min: 0,
                          max: SensorThresholds.waterLevelCritical,
                          isCritical:
                              _deviceOnline &&
                              SensorThresholds.isWaterCritical(
                                _latest!.waterLevel,
                              ),
                          note:
                              '> ${SensorThresholds.waterLevelCritical.toInt()} cm = low water',
                        ),
                        const SizedBox(height: 8),
                        _TimestampPanel(
                          ts: _latest!.timestamp,
                          online: _deviceOnline,
                        ),
                        const SizedBox(height: 12),
                      ]),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // ── Floating Logs button ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            right: 20,
            child: _LogsFAB(plant: widget.plant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbedded(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_hasError || _latest == null) {
      return _NoData();
    }

    final snapshot = _latest!;
    final ranges = SensorThresholds.forPlant(widget.plant);
    final health = PlantHealth.from(plant: widget.plant, latest: snapshot);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = (constraints.maxHeight * 0.46).clamp(
            205.0,
            285.0,
          );
          return Column(
            children: [
              AhsPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                borderColor: _alarmOn
                    ? AHSColors.critical.withAlpha(100)
                    : null,
                child: Row(
                  children: [
                    Icon(
                      _alarmOn
                          ? Icons.warning_amber_rounded
                          : Icons.sensors_rounded,
                      color: _alarmOn ? AHSColors.critical : AHSColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _deviceOnline
                                ? 'Live check every 10 seconds'
                                : 'Device offline - showing last reading',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _RefreshDot(active: _deviceOnline),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Sensor logs',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LogsScreen(plant: widget.plant),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _HealthRecommendationPanel(health: health),
              const SizedBox(height: 10),
              SizedBox(
                height: chartHeight,
                child: _TempHumidChart(
                  history: _history,
                  plant: widget.plant,
                  compact: true,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: [
                    _LiveMetricTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Temp',
                      value: '${snapshot.temperature.toStringAsFixed(1)} C',
                      critical:
                          _deviceOnline &&
                          !ranges.temperature.contains(snapshot.temperature),
                    ),
                    _LiveMetricTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Humidity',
                      value: '${snapshot.humidity.toStringAsFixed(0)}%',
                      critical:
                          _deviceOnline &&
                          !ranges.humidity.contains(snapshot.humidity),
                    ),
                    _LiveMetricTile(
                      icon: Icons.science_outlined,
                      label: 'pH',
                      value: snapshot.ph.toStringAsFixed(2),
                      critical:
                          _deviceOnline && !ranges.ph.contains(snapshot.ph),
                    ),
                    _LiveMetricTile(
                      icon: Icons.bubble_chart_outlined,
                      label: 'TDS',
                      value: '${snapshot.tds.toStringAsFixed(0)} ppm',
                      critical:
                          _deviceOnline && !ranges.tds.contains(snapshot.tds),
                    ),
                    _LiveMetricTile(
                      icon: Icons.waves_outlined,
                      label: 'Water',
                      value: '${snapshot.waterLevel.toStringAsFixed(1)} cm',
                      critical:
                          _deviceOnline &&
                          SensorThresholds.isWaterCritical(snapshot.waterLevel),
                    ),
                    _LiveMetricTile(
                      icon: Icons.schedule_rounded,
                      label: _deviceOnline ? 'Last check' : 'Last online',
                      value: DateFormat('HH:mm:ss').format(snapshot.timestamp),
                      critical: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool critical;

  const _LiveMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    final color = critical ? AHSColors.critical : AHSColors.primary;
    return AhsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: critical ? AHSColors.criticalGlow : AHSColors.bgCard,
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRecommendationPanel extends StatelessWidget {
  final PlantHealth health;

  const _HealthRecommendationPanel({required this.health});

  @override
  Widget build(BuildContext context) {
    final color = health.score >= 85
        ? AHSColors.stable
        : health.score >= 65
        ? AHSColors.warning
        : AHSColors.critical;
    return AhsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${health.score}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant health - ${health.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  health.recommendations.join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────
