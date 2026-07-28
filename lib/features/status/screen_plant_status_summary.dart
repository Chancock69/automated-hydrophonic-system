import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/analytics_summary.dart';
import 'package:ahs/data/models/harvest_event.dart';
import 'package:ahs/data/models/plant_health.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/plant_preset.dart';
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:ahs/data/models/sensor_thresholds.dart';
import 'package:ahs/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlantStatusSummaryScreen extends StatefulWidget {
  final PlantModel plant;

  const PlantStatusSummaryScreen({super.key, required this.plant});

  @override
  State<PlantStatusSummaryScreen> createState() =>
      _PlantStatusSummaryScreenState();
}

class _PlantStatusSummaryScreenState extends State<PlantStatusSummaryScreen> {
  late Future<_PlantStatusSummaryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlantStatusSummaryData> _load() async {
    final plantId = widget.plant.id;
    if (plantId == null) {
      return _PlantStatusSummaryData.empty(widget.plant);
    }
    final plant =
        await DatabaseHelper.instance.getPlantById(plantId) ?? widget.plant;
    final rows = await DatabaseHelper.instance.getLogsForPlant(
      plantId,
      limit: 120,
    );
    final latestRow = await DatabaseHelper.instance.getLatestLogForPlant(
      plantId,
    );
    final harvests = await DatabaseHelper.instance.getHarvestEvents(
      plantId: plantId,
    );
    final alive = await DatabaseHelper.instance.getAliveSlotCount(plantId);
    final summary = AnalyticsSummary.fromRows(rows);
    final latest = latestRow == null ? null : _snapshotFromRow(latestRow);
    final health = PlantHealth.from(
      plant: plant,
      latest: latest,
      summary: summary,
      aliveCount: alive,
    );
    return _PlantStatusSummaryData(
      plant: plant,
      latest: latest,
      summary: summary,
      harvests: harvests,
      aliveCount: alive,
      health: health,
    );
  }

