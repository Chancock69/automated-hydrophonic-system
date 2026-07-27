import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/plant_slot.dart';
import 'package:ahs/shared/widgets/app_ui.dart';

class PlantAreaScreen extends StatefulWidget {
  final PlantModel plant;

  const PlantAreaScreen({super.key, required this.plant});

  @override
  State<PlantAreaScreen> createState() => _PlantAreaScreenState();
}

class _PlantAreaScreenState extends State<PlantAreaScreen> {
  late PlantModel _plant = widget.plant;
  List<PlantSlot> _slots = [];
  bool _loading = true;
  bool _saving = false;
  PlantSlot? _moveSource;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plantId = _plant.id;
    if (plantId == null) return;
    try {
      final plants = await DatabaseHelper.instance.getAllPlants();
      final current = plants.where((plant) => plant.id == plantId).firstOrNull;
      final slots = await DatabaseHelper.instance.getPlantSlots(plantId);
      if (!mounted) return;
      setState(() {
        _plant = current ?? _plant;
        _slots = slots;
        _moveSource = _moveSource == null
            ? null
            : slots
                  .where((slot) => slot.position == _moveSource!.position)
                  .firstOrNull;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Unable to load plant area. Please try again.');
    }
  }

  Future<void> _changeQuantity(int delta) async {
    final next = (_plant.quantity + delta).clamp(1, 6);
    if (next == _plant.quantity) return;
    final ok = await _confirm(
      title: 'Update quantity?',
      body:
          'This will change "${_plant.name}" from ${_plant.quantity} to $next planted position${next == 1 ? '' : 's'}.',
      action: 'Update',
    );
    if (!ok) return;

    await _guardedSave(() async {
      await DatabaseHelper.instance.updatePlantQuantity(_plant, next);
      await _load();
    });
  }

  Future<void> _toggleSlot(PlantSlot slot) async {
    if (_moveSource != null) {
      await _moveSlot(slot);
      return;
    }
    if (slot.status == PlantSlotStatus.empty) return;
    final next = slot.status == PlantSlotStatus.alive
        ? PlantSlotStatus.dead
        : PlantSlotStatus.alive;
    final ok = await _confirm(
      title: 'Mark position ${slot.position} as ${next.label}?',
      body:
          'This updates the survival record used for harvest life-rate analytics.',
      action: 'Mark ${next.label}',
      danger: next == PlantSlotStatus.dead,
    );
    if (!ok) return;

    await _guardedSave(() async {
      await DatabaseHelper.instance.updatePlantSlotStatus(
        slot.plantId,
        slot.position,
        next,
      );
      await _load();
    });
  }

  void _selectMoveSource(PlantSlot slot) {
    if (_saving || slot.status == PlantSlotStatus.empty) return;
    setState(() => _moveSource = slot);
  }

  Future<void> _moveSlot(PlantSlot target) async {
    final source = _moveSource;
    if (source == null) return;

    if (source.position == target.position) {
      setState(() => _moveSource = null);
      return;
    }

    final ok = await _confirm(
      title: 'Move ${source.status.label} plant?',
      body:
          'Position ${source.position} and Position ${target.position} will exchange their area status. This helps keep the plant map accurate when plants are rearranged.',
      action: 'Move',
    );
    if (!ok) return;

    await _guardedSave(() async {
      await DatabaseHelper.instance.swapPlantSlotStatuses(
        source.plantId,
        source.position,
        target.position,
      );
      setState(() => _moveSource = null);
      await _load();
    });
  }

  Future<void> _guardedSave(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      _showError('Unable to save plant area changes. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AHSColors.critical),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alive = _slots
        .where((slot) => slot.status == PlantSlotStatus.alive)
        .length;
    final dead = _slots
        .where((slot) => slot.status == PlantSlotStatus.dead)
        .length;
    final lifeRate = _plant.quantity == 0
        ? 0.0
        : (alive / _plant.quantity) * 100;

    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: AhsPageHeader(
                        title: 'Plant Area',
                        subtitle: _plant.name,
                        onBack: () => Navigator.pop(context, true),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _AreaSummary(
                        quantity: _plant.quantity,
                        alive: alive,
                        dead: dead,
                        lifeRate: lifeRate,
                        onDecrease: () => _changeQuantity(-1),
                        onIncrease: () => _changeQuantity(1),
                        enabled: !_saving,
                      ),
                    ),
                  ),
                  if (_moveSource != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _MoveBanner(
                          source: _moveSource!,
                          onCancel: () => setState(() => _moveSource = null),
                        ),
                      ),
                    ),
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final narrow = width < 390;
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: narrow ? 1 : 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: narrow ? 2.35 : 1.05,
                              ),
                          delegate: SliverChildBuilderDelegate((_, index) {
                            final slot = _slots[index];
                            return _SlotCard(
                              slot: slot,
                              enabled: !_saving,
                              selected: _moveSource?.position == slot.position,
                              moving: _moveSource != null,
                              onTap: () => _toggleSlot(slot),
                              onMove: () => _selectMoveSource(slot),
                            ).animate().fadeIn(delay: (index * 35).ms);
                          }, childCount: _slots.length),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _AreaSummary extends StatelessWidget {
  final int quantity;
  final int alive;
  final int dead;
  final double lifeRate;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool enabled;

  const _AreaSummary({
    required this.quantity,
    required this.alive,
    required this.dead,
    required this.lifeRate,
    required this.onDecrease,
    required this.onIncrease,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Planted Quantity',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: enabled ? onDecrease : null,
                icon: const Icon(Icons.remove_rounded),
                color: AHSColors.primary,
              ),
              Text(
                '$quantity / 6',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.primary,
                ),
              ),
              IconButton(
                onPressed: enabled ? onIncrease : null,
                icon: const Icon(Icons.add_rounded),
                color: AHSColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 330;
              final stats = [
                _MiniStat(
                  label: 'Alive',
                  value: alive,
                  color: AHSColors.stable,
                ),
                _MiniStat(
                  label: 'Dead',
                  value: dead,
                  color: AHSColors.critical,
                ),
                _MiniStat(
                  label: 'Life Rate',
                  value: lifeRate.round(),
                  suffix: '%',
                  color: AHSColors.primaryMid,
                ),
              ];
              if (!narrow) {
                return Row(
                  children: [
                    Expanded(child: stats[0]),
                    const SizedBox(width: 8),
                    Expanded(child: stats[1]),
                    const SizedBox(width: 8),
                    Expanded(child: stats[2]),
                  ],
                );
              }
              return Column(
                children: [
                  for (final stat in stats) ...[
                    stat,
                    if (stat != stats.last) const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value$suffix',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
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
    );
  }
}

class _MoveBanner extends StatelessWidget {
  final PlantSlot source;
  final VoidCallback onCancel;

  const _MoveBanner({required this.source, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final color = source.status == PlantSlotStatus.dead
        ? AHSColors.critical
        : AHSColors.stable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(Icons.open_with_rounded, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Move ${source.status.label} from Position ${source.position}. Tap the new position.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final PlantSlot slot;
  final VoidCallback onTap;
  final VoidCallback onMove;
  final bool enabled;
  final bool selected;
  final bool moving;

  const _SlotCard({
    required this.slot,
    required this.enabled,
    required this.selected,
    required this.moving,
    required this.onTap,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (slot.status) {
      PlantSlotStatus.alive => AHSColors.stable,
      PlantSlotStatus.dead => AHSColors.critical,
      PlantSlotStatus.empty => AHSColors.textHint,
    };
    final icon = switch (slot.status) {
      PlantSlotStatus.alive => Icons.eco_rounded,
      PlantSlotStatus.dead => Icons.close_rounded,
      PlantSlotStatus.empty => Icons.radio_button_unchecked_rounded,
    };
    final canMove = enabled && slot.status != PlantSlotStatus.empty && !moving;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AHSColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AHSColors.primary : color.withAlpha(90),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AHSColors.primary.withAlpha(35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(height: 8),
            Text(
              'Position ${slot.position}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AHSColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              moving && !selected ? 'Tap to move here' : slot.status.label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: moving && !selected ? AHSColors.primary : color,
              ),
            ),
            if (canMove) ...[
              const SizedBox(height: 9),
              GestureDetector(
                onTap: onMove,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AHSColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_with_rounded,
                        color: AHSColors.primary,
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Move',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AHSColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
