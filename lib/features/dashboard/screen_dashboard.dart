import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/harvest_event.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/features/analytics/screen_analytics.dart';
import 'package:ahs/features/harvest/screen_harvest_history.dart';
import 'package:ahs/features/plant_area/screen_plant_area.dart';
import 'package:ahs/features/status/screen_status.dart';
import 'package:ahs/shared/widgets/app_ui.dart';
import 'package:ahs/shared/widgets/plant_image.dart';

part 'widgets/dashboard_widgets.dart';

// ─────────────────────────────────────────────
//  Dashboard Screen
// ─────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _HarvestInput {
  final double weightKg;
  final bool markDone;

  const _HarvestInput({required this.weightKg, required this.markDone});
}

class _HarvestDialog extends StatefulWidget {
  final PlantModel plant;
  final int alive;
  final String timingText;

  const _HarvestDialog({
    required this.plant,
    required this.alive,
    required this.timingText,
  });

  @override
  State<_HarvestDialog> createState() => _HarvestDialogState();
}

class _HarvestDialogState extends State<_HarvestDialog> {
  final TextEditingController _weightController = TextEditingController();
  late bool _markDone;
  String? _weightError;

  @override
  void initState() {
    super.initState();
    _markDone = widget.plant.harvestType == PlantHarvestType.single;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      setState(() => _weightError = 'Enter a harvest weight greater than 0.');
      return;
    }
    Navigator.of(
      context,
    ).pop(_HarvestInput(weightKg: weight, markDone: _markDone));
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    return AlertDialog(
      scrollable: true,
      title: const Text('Record Harvest'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${plant.name}" has ${widget.alive} of ${plant.quantity} plants marked alive. ${widget.timingText}',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: AHSColors.textMid,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _weightController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Harvest weight',
              hintText: '0.0',
              suffixText: 'kg',
              errorText: _weightError,
            ),
          ),
          if (plant.harvestType == PlantHarvestType.multiple) ...[
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('Continue'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.done_all_rounded),
                  label: Text('Done'),
                ),
              ],
              selected: {_markDone},
              onSelectionChanged: (value) {
                setState(() => _markDone = value.first);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_markDone ? 'Finish Harvest' : 'Save Harvest'),
        ),
      ],
    );
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PlantModel> _plants = [];
  List<HarvestEvent> _harvestEvents = [];
  bool _loading = true;

  // battery
  double _batteryPercent = 100.0;
  Timer? _batteryTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadBattery();
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadBattery(),
    );
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    super.dispose();
  }

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
      builder: (_) => AlertDialog(
        title: const Text('Device Battery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BatteryDialogWidget(percent: _batteryPercent),
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
              'Estimated runtime: 3 hours',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: AHSColors.textSoft,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _batteryPercent < 20
                      ? Icons.battery_alert_rounded
                      : _batteryPercent >= 100
                      ? Icons.battery_full_rounded
                      : Icons.battery_std_rounded,
                  size: 18,
                  color: _batteryPercent < 20
                      ? AHSColors.critical
                      : AHSColors.stable,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _batteryPercent <= 0
                        ? 'Battery depleted'
                        : _batteryPercent < 20
                        ? 'Low battery'
                        : _batteryPercent >= 100
                        ? 'Fully charged'
                        : 'Running on battery',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
            label: const Text('Mark as Charged'),
            onPressed: () async {
              await DatabaseHelper.instance.resetBattery();
              await _loadBattery();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    try {
      final list = await DatabaseHelper.instance.getAllPlants();
      final harvestEvents = await DatabaseHelper.instance.getHarvestEvents();
      if (mounted) {
        setState(() {
          _plants = list;
          _harvestEvents = harvestEvents;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _plants = [];
          _harvestEvents = [];
          _loading = false;
        });
      }
    }
  }

  // ── helpers ───────────────────────────────
  PlantModel? get _active => _plants.where((p) => p.isActive).firstOrNull;

  Future<void> _setActive(PlantModel p) async {
    final plantId = p.id;
    if (plantId == null || p.isHarvested) {
      _showError('Only saved growing plants can be set active.');
      return;
    }
    final ok = await _confirm(
      title: 'Set "${p.name}" as active?',
      body:
          'Sensor readings fetched from Firebase will be saved locally under this plant while it is active.',
      action: 'Set Active',
    );
    if (!ok) return;

    try {
      await DatabaseHelper.instance.setActivePlant(plantId);
      if (!mounted) return;
      await _reload();
    } catch (_) {
      _showError('Unable to set active plant. Please try again.');
    }
  }

  Future<void> _harvest(PlantModel p) async {
    final status = _harvestTimingText(p);
    final result = await _showHarvestSheet(p, status);
    if (result == null) return;

    try {
      await DatabaseHelper.instance.recordHarvest(
        plant: p,
        weightKg: result.weightKg,
        markDone: result.markDone,
      );
      if (!mounted) return;
      await _reload();
    } catch (_) {
      _showError('Unable to record harvest. Please check the plant data.');
    }
  }

  Future<_HarvestInput?> _showHarvestSheet(
    PlantModel plant,
    String timingText,
  ) async {
    final alive = plant.id == null
        ? plant.quantity
        : await DatabaseHelper.instance.getAliveSlotCount(plant.id!);
    if (!mounted) return null;

    return showDialog<_HarvestInput>(
      context: context,
      builder: (_) =>
          _HarvestDialog(plant: plant, alive: alive, timingText: timingText),
    );
  }

  Future<void> _delete(PlantModel p) async {
    final plantId = p.id;
    if (plantId == null) {
      _showError('This plant has not been saved yet.');
      return;
    }
    final ok = await _confirm(
      title: 'Delete "${p.name}"?',
      body:
          'This will permanently remove the plant record from this device. Saved sensor logs may remain for reports and analytics.',
      action: 'Delete',
      danger: true,
    );
    if (ok) {
      try {
        await DatabaseHelper.instance.deletePlant(plantId);
        if (!mounted) return;
        await _reload();
      } catch (_) {
        _showError('Unable to delete plant. Please try again.');
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    return showAhsConfirmDialog(
      context: context,
      title: title,
      message: body,
      confirmLabel: action,
      destructive: danger,
    );
  }

  String _harvestTimingText(PlantModel plant) {
    final planned = plant.harvestDate;
    if (planned == null) {
      return 'No planned harvest date was set for comparison.';
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(planned);
    final diff = today.difference(target).inDays;
    if (diff < 0) {
      final days = diff.abs();
      return 'This is $days day${days == 1 ? '' : 's'} earlier than the planned harvest date.';
    }
    if (diff > 0) {
      return 'This is $diff day${diff == 1 ? '' : 's'} after the planned harvest date.';
    }
    return 'This matches the planned harvest date.';
  }

  void _openAddSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddPlantSheet(onSaved: _reload),
  );

  void _openEditSheet(PlantModel plant) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddPlantSheet(onSaved: _reload, initialPlant: plant),
  );

  void _openHarvestHistory() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HarvestHistoryScreen(plants: _plants)),
  );

  void _openStatus(PlantModel plant) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => StatusScreen(plant: plant)),
  );

  void _openAnalytics(PlantModel plant) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AnalyticsScreen(plant: plant)),
  );

  Future<void> _openPlantArea(PlantModel plant) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlantAreaScreen(plant: plant)),
      );
      _reload();
    } catch (_) {
      _showError('Unable to open plant area.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AHSColors.critical),
    );
  }

  // ── build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasActive = _active != null;
    final visiblePlants = _plants.where((plant) => !plant.isHarvested).toList();

    if (MediaQuery.sizeOf(context).width < 700) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        physics: const BouncingScrollPhysics(),
        children: [
          _CompactChamberCard(
            active: _active,
            batteryPercent: _batteryPercent,
            onBatteryTap: _showBatterySettings,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 420.0,
            child: _DashboardGraphStack(
              plants: _plants,
              harvestEvents: _harvestEvents,
              activePlant: _active,
              height: 400.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('My Plants', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openAddSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add plant'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (visiblePlants.isEmpty)
            const _CompactEmptyPlants()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visiblePlants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final plant = visiblePlants[index];
                final locked =
                    hasActive && !plant.isActive && !plant.isHarvested;
                return _CompactPlantCard(
                  plant: plant,
                  locked: locked,
                  onActivate: () => _setActive(plant),
                  onHarvest: () => _harvest(plant),
                  onDelete: () => _delete(plant),
                  onEdit: () => _openEditSheet(plant),
                  onArea: () => _openPlantArea(plant),
                  onStatus: () => _openStatus(plant),
                  onAnalytics: () => _openAnalytics(plant),
                );
              },
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top bar ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AHSColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automated Hydrophonic System',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AHSColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: AHSColors.textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Battery indicator in top bar
                    GestureDetector(
                      onTap: _showBatterySettings,
                      child: _BatteryTopBarWidget(percent: _batteryPercent),
                    ),
                  ],
                ),
              ),
            ),

            // ── Chamber status card ───────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ChamberCard(active: _active),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08, end: 0),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _DashboardOverview(
                  plants: _plants,
                  harvestEvents: _harvestEvents,
                  activePlant: _active,
                  onStatus: _active == null
                      ? null
                      : () => _openStatus(_active!),
                  onAnalytics: _active == null
                      ? null
                      : () => _openAnalytics(_active!),
                  onArea: _active == null
                      ? null
                      : () => _openPlantArea(_active!),
                  onHistory: _openHarvestHistory,
                ),
              ),
            ),

            // ── Section header ────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Plants',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AHSColors.textDark,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton.outlined(
                          tooltip: 'Harvest history',
                          onPressed: _openHarvestHistory,
                          icon: const Icon(Icons.history_rounded),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _openAddSheet,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add plant'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── List ──────────────────────────
            if (_loading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (visiblePlants.isEmpty)
              const SliverToBoxAdapter(child: _EmptyPlants())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final plant = visiblePlants[i];
                    // Disable if another plant is already active
                    final locked =
                        hasActive && !plant.isActive && !plant.isHarvested;
                    return _PlantCard(
                          plant: plant,
                          locked: locked,
                          onActivate: () => _setActive(plant),
                          onHarvest: () => _harvest(plant),
                          onDelete: () => _delete(plant),
                          onEdit: () => _openEditSheet(plant),
                          onArea: () => _openPlantArea(plant),
                          onStatus: () => _openStatus(plant),
                          onAnalytics: () => _openAnalytics(plant),
                        )
                        .animate()
                        .fadeIn(delay: (i * 70).ms, duration: 400.ms)
                        .slideX(begin: 0.06, end: 0);
                  }, childCount: visiblePlants.length),
                ),
              ),

            // Bottom clearance — clears Android nav bar + extra breathing room
            SliverToBoxAdapter(
              child: Builder(
                builder: (ctx) =>
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom + 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Chamber card (top hero)
// ─────────────────────────────────────────────
