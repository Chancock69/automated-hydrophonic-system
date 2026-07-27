import 'dart:async';

import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/features/dashboard/screen_dashboard.dart';
import 'package:ahs/features/harvest/screen_harvest_history.dart';
import 'package:ahs/features/notifications/screen_notifications.dart';
import 'package:ahs/features/settings/screen_settings.dart';
import 'package:ahs/features/status/screen_status.dart';
import 'package:ahs/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _monitorKey = GlobalKey<_ActiveMonitorTabState>();
  final _notificationsKey = GlobalKey<NotificationsScreenState>();
  final _historyKey = GlobalKey<_HistoryTabState>();
  final _settingsKey = GlobalKey<SettingsScreenState>();
  Timer? _unreadTimer;
  int _selectedIndex = 0;
  int _unreadCount = 0;

  static const _titles = [
    'Automated Hydrophonic System',
    'Live Monitoring',
    'Notifications',
    'Harvest History',
    'App Settings',
  ];

  static const _subtitles = [
    '',
    'Current chamber sensor readings',
    'Sensor alerts and chamber updates',
    'Weight, survival, and completed batches',
    'Monitoring, storage, and device preferences',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_refreshUnreadCount());
    unawaited(_requestNotificationPermissionOnce());
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshUnreadCount()),
    );
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestNotificationPermissionOnce() async {
    final requested = await DatabaseHelper.instance.getAppSetting(
      'notificationPermissionRequested',
    );
    if (requested == 'true') return;
    await NotificationService.instance.requestPermission();
    await DatabaseHelper.instance.setAppSetting(
      'notificationPermissionRequested',
      'true',
    );
  }

  Future<void> _refreshUnreadCount() async {
    final count = await DatabaseHelper.instance.getUnreadNotificationCount();
    if (mounted && count != _unreadCount) {
      setState(() => _unreadCount = count);
    }
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) _monitorKey.currentState?.reload();
    if (index == 2) _notificationsKey.currentState?.reload();
    if (index == 3) _historyKey.currentState?.reload();
    if (index == 4) _settingsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 390;
    final subtitle = _selectedIndex == 0
        ? DateFormat('EEEE, MMM d').format(DateTime.now())
        : _subtitles[_selectedIndex];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) _selectTab(0);
      },
      child: Scaffold(
        backgroundColor: AHSColors.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: compact ? 64 : 72,
          backgroundColor: AHSColors.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: compact ? 12 : 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _titles[_selectedIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: compact ? 18 : null),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const DashboardScreen(),
            _ActiveMonitorTab(key: _monitorKey, active: _selectedIndex == 1),
            NotificationsScreen(
              key: _notificationsKey,
              onUnreadChanged: (count) {
                if (mounted && count != _unreadCount) {
                  setState(() => _unreadCount = count);
                }
              },
            ),
            _HistoryTab(key: _historyKey),
            SettingsScreen(key: _settingsKey),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          height: compact ? 62 : 68,
          labelBehavior: compact
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          backgroundColor: AHSColors.bgCard,
          indicatorColor: AHSColors.primaryGlow,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart_rounded),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                ),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                ),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveMonitorTab extends StatefulWidget {
  final bool active;

  const _ActiveMonitorTab({super.key, required this.active});

  @override
  State<_ActiveMonitorTab> createState() => _ActiveMonitorTabState();
}

class _ActiveMonitorTabState extends State<_ActiveMonitorTab> {
  PlantModel? _activePlant;
  bool _loading = true;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final plant = await DatabaseHelper.instance.getActivePlant();
      if (!mounted) return;
      setState(() {
        _activePlant = plant;
        _loading = false;
        _generation++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _TabMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load monitoring',
        message: 'Check the local database, then try again.',
        actionLabel: 'Try again',
        onAction: reload,
      );
    }

    final plant = _activePlant;
    if (plant == null) {
      return _TabMessage(
        icon: Icons.energy_savings_leaf_outlined,
        title: 'No active plant',
        message:
            'Set a plant as active from Home before opening live monitoring.',
        actionLabel: 'Check again',
        onAction: reload,
      );
    }

    return StatusScreen(
      key: ValueKey('${plant.id}-$_generation'),
      plant: plant,
      embedded: true,
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({super.key});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<PlantModel> _plants = const [];
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);
    try {
      final plants = await DatabaseHelper.instance.getAllPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _loading = false;
        _generation++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return HarvestHistoryScreen(
      key: ValueKey(_generation),
      plants: _plants,
      embedded: true,
    );
  }
}

class _TabMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _TabMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AHSColors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AHSColors.primary, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
