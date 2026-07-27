import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/harvest_event.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/features/analytics/screen_analytics.dart';
import 'package:ahs/features/logs/screen_logs.dart';
import 'package:ahs/shared/widgets/app_ui.dart';

class HarvestHistoryScreen extends StatefulWidget {
  final List<PlantModel> plants;
  final bool embedded;

  const HarvestHistoryScreen({
    super.key,
    required this.plants,
    this.embedded = false,
  });

  @override
  State<HarvestHistoryScreen> createState() => _HarvestHistoryScreenState();
}

class _HarvestHistoryScreenState extends State<HarvestHistoryScreen> {
  late Future<List<HarvestEvent>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getHarvestEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDetails(HarvestEvent event, PlantModel? plant) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HarvestDetailsSheet(event: event, plant: plant),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: FutureBuilder<List<HarvestEvent>>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final events = snap.data ?? const <HarvestEvent>[];
            final filteredEvents = _filterEvents(events);
            final doneCount = _donePlantCount(events);

            if (widget.embedded) {
              return _buildEmbedded(context, loading: loading, events: events);
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: AhsPageHeader(
                      title: 'Harvest History',
                      subtitle: 'Weight, survival, and completed batches',
                      onBack: widget.embedded
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ),
                ),
                if (loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (events.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HarvestEmpty(),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: _HarvestSearchPanel(
                        controller: _searchController,
                        query: _query,
                        doneCount: doneCount,
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                  ),
                  if (filteredEvents.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoHarvestSearchResults(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: filteredEvents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final event = filteredEvents[index];
                          final plant = widget.plants
                              .where((plant) => plant.id == event.plantId)
                              .firstOrNull;
                          return _HarvestTile(
                            event: event,
                            plant: plant,
                            onDetails: () => _openDetails(event, plant),
                            onAnalytics: plant == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AnalyticsScreen(plant: plant),
                                    ),
                                  ),
                            onLogs: plant == null
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LogsScreen(plant: plant),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmbedded(
    BuildContext context, {
    required bool loading,
    required List<HarvestEvent> events,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return const _HarvestEmpty();
    }
    final filteredEvents = _filterEvents(events);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HarvestSearchPanel(
            controller: _searchController,
            query: _query,
            doneCount: _donePlantCount(events),
            onChanged: (value) => setState(() => _query = value),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filteredEvents.isEmpty
                ? const _NoHarvestSearchResults()
                : ListView.separated(
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final event = filteredEvents[index];
                      final plant = widget.plants
                          .where((item) => item.id == event.plantId)
                          .firstOrNull;
                      return _HarvestTile(
                        event: event,
                        plant: plant,
                        onDetails: () => _openDetails(event, plant),
                        onAnalytics: plant == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnalyticsScreen(plant: plant),
                                ),
                              ),
                        onLogs: plant == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LogsScreen(plant: plant),
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<HarvestEvent> _filterEvents(List<HarvestEvent> events) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return events;
    return events.where((event) {
      final date = DateFormat('MMM d, y').format(event.harvestedAt);
      final status = event.markedDone ? 'done completed ended' : 'continuing';
      final text = '${event.plantName} $date $status ${event.plantId}'
          .toLowerCase();
      return text.contains(query);
    }).toList();
  }

  int _donePlantCount(List<HarvestEvent> events) {
    final ids = <int>{};
    for (final event in events) {
      if (event.markedDone) ids.add(event.plantId);
    }
    return ids.length;
  }
}

class _HarvestSearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final int doneCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _HarvestSearchPanel({
    required this.controller,
    required this.query,
    required this.doneCount,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search harvest history',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AHSColors.stable.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AHSColors.stable.withAlpha(45)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AHSColors.stable.withAlpha(24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.done_all_rounded,
                    color: AHSColors.stable,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Plants done',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AHSColors.textDark,
                    ),
                  ),
                ),
                Text(
                  '$doneCount',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AHSColors.stable,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestTile extends StatelessWidget {
  final HarvestEvent event;
  final PlantModel? plant;
  final VoidCallback onDetails;
  final VoidCallback? onAnalytics;
  final VoidCallback? onLogs;

  const _HarvestTile({
    required this.event,
    required this.plant,
    required this.onDetails,
    required this.onAnalytics,
    required this.onLogs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AHSColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AHSColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              event.markedDone ? Icons.done_all_rounded : Icons.refresh_rounded,
              color: event.markedDone ? AHSColors.warning : AHSColors.stable,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.plantName,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('MMM d, y').format(event.harvestedAt)} - ${event.survivedCount}/${event.totalCount} survived - ${event.lifeRate.toStringAsFixed(0)}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AHSColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${event.weightKg.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AHSColors.primary,
            ),
          ),
          if (plant != null) ...[
            const SizedBox(width: 8),
            _HistoryIconButton(
              icon: Icons.visibility_rounded,
              color: AHSColors.primary,
              onTap: onDetails,
            ),
            const SizedBox(width: 6),
            _HistoryIconButton(
              icon: Icons.insights_rounded,
              color: AHSColors.primaryMid,
              onTap: onAnalytics,
            ),
            const SizedBox(width: 6),
            _HistoryIconButton(
              icon: Icons.receipt_long_rounded,
              color: AHSColors.textMid,
              onTap: onLogs,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _HistoryIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

class _HarvestDetailsSheet extends StatelessWidget {
  final HarvestEvent event;
  final PlantModel? plant;

  const _HarvestDetailsSheet({required this.event, required this.plant});

  @override
  Widget build(BuildContext context) {
    final p = plant;
    final planned = p?.harvestDate;
    final actual = p?.actualHarvestDate ?? event.harvestedAt;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        18 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AHSColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AHSColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AHSColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    color: AHSColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.plantName,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AHSColors.textDark,
                        ),
                      ),
                      const Text(
                        'View-only harvest record',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AHSColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(
              label: 'Description',
              value: p?.description.isEmpty ?? true
                  ? 'No description'
                  : p!.description,
            ),
            _DetailRow(
              label: 'Planted',
              value: p == null
                  ? '--'
                  : DateFormat('MMM d, y').format(p.addedDate),
            ),
            _DetailRow(
              label: 'Planned End',
              value: planned == null
                  ? '--'
                  : DateFormat('MMM d, y').format(planned),
            ),
            _DetailRow(
              label: 'Harvested',
              value: DateFormat('MMM d, y').format(actual),
            ),
            _DetailRow(
              label: 'Harvest Type',
              value:
                  p?.harvestType.label ??
                  (event.markedDone ? 'Ended' : 'Multi harvest'),
            ),
            _DetailRow(
              label: 'Weight',
              value: '${event.weightKg.toStringAsFixed(1)} kg',
            ),
            _DetailRow(
              label: 'Survival',
              value:
                  '${event.survivedCount}/${event.totalCount} plants - ${event.lifeRate.toStringAsFixed(0)}%',
            ),
            _DetailRow(
              label: 'Status',
              value: event.markedDone ? 'Harvest ended' : 'Growing continues',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHarvestSearchResults extends StatelessWidget {
  const _NoHarvestSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AHSColors.primaryGlow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AHSColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching harvests',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another plant name, date, or status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AHSColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AHSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AHSColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HarvestEmpty extends StatelessWidget {
  const _HarvestEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 42),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.agriculture_rounded,
              size: 58,
              color: AHSColors.textHint,
            ),
            SizedBox(height: 18),
            Text(
              'No harvest records yet',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Harvest weight, survival rate, and completed batches will appear here.',
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
}
