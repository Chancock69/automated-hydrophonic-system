part of '../screen_dashboard.dart';

class _ChamberCard extends StatelessWidget {
  final PlantModel? active;
  const _ChamberCard({this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AHSColors.primary, AHSColors.primaryMid],
        ),
        borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
        boxShadow: [
          BoxShadow(
            color: AHSColors.primary.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHAMBER 01',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  active?.name ?? 'No Plant Active',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (active?.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    active!.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
                if (active?.harvestDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_rounded,
                        color: Colors.white60,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Harvest ${DateFormat('MMM d, y').format(active!.harvestDate!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(46),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active != null
                            ? Icons.sensors_rounded
                            : Icons.power_settings_new_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        active != null ? 'Active' : 'Standby',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Plant photo or emoji
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PlantImage(
              imagePath: active?.imagePath,
              width: 76,
              height: 76,
              fallback: Container(
                color: Colors.white.withAlpha(38),
                child: const Center(
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChamberCard extends StatelessWidget {
  final PlantModel? active;
  final double batteryPercent;
  final VoidCallback onBatteryTap;

  const _CompactChamberCard({
    required this.active,
    required this.batteryPercent,
    required this.onBatteryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AHSColors.primary, AHSColors.primaryMid],
        ),
        borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
        boxShadow: [
          BoxShadow(
            color: AHSColors.primary.withAlpha(32),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CHAMBER 01',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active?.name ?? 'No Plant Active',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active == null
                      ? 'Standby'
                      : active!.harvestDate == null
                      ? 'Active monitoring'
                      : 'Harvest ${DateFormat('MMM d').format(active!.harvestDate!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Device battery',
            onPressed: onBatteryTap,
            color: Colors.white,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.battery_5_bar_rounded),
                Positioned(
                  right: -10,
                  top: -8,
                  child: Text(
                    '${batteryPercent.round().clamp(0, 100)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PlantImage(
              imagePath: active?.imagePath,
              width: 58,
              height: 58,
              fallback: Container(
                color: Colors.white.withAlpha(36),
                child: const Icon(
                  Icons.local_florist_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEmptyPlants extends StatelessWidget {
  const _CompactEmptyPlants();

  @override
  Widget build(BuildContext context) {
    return AhsPanel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AHSColors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spa_outlined, color: AHSColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No plants yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Use Add plant to create the first chamber record.',
                  maxLines: 2,
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

class _CompactPlantCard extends StatelessWidget {
  final PlantModel plant;
  final bool locked;
  final VoidCallback onActivate;
  final VoidCallback onHarvest;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onArea;
  final VoidCallback onStatus;
  final VoidCallback onAnalytics;

  const _CompactPlantCard({
    required this.plant,
    required this.locked,
    required this.onActivate,
    required this.onHarvest,
    required this.onDelete,
    required this.onEdit,
    required this.onArea,
    required this.onStatus,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final active = plant.isActive;
    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: AhsPanel(
        padding: const EdgeInsets.all(8),
        borderColor: active ? AHSColors.primaryLight : AHSColors.border,
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: PlantImage(
                    imagePath: plant.imagePath,
                    width: 46,
                    height: 46,
                    fallback: Container(
                      color: AHSColors.primaryGlow,
                      child: const Icon(
                        Icons.spa_rounded,
                        color: AHSColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plant.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (active)
                            const _StatusBadge(
                              label: 'Active',
                              color: AHSColors.stable,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plant.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${plant.quantity} planted - ${plant.harvestType.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Plant actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit plant')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete plant',
                        style: TextStyle(color: AHSColors.critical),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: active
                  ? [
                      _CompactPlantAction(
                        tooltip: 'Open live status',
                        icon: Icons.monitor_heart_outlined,
                        onTap: onStatus,
                      ),
                      const SizedBox(width: 6),
                      _CompactPlantAction(
                        tooltip: 'Open analytics',
                        icon: Icons.insights_outlined,
                        onTap: onAnalytics,
                      ),
                      const SizedBox(width: 6),
                      _CompactPlantAction(
                        tooltip: 'Open plant area',
                        icon: Icons.grid_view_rounded,
                        onTap: onArea,
                      ),
                      const SizedBox(width: 6),
                      _CompactPlantAction(
                        tooltip: 'Record harvest',
                        icon: Icons.agriculture_rounded,
                        color: AHSColors.warning,
                        onTap: onHarvest,
                      ),
                    ]
                  : [
                      _CompactPlantAction(
                        tooltip: locked
                            ? 'Another plant is active'
                            : 'Set active',
                        icon: Icons.power_settings_new_rounded,
                        onTap: locked ? null : onActivate,
                      ),
                      _CompactPlantAction(
                        tooltip: 'Open analytics',
                        icon: Icons.insights_outlined,
                        onTap: onAnalytics,
                      ),
                      _CompactPlantAction(
                        tooltip: 'Edit plant',
                        icon: Icons.edit_outlined,
                        onTap: onEdit,
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPlantAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CompactPlantAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = AHSColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          color: color,
          padding: const EdgeInsets.all(4),
          style: IconButton.styleFrom(
            backgroundColor: color.withAlpha(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  final List<PlantModel> plants;
  final List<HarvestEvent> harvestEvents;
  final PlantModel? activePlant;
  final VoidCallback? onStatus;
  final VoidCallback? onAnalytics;
  final VoidCallback? onArea;
  final VoidCallback onHistory;

  const _DashboardOverview({
    required this.plants,
    required this.harvestEvents,
    required this.activePlant,
    required this.onStatus,
    required this.onAnalytics,
    required this.onArea,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final growing = plants.where((plant) => !plant.isHarvested).length;
    final upcoming = plants.where((plant) {
      final date = plant.harvestDate;
      return !plant.isHarvested &&
          date != null &&
          !DateUtils.dateOnly(date).isBefore(today);
    }).length;
    final totalWeight = harvestEvents.fold<double>(
      0,
      (total, event) => total + event.weightKg,
    );

    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_outlined,
                color: AHSColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chamber overview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                activePlant == null ? 'No active plant' : activePlant!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: activePlant == null
                      ? AHSColors.textSoft
                      : AHSColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  value: '$growing',
                  label: 'Growing',
                  color: AHSColors.primary,
                  background: AHSColors.primaryGlow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  value: '$upcoming',
                  label: 'Upcoming',
                  color: AHSColors.warning,
                  background: AHSColors.warningGlow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  value: '${totalWeight.toStringAsFixed(1)} kg',
                  label: 'Harvested',
                  color: AHSColors.sensor,
                  background: AHSColors.sensorGlow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _OverviewAction(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Monitor',
                  onTap: onStatus,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _OverviewAction(
                  icon: Icons.insights_outlined,
                  label: 'Analytics',
                  onTap: onAnalytics,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _OverviewAction(
                  icon: Icons.grid_view_rounded,
                  label: 'Area',
                  onTap: onArea,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _OverviewAction(
                  icon: Icons.history_rounded,
                  label: 'History',
                  onTap: onHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _OverviewMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color background;

  const _OverviewMetric({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AHSColors.textMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _OverviewAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: enabled ? label : 'Select an active plant first',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: enabled ? AHSColors.bgCardAlt : AHSColors.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AHSColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: enabled ? AHSColors.primary : AHSColors.textHint,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: enabled ? AHSColors.textMid : AHSColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Plant card row
// ─────────────────────────────────────────────
class _DashboardGraphStack extends StatefulWidget {
  final List<PlantModel> plants;
  final List<HarvestEvent> harvestEvents;
  final PlantModel? activePlant;
  final double height;

  const _DashboardGraphStack({
    required this.plants,
    required this.harvestEvents,
    required this.activePlant,
    this.height = 390,
  });

  @override
  State<_DashboardGraphStack> createState() => _DashboardGraphStackState();
}

class _DashboardGraphStackState extends State<_DashboardGraphStack> {
  final PageController _controller = PageController(viewportFraction: 0.94);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _HarvestScheduleGraph(plants: widget.plants),
      _HarvestWeightGraph(events: widget.harvestEvents),
      _LifeRateGraph(events: widget.harvestEvents),
      _PlantTimelineGraph(
        plants: widget.plants,
        harvestEvents: widget.harvestEvents,
        activePlant: widget.activePlant,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) => Padding(
              padding: EdgeInsets.only(
                right: index == cards.length - 1 ? 0 : 10,
              ),
              child: cards[index],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (index) => AnimatedContainer(
              duration: 180.ms,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _page ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: index == _page ? AHSColors.primary : AHSColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}

class _HarvestScheduleGraph extends StatelessWidget {
  final List<PlantModel> plants;

  const _HarvestScheduleGraph({required this.plants});

  @override
  Widget build(BuildContext context) {
    final tracked = plants.where((plant) => plant.harvestDate != null).toList();
    final harvested = tracked.where((plant) => plant.isHarvested).length;
    final early = tracked.where((plant) => _harvestDelta(plant) < 0).length;
    final late = tracked.where((plant) => _harvestDelta(plant) > 0).length;
    final upcoming = tracked.length - harvested;
    final chartPlants = tracked.take(6).toList();

    return _DashboardGraphCard(
      icon: Icons.event_available_rounded,
      title: 'Harvest Schedule',
      trailing: '${tracked.length} plants',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TrackerPill(
                label: 'Upcoming',
                value: upcoming.toString(),
                color: AHSColors.primaryMid,
              ),
              const SizedBox(width: 8),
              _TrackerPill(
                label: 'Early',
                value: early.toString(),
                color: AHSColors.stable,
              ),
              const SizedBox(width: 8),
              _TrackerPill(
                label: 'Late',
                value: late.toString(),
                color: AHSColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: chartPlants.isEmpty
                ? const _GraphEmpty(label: 'No harvest dates yet')
                : _AxisChartFrame(
                    yLabel: 'Days',
                    xLabel: 'Plants',
                    child: BarChart(_harvestChart(chartPlants)),
                  ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _ChartKey(color: AHSColors.primaryLight, label: 'Planned days'),
              SizedBox(width: 14),
              _ChartKey(color: AHSColors.warning, label: 'Actual/elapsed'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartData _harvestChart(List<PlantModel> chartPlants) {
    final maxDays = chartPlants.fold<double>(1, (maxValue, plant) {
      final planned = _plannedGrowDays(plant).toDouble();
      final actual = _actualOrElapsedDays(plant).toDouble();
      return max(maxValue, max(planned, actual));
    });

    return BarChartData(
      minY: 0,
      maxY: maxDays + 5,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: max(5, (maxDays / 3).ceilToDouble()),
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
            reservedSize: 28,
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
            getTitlesWidget: (value, _) {
              final index = value.toInt();
              if (index < 0 || index >= chartPlants.length) {
                return const SizedBox.shrink();
              }
              final name = _plantBatchLabel(chartPlants[index]);
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  name.length > 7 ? name.substring(0, 7) : name,
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
      barGroups: chartPlants.asMap().entries.map((entry) {
        final plant = entry.value;
        return BarChartGroupData(
          x: entry.key,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: _plannedGrowDays(plant).toDouble(),
              width: 8,
              color: AHSColors.primaryLight,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: _actualOrElapsedDays(plant).toDouble(),
              width: 8,
              color: _harvestDelta(plant) > 0
                  ? AHSColors.warning
                  : AHSColors.stable,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList(),
    );
  }

  static int _plannedGrowDays(PlantModel plant) {
    final planned = plant.harvestDate;
    if (planned == null) return 0;
    return DateUtils.dateOnly(
      planned,
    ).difference(DateUtils.dateOnly(plant.addedDate)).inDays.clamp(1, 9999);
  }

  static int _actualOrElapsedDays(PlantModel plant) {
    final end = plant.actualHarvestDate ?? DateTime.now();
    return DateUtils.dateOnly(
      end,
    ).difference(DateUtils.dateOnly(plant.addedDate)).inDays.clamp(0, 9999);
  }

  static int _harvestDelta(PlantModel plant) {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (!plant.isHarvested || planned == null || actual == null) return 0;
    return DateUtils.dateOnly(
      actual,
    ).difference(DateUtils.dateOnly(planned)).inDays;
  }
}

class _HarvestWeightGraph extends StatelessWidget {
  final List<HarvestEvent> events;

  const _HarvestWeightGraph({required this.events});

  @override
  Widget build(BuildContext context) {
    final recentEvents = events.take(4).toList();
    final totalWeight = events.fold<double>(
      0,
      (total, event) => total + event.weightKg,
    );

    return _DashboardGraphCard(
      icon: Icons.scale_rounded,
      title: 'Harvest Weight',
      trailing: '${totalWeight.toStringAsFixed(1)} kg',
      child: recentEvents.isEmpty
          ? const _GraphEmpty(label: 'Harvest records will appear here')
          : _HarvestWeightSummary(events: recentEvents, allEvents: events),
    );
  }
}

class _LifeRateGraph extends StatelessWidget {
  final List<HarvestEvent> events;

  const _LifeRateGraph({required this.events});

  @override
  Widget build(BuildContext context) {
    final recentEvents = events.take(4).toList();
    final avgLife = events.isEmpty
        ? 0.0
        : events.fold<double>(0, (total, event) => total + event.lifeRate) /
              events.length;

    return _DashboardGraphCard(
      icon: Icons.health_and_safety_rounded,
      title: 'Plant Life Rate',
      trailing: '${avgLife.toStringAsFixed(0)}%',
      child: recentEvents.isEmpty
          ? const _GraphEmpty(label: 'Survival rates will appear here')
          : _HarvestLifeSummary(events: recentEvents, allEvents: events),
    );
  }
}

class _HarvestWeightSummary extends StatelessWidget {
  final List<HarvestEvent> events;
  final List<HarvestEvent> allEvents;

  const _HarvestWeightSummary({required this.events, required this.allEvents});

  @override
  Widget build(BuildContext context) {
    final maxWeight = events.fold<double>(
      1,
      (value, event) => max(value, event.weightKg),
    );

    return Column(
      children: events.map((event) {
        final ratio = (event.weightKg / maxWeight).clamp(0.04, 1.0);
        return _HarvestProgressRow(
          name: _harvestEventBatchLabel(event),
          detail: _harvestEventDetail(event, allEvents),
          value: '${event.weightKg.toStringAsFixed(1)} kg',
          ratio: ratio,
          color: AHSColors.primaryMid,
        );
      }).toList(),
    );
  }
}

class _HarvestLifeSummary extends StatelessWidget {
  final List<HarvestEvent> events;
  final List<HarvestEvent> allEvents;

  const _HarvestLifeSummary({required this.events, required this.allEvents});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.map((event) {
        return _HarvestProgressRow(
          name: _harvestEventBatchLabel(event),
          detail:
              '${_harvestEventDetail(event, allEvents)} - ${event.survivedCount}/${event.totalCount} survived',
          value: '${event.lifeRate.toStringAsFixed(0)}%',
          ratio: (event.lifeRate / 100).clamp(0.04, 1.0),
          color: event.lifeRate >= 70 ? AHSColors.stable : AHSColors.warning,
        );
      }).toList(),
    );
  }
}

class _HarvestProgressRow extends StatelessWidget {
  final String name;
  final String detail;
  final String value;
  final double ratio;
  final Color color;

  const _HarvestProgressRow({
    required this.name,
    required this.detail,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AHSColors.textSoft,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: color.withAlpha(22),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

String _plantBatchLabel(PlantModel plant) {
  final id = plant.id;
  if (id == null) return plant.name;
  return '${plant.name} #$id';
}

String _harvestEventBatchLabel(HarvestEvent event) =>
    '${event.plantName} #${event.plantId}';

String _harvestEventDetail(HarvestEvent event, List<HarvestEvent> allEvents) {
  final sameBatch =
      allEvents.where((item) => item.plantId == event.plantId).toList()
        ..sort((a, b) => a.harvestedAt.compareTo(b.harvestedAt));
  final index = sameBatch.indexWhere(
    (item) =>
        item.id == event.id ||
        item.harvestedAt == event.harvestedAt &&
            item.weightKg == event.weightKg &&
            item.markedDone == event.markedDone,
  );
  final harvestNumber = index < 0 ? 1 : index + 1;
  final date = DateFormat('MMM d').format(event.harvestedAt);
  final isMultipleHarvest = sameBatch.length > 1 || !event.markedDone;
  if (!isMultipleHarvest) return 'Batch harvest - $date';

  final status = event.markedDone ? 'final' : 'continuing';
  return 'Harvest $harvestNumber of ${sameBatch.length} - $status - $date';
}

class _PlantTimelineGraph extends StatefulWidget {
  final List<PlantModel> plants;
  final List<HarvestEvent> harvestEvents;
  final PlantModel? activePlant;

  const _PlantTimelineGraph({
    required this.plants,
    required this.harvestEvents,
    required this.activePlant,
  });

  @override
  State<_PlantTimelineGraph> createState() => _PlantTimelineGraphState();
}

class _PlantTimelineGraphState extends State<_PlantTimelineGraph> {
  late DateTime _month = _initialMonth();

  @override
  void didUpdateWidget(covariant _PlantTimelineGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePlant?.id != widget.activePlant?.id) {
      _month = _initialMonth();
    }
  }

  DateTime _initialMonth() {
    final plant = _focusedPlant();
    final dates = <DateTime>[
      if (plant != null) ...[
        plant.addedDate,
        if (plant.harvestDate != null) plant.harvestDate!,
        if (plant.actualHarvestDate != null) plant.actualHarvestDate!,
      ],
      for (final event in _focusedEvents()) event.harvestedAt,
    ]..sort((a, b) => b.compareTo(a));
    final selected = dates.isEmpty ? DateTime.now() : dates.first;
    return DateTime(selected.year, selected.month);
  }

  PlantModel? _focusedPlant() {
    final active = widget.activePlant;
    if (active != null) return active;
    final visible = widget.plants
        .where(
          (plant) =>
              !plant.isHarvested &&
              (plant.harvestDate != null || plant.actualHarvestDate != null),
        )
        .toList();
    return visible.isEmpty ? null : visible.first;
  }

  List<HarvestEvent> _focusedEvents() {
    final plant = _focusedPlant();
    if (plant?.id == null) return const [];
    return widget.harvestEvents
        .where((event) => event.plantId == plant!.id)
        .toList();
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final plant = _focusedPlant();
    final events = _focusedEvents().take(12).toList();
    final mappedPlants = plant == null ? const <PlantModel>[] : [plant];

    return _DashboardGraphCard(
      icon: Icons.calendar_month_rounded,
      title: 'Plant Calendar',
      trailing: plant?.name ?? 'No plant',
      child: mappedPlants.isEmpty && events.isEmpty
          ? const _GraphEmpty(label: 'Add harvest dates to map plant cycles')
          : _PlantCalendar(
              month: _month,
              plants: mappedPlants,
              events: events,
              onPrevious: () => _moveMonth(-1),
              onNext: () => _moveMonth(1),
            ),
    );
  }
}

class _PlantCalendar extends StatelessWidget {
  final DateTime month;
  final List<PlantModel> plants;
  final List<HarvestEvent> events;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PlantCalendar({
    required this.month,
    required this.plants,
    required this.events,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final leading = first.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    return Column(
      children: [
        _CalendarMonthNav(month: month, onPrevious: onPrevious, onNext: onNext),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
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
        const SizedBox(height: 5),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
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
              );
            },
          ),
        ),
      ],
    );
  }

  List<Color> _markersFor(DateTime date) {
    final markers = <Color>[];
    for (final plant in plants) {
      if (_sameDate(date, plant.addedDate)) {
        markers.add(const Color(0xFF2563EB));
      }
      if (plant.harvestDate != null && _sameDate(date, plant.harvestDate!)) {
        markers.add(AHSColors.warning);
      }
      if (plant.actualHarvestDate != null &&
          _sameDate(date, plant.actualHarvestDate!)) {
        markers.add(_actualHarvestColor(plant));
      }
    }
    for (final event in events) {
      if (!_sameDate(date, event.harvestedAt)) continue;
      markers.add(event.markedDone ? AHSColors.warning : AHSColors.neonCyan);
    }
    return markers.take(4).toList();
  }

  bool _isInTimeline(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return plants.any((plant) {
      final start = DateUtils.dateOnly(plant.addedDate);
      final end = DateUtils.dateOnly(
        plant.actualHarvestDate ?? plant.harvestDate ?? DateTime.now(),
      );
      return !day.isBefore(start) && !day.isAfter(end);
    });
  }

  Color _actualHarvestColor(PlantModel plant) {
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

  const _CalendarDayCell({
    required this.day,
    required this.markers,
    required this.inTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final hasMarker = markers.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: hasMarker
            ? AHSColors.primary.withAlpha(10)
            : inTimeline
            ? AHSColors.primaryGlow.withAlpha(36)
            : AHSColors.bgCardAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: hasMarker
              ? AHSColors.primaryLight.withAlpha(90)
              : inTimeline
              ? AHSColors.primaryLight.withAlpha(55)
              : AHSColors.divider,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasMarker ? AHSColors.textDark : AHSColors.textSoft,
                  ),
                ),
              ),
            ),
          ),
          if (inTimeline)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: AHSColors.primaryLight.withAlpha(120),
                borderRadius: BorderRadius.circular(999),
              ),
            )
          else if (hasMarker)
            const SizedBox(height: 4),
          if (hasMarker)
            Row(
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
          if (hasMarker || inTimeline) const SizedBox(height: 1),
        ],
      ),
    );
  }
}

class _CalendarMonthNav extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarMonthNav({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CalendarNavButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
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
        _CalendarNavButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarNavButton({required this.icon, required this.onTap});

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

class _DashboardGraphCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;
  final Widget child;

  const _DashboardGraphCard({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AHSColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AHSColors.primary.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AHSColors.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AHSColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
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

class _GraphEmpty extends StatelessWidget {
  final String label;

  const _GraphEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AHSColors.textSoft,
        ),
      ),
    );
  }
}

class _TrackerPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TrackerPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _ChartKey extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartKey({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
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

class _PlantCard extends StatelessWidget {
  final PlantModel plant;
  final bool locked;
  final VoidCallback onActivate;
  final VoidCallback onHarvest;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onArea;
  final VoidCallback onStatus;
  final VoidCallback onAnalytics;

  const _PlantCard({
    required this.plant,
    required this.locked,
    required this.onActivate,
    required this.onHarvest,
    required this.onDelete,
    required this.onEdit,
    required this.onArea,
    required this.onStatus,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final harvested = plant.isHarvested;
    final active = plant.isActive;

    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AHSColors.bgCard,
          borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
          border: Border.all(
            color: active ? AHSColors.primaryLight : AHSColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PlantImage(
                    imagePath: plant.imagePath,
                    width: 72,
                    height: 72,
                    fallback: Container(
                      color: AHSColors.primaryGlow,
                      child: const Center(
                        child: Icon(
                          Icons.spa_rounded,
                          size: 30,
                          color: AHSColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              plant.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(height: 1.15),
                            ),
                          ),
                          if (active || harvested) ...[
                            const SizedBox(width: 8),
                            _StatusBadge(
                              label: active ? 'Active' : 'Harvested',
                              color: active
                                  ? AHSColors.stable
                                  : AHSColors.warning,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plant.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: AHSColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.numbers_rounded,
                            size: 13,
                            color: AHSColors.textSoft,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${plant.quantity} plants · ${plant.harvestType.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AHSColors.textSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (plant.harvestDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 13,
                              color: AHSColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'MMM d, y',
                                ).format(plant.harvestDate!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AHSColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (harvested && plant.actualHarvestDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _harvestStatusLabel(plant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _harvestStatusColor(plant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Plant actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit plant'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: AHSColors.critical,
                        ),
                        title: Text(
                          'Delete plant',
                          style: TextStyle(color: AHSColors.critical),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: active
                  ? [
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Monitor',
                          onTap: onStatus,
                        ),
                      ),
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.insights_outlined,
                          label: 'Analytics',
                          onTap: onAnalytics,
                        ),
                      ),
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.grid_view_rounded,
                          label: 'Area',
                          onTap: onArea,
                        ),
                      ),
                      if (!harvested)
                        Expanded(
                          child: _PlantQuickAction(
                            icon: Icons.agriculture_rounded,
                            label: 'Harvest',
                            color: AHSColors.warning,
                            onTap: onHarvest,
                          ),
                        ),
                    ]
                  : [
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.power_settings_new_rounded,
                          label: locked ? 'Unavailable' : 'Set active',
                          onTap: locked || harvested ? null : onActivate,
                        ),
                      ),
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.insights_outlined,
                          label: 'Analytics',
                          onTap: onAnalytics,
                        ),
                      ),
                      Expanded(
                        child: _PlantQuickAction(
                          icon: Icons.grid_view_rounded,
                          label: 'Area',
                          onTap: onArea,
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  String _harvestStatusLabel(PlantModel plant) {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (planned == null || actual == null) return 'No schedule';

    final diff = DateUtils.dateOnly(
      actual,
    ).difference(DateUtils.dateOnly(planned)).inDays;
    if (diff < 0) {
      final days = diff.abs();
      return '$days day${days == 1 ? '' : 's'} early';
    }
    if (diff > 0) {
      return '$diff day${diff == 1 ? '' : 's'} late';
    }
    return 'on schedule';
  }

  Color _harvestStatusColor(PlantModel plant) {
    final planned = plant.harvestDate;
    final actual = plant.actualHarvestDate;
    if (planned == null || actual == null) return AHSColors.textHint;

    final diff = DateUtils.dateOnly(
      actual,
    ).difference(DateUtils.dateOnly(planned)).inDays;
    if (diff < 0) return AHSColors.stable;
    if (diff > 0) return AHSColors.warning;
    return AHSColors.primaryMid;
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PlantQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PlantQuickAction({
    required this.icon,
    required this.label,
    this.color = AHSColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: enabled ? color : AHSColors.textHint),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: enabled ? AHSColors.textMid : AHSColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── small glowing badge ───────────────────────
class _GlowBadge extends StatefulWidget {
  final String label;
  final Color color;
  const _GlowBadge({required this.label, required this.color});
  @override
  State<_GlowBadge> createState() => _GlowBadgeState();
}

class _GlowBadgeState extends State<_GlowBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: 1600.ms)
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
      final g = _c.value;
      return Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha(((0.45 * g) * 255).round()),
              blurRadius: 12 * g,
              spreadRadius: 2 * g,
            ),
          ],
        ),
        child: Text(
          '● ${widget.label}',
          style: const TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    },
  );
}

class _EmptyPlants extends StatelessWidget {
  const _EmptyPlants();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: AhsPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AHSColors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: AHSColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No plants yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Use Add plant above to create the first chamber record.',
                  style: TextStyle(fontSize: 12, color: AHSColors.textSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Add Plant Bottom Sheet
// ─────────────────────────────────────────────
class _AddPlantSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final PlantModel? initialPlant;

  const _AddPlantSheet({required this.onSaved, this.initialPlant});
  @override
  State<_AddPlantSheet> createState() => _AddPlantSheetState();
}

class _AddPlantSheetState extends State<_AddPlantSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _imgPath;
  DateTime? _harvestDate;
  int _quantity = 1;
  PlantHarvestType _harvestType = PlantHarvestType.single;
  bool _saving = false;
  bool get _editing => widget.initialPlant != null;

  @override
  void initState() {
    super.initState();
    final plant = widget.initialPlant;
    if (plant != null) {
      _nameCtrl.text = plant.name;
      _descCtrl.text = plant.description;
      _imgPath = plant.imagePath;
      _harvestDate = plant.harvestDate;
      _quantity = plant.quantity;
      _harvestType = plant.harvestType;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null && mounted) setState(() => _imgPath = file.path);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final savedDate = _harvestDate;
    final date = await showDatePicker(
      context: context,
      initialDate: savedDate ?? now.add(const Duration(days: 30)),
      firstDate: DateUtils.dateOnly(now),
      lastDate: now.add(const Duration(days: 365)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AHSColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: savedDate != null
          ? TimeOfDay.fromDateTime(savedDate)
          : const TimeOfDay(hour: 9, minute: 0),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AHSColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _harvestDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a plant name before saving.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final initial = widget.initialPlant;
      if (initial == null) {
        final plant = PlantModel(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          imagePath: _imgPath,
          addedDate: DateTime.now(),
          harvestDate: _harvestDate,
          quantity: _quantity,
          harvestType: _harvestType,
        );
        await DatabaseHelper.instance.insertPlant(plant);
      } else {
        await DatabaseHelper.instance.updatePlant(
          initial.copyWith(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            imagePath: _imgPath,
            harvestDate: _harvestDate,
            quantity: _quantity,
            harvestType: _harvestType,
          ),
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save this plant. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AHSColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AHSColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: 19,
                    color: AHSColors.textDark,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _editing ? 'Edit Plant' : 'Add New Plant',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 1: Basic Info ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AHSColors.bgCardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AHSColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image pick (small square)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: AHSColors.primaryGlow.withAlpha(38),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AHSColors.primaryLight.withAlpha(89),
                              width: 1.5,
                            ),
                          ),
                          child: _imgPath != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: PlantImage(
                                    imagePath: _imgPath,
                                    width: 72,
                                    height: 72,
                                    fallback: const _ImagePickerPlaceholder(),
                                  ),
                                )
                              : const _ImagePickerPlaceholder(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _Field(
                          ctrl: _nameCtrl,
                          label: 'Plant Name',
                          hint: 'e.g. Lettuce, Basil',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    ctrl: _descCtrl,
                    label: 'Description',
                    hint: 'Variety, source, notes…',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 2: Setup ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AHSColors.bgCardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AHSColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planting Setup',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  _QuantityPicker(
                    value: _quantity,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(height: 14),
                  _HarvestTypePicker(
                    value: _harvestType,
                    onChanged: (value) => setState(() => _harvestType = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 3: Schedule ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AHSColors.bgCardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AHSColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule & Notifications',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: AHSColors.bgCard,
                        borderRadius: BorderRadius.circular(
                          AHSTheme.controlRadius,
                        ),
                        border: Border.all(color: AHSColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: AHSColors.primaryLight,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _harvestDate != null
                                  ? 'Harvest: ${DateFormat('MMM d, y @ h:mm a').format(_harvestDate!)}'
                                  : 'Set harvest date & time (optional)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                color: _harvestDate != null
                                    ? AHSColors.textDark
                                    : AHSColors.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_editing ? 'Update Plant' : 'Save Plant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final int maxLines;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AHSColors.textMid,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        maxLength: maxLines == 1 ? 60 : 240,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: AHSColors.textDark,
        ),
        decoration: InputDecoration(hintText: hint, counterText: ''),
      ),
    ],
  );
}
// ─────────────────────────────────────────────
//  Battery widgets for Dashboard
// ─────────────────────────────────────────────

class _ImagePickerPlaceholder extends StatelessWidget {
  const _ImagePickerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: AHSColors.primaryLight,
          size: 26,
        ),
        SizedBox(height: 4),
        Text(
          'Add photo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: AHSColors.textSoft,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _QuantityPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QuantityPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(AHSTheme.controlRadius),
        border: Border.all(color: AHSColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant Quantity',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AHSColors.textMid,
                  ),
                ),
                Text(
                  'Maximum of 6 plant positions',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AHSColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AHSColors.primary,
            ),
          ),
          IconButton(
            onPressed: value < 6 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _HarvestTypePicker extends StatelessWidget {
  final PlantHarvestType value;
  final ValueChanged<PlantHarvestType> onChanged;

  const _HarvestTypePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Harvest Type',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AHSColors.textMid,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AHSColors.bgCard,
            borderRadius: BorderRadius.circular(AHSTheme.controlRadius),
            border: Border.all(color: AHSColors.border),
          ),
          child: DropdownButton<PlantHarvestType>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AHSColors.textSoft,
            ),
            items: PlantHarvestType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.label,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: AHSColors.textDark,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    );
  }
}

/// Compact bar used in the top AppBar row
class _BatteryTopBarWidget extends StatelessWidget {
  final double percent;
  const _BatteryTopBarWidget({required this.percent});

  Color get _color {
    if (percent > 50) return AHSColors.stable;
    if (percent > 20) return AHSColors.warning;
    return AHSColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Body shell
        Container(
          width: 28,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _color, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  color: _color.withAlpha(200),
                ),
              ),
            ),
          ),
        ),
        // Positive terminal nub
        Container(
          width: 3,
          height: 6,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(1.5),
              bottomRight: Radius.circular(1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Larger battery bar used inside the dialog
class _BatteryDialogWidget extends StatelessWidget {
  final double percent;
  const _BatteryDialogWidget({required this.percent});

  Color get _color {
    if (percent > 50) return AHSColors.stable;
    if (percent > 20) return AHSColors.warning;
    return AHSColors.critical;
  }

  String get _label {
    if (percent <= 0) return '0%';
    return '${percent.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Track
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: AHSColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Fill
                  FractionallySizedBox(
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 700),
                      height: 24,
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: _color.withAlpha(80), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Terminal nub
            Container(
              width: 6,
              height: 12,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ],
    );
  }
}