  SensorSnapshot? _snapshotFromRow(Map<String, dynamic> row) {
    final ts = DateTime.tryParse(row['timestamp']?.toString() ?? '');
    if (ts == null) return null;
    double value(String key) {
      final raw = row[key];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return SensorSnapshot(
      temperature: value('temperature'),
      humidity: value('humidity'),
      ph: SensorSnapshot.normalizePh(value('ph')),
      tds: value('tds'),
      waterLevel: value('waterLevel'),
      timestamp: ts,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markNutrients() async {
    final id = widget.plant.id;
    if (id == null) return;
    await DatabaseHelper.instance.markNutrientAdded(id);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nutrient reminder marked done.')),
    );
  }

  Future<void> _markWaterChanged() async {
    final id = widget.plant.id;
    if (id == null) return;
    await DatabaseHelper.instance.markWaterChanged(id);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Water change reminder marked done.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: FutureBuilder<_PlantStatusSummaryData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return RefreshIndicator(
              color: AHSColors.primary,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: AhsPageHeader(
                        title: 'Plant Status',
                        subtitle: widget.plant.name,
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (data == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Unable to load status.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.list(
                        children: [
                          _HealthCard(data: data),
                          const SizedBox(height: 12),
                          _RecommendationCard(health: data.health),
                          const SizedBox(height: 12),
                          _LatestReadingCard(data: data),
                          const SizedBox(height: 12),
                          _PresetRangeCard(plant: data.plant),
                          const SizedBox(height: 12),
                          _ReminderCard(
                            plant: data.plant,
                            onNutrients: _markNutrients,
                            onWaterChanged: _markWaterChanged,
                          ),
                          const SizedBox(height: 12),
                          _TimelineCard(data: data),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlantStatusSummaryData {
  final PlantModel plant;
  final SensorSnapshot? latest;
  final AnalyticsSummary summary;
  final List<HarvestEvent> harvests;
  final int aliveCount;
  final PlantHealth health;

  const _PlantStatusSummaryData({
    required this.plant,
    required this.latest,
    required this.summary,
    required this.harvests,
    required this.aliveCount,
    required this.health,
  });

  factory _PlantStatusSummaryData.empty(PlantModel plant) {
    final summary = AnalyticsSummary.fromRows(const []);
    return _PlantStatusSummaryData(
      plant: plant,
      latest: null,
      summary: summary,
      harvests: const [],
      aliveCount: plant.quantity,
      health: PlantHealth.from(plant: plant, summary: summary),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final _PlantStatusSummaryData data;

  const _HealthCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final score = data.health.score;
    final color = score >= 85
        ? AHSColors.stable
        : score >= 65
        ? AHSColors.warning
        : AHSColors.critical;
    final lifeRate = data.plant.quantity == 0
        ? 0.0
        : (data.aliveCount / data.plant.quantity.clamp(1, 6)) * 100;
    return AhsPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.health.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Based on latest readings, survival, and ${data.summary.anomalyCount} anomalies',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatusStat(
                  label: 'Survival',
                  value: '${lifeRate.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatusStat(
                  label: 'Readings',
                  value: '${data.summary.totalRecords}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatusStat(
                  label: 'Preset',
                  value: PlantPreset.byKey(data.plant.presetKey).label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final PlantHealth health;

  const _RecommendationCard({required this.health});

  @override
  Widget build(BuildContext context) {
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AHSColors.primary),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: health.recommendations
                .map(
                  (item) => Chip(
                    label: Text(item),
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    backgroundColor: AHSColors.primaryGlow,
                    side: const BorderSide(color: AHSColors.border),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LatestReadingCard extends StatelessWidget {
  final _PlantStatusSummaryData data;

  const _LatestReadingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final latest = data.latest;
    if (latest == null) {
      return const AhsPanel(
        padding: EdgeInsets.all(16),
        child: Text(
          'No saved readings yet. Open Live Monitoring to collect data.',
        ),
      );
    }
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Snapshot',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MM-dd-yyyy h:mm a').format(latest.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReadingChip(
                label: 'Temp',
                value: '${latest.temperature.toStringAsFixed(1)} C',
              ),
              _ReadingChip(
                label: 'Humidity',
                value: '${latest.humidity.toStringAsFixed(0)}%',
              ),
              _ReadingChip(label: 'pH', value: latest.ph.toStringAsFixed(2)),
              _ReadingChip(
                label: 'TDS',
                value: '${latest.tds.toStringAsFixed(0)} ppm',
              ),
              _ReadingChip(
                label: 'Water',
                value: '${latest.waterLevel.toStringAsFixed(1)} cm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetRangeCard extends StatelessWidget {
  final PlantModel plant;

  const _PresetRangeCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    final preset = PlantPreset.byKey(plant.presetKey);
    final ranges = SensorThresholds.forPlant(plant);
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${preset.label} Sensor Ranges',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _RangeRow(
            label: 'Temperature',
            value: '${ranges.temperature.min}-${ranges.temperature.max} C',
          ),
          _RangeRow(
            label: 'Humidity',
            value: '${ranges.humidity.min}-${ranges.humidity.max}%',
          ),
          _RangeRow(label: 'pH', value: '${ranges.ph.min}-${ranges.ph.max}'),
          _RangeRow(
            label: 'TDS',
            value:
                '${ranges.tds.min.toStringAsFixed(0)}-${ranges.tds.max.toStringAsFixed(0)} ppm',
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final PlantModel plant;
  final VoidCallback onNutrients;
  final VoidCallback onWaterChanged;

  const _ReminderCard({
    required this.plant,
    required this.onNutrients,
    required this.onWaterChanged,
  });

  @override
  Widget build(BuildContext context) {
    String age(DateTime? date) {
      final base = date ?? plant.addedDate;
      final days = DateTime.now().difference(base).inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }

    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Care Reminders',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _ReminderAction(
            icon: Icons.science_outlined,
            label: 'Nutrients',
            value: age(plant.lastNutrientAt),
            onTap: onNutrients,
          ),
          const SizedBox(height: 8),
          _ReminderAction(
            icon: Icons.water_drop_outlined,
            label: 'Water change',
            value: age(plant.lastWaterChangeAt),
            onTap: onWaterChanged,
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final _PlantStatusSummaryData data;

  const _TimelineCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final plant = data.plant;
    final monitoringDays = DateTime.now()
        .difference(plant.addedDate)
        .inDays
        .clamp(0, 9999);
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          _TimelineLine(
            icon: Icons.spa_rounded,
            label: 'Planted',
            value: DateFormat('MM-dd-yyyy').format(plant.addedDate),
          ),
          _TimelineLine(
            icon: Icons.calendar_month_rounded,
            label: 'Monitoring',
            value: '$monitoringDays day${monitoringDays == 1 ? '' : 's'}',
          ),
          _TimelineLine(
            icon: Icons.event_available_rounded,
            label: 'Planned harvest',
            value: plant.harvestDate == null
                ? 'Not set'
                : DateFormat('MM-dd-yyyy').format(plant.harvestDate!),
          ),
          for (final event in data.harvests.take(3))
            _TimelineLine(
              icon: Icons.agriculture_rounded,
              label: 'Harvest',
              value:
                  '${DateFormat('MM-dd-yyyy').format(event.harvestedAt)} - ${event.weightKg.toStringAsFixed(1)} kg',
            ),
        ],
      ),
    );
  }
}

class _MiniStatusStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatusStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AHSColors.primaryGlow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  final String label;
  final String value;

  const _ReadingChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: AHSColors.bgCardAlt,
      side: const BorderSide(color: AHSColors.border),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final String value;

  const _RangeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AHSColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ReminderAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AHSColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label - $value',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(onPressed: onTap, child: const Text('Mark done')),
      ],
    );
  }
}

class _TimelineLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimelineLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AHSColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
