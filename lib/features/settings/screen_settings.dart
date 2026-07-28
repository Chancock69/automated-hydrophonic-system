import 'dart:async';

import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/remote/firebase_http.dart';
import 'package:ahs/services/notification_service.dart';
import 'package:ahs/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  bool _soundAlerts = true;
  bool _systemNotifications = true;
  double _batteryPercent = 100;
  Map<String, int> _stats = const {'plants': 0, 'sensorLogs': 0, 'harvests': 0};
  bool _loading = true;
  bool _testingConnection = false;
  String? _firebaseStatus;
  String? _firebaseLastSyncedAt;
  String? _firebaseLatestPath;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    try {
      final sound = await DatabaseHelper.instance.getAppSetting('soundAlerts');
      final notifications = await DatabaseHelper.instance.getAppSetting(
        'systemNotifications',
      );
      final stats = await DatabaseHelper.instance.getStorageStats();
      final battery = await DatabaseHelper.instance.getBatteryPercent();
      final firebaseStatus = await DatabaseHelper.instance.getAppSetting(
        'firebaseLastStatus',
      );
      final firebaseLastSyncedAt = await DatabaseHelper.instance.getAppSetting(
        'firebaseLastSyncedAt',
      );
      final firebaseLatestPath = await DatabaseHelper.instance.getAppSetting(
        'firebaseLatestPath',
      );
      if (!mounted) return;
      setState(() {
        _soundAlerts = sound != 'false';
        _systemNotifications = notifications != 'false';
        _stats = stats;
        _batteryPercent = battery;
        _firebaseStatus = firebaseStatus;
        _firebaseLastSyncedAt = firebaseLastSyncedAt;
        _firebaseLatestPath = firebaseLatestPath;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setSoundAlerts(bool value) async {
    setState(() => _soundAlerts = value);
    await DatabaseHelper.instance.setAppSetting('soundAlerts', '$value');
  }

  Future<void> _setSystemNotifications(bool value) async {
    if (value) {
      await NotificationService.instance.requestPermission();
    }
    if (!mounted) return;
    setState(() => _systemNotifications = value);
    await DatabaseHelper.instance.setAppSetting(
      'systemNotifications',
      '$value',
    );
  }

  Future<void> _testFirebase() async {
    if (_testingConnection) return;
    setState(() => _testingConnection = true);
    try {
      final snapshot = await FirebaseHttp.instance.fetchLatest();
      if (!mounted) return;
      final online =
          snapshot != null &&
          !DateTime.now().difference(snapshot.timestamp).isNegative &&
          DateTime.now().difference(snapshot.timestamp) <=
              const Duration(minutes: 2);
      _showMessage(
        snapshot == null
            ? 'Firebase responded, but no sensor reading was found.'
            : online
            ? 'Firebase is working and ESP32 data is live.'
            : 'Firebase is working, but ESP32 appears offline.',
      );
      await DatabaseHelper.instance.saveFirebaseSync(
        syncedAt: DateTime.now(),
        path: snapshot == null
            ? '/'
            : '/${snapshot.timestamp.year}/${snapshot.timestamp.month.toString().padLeft(2, '0')}/${snapshot.timestamp.day.toString().padLeft(2, '0')}',
        online: online,
      );
      await reload();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Firebase could not be reached. Check Wi-Fi and configuration.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _markCharged() async {
    await DatabaseHelper.instance.resetBattery();
    await reload();
    _showMessage('Device battery marked as fully charged.');
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showAhsConfirmDialog(
      context: context,
      title: 'Delete all local data?',
      message:
          'This will remove plants, sensor logs, harvest history, and saved alerts from SQLite on this device.',
      confirmLabel: 'Delete data',
      destructive: true,
    );
    if (!confirmed) return;
    await DatabaseHelper.instance.clearLocalData();
    await reload();
    _showMessage('Local SQLite data cleared.');
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AHSColors.critical : AHSColors.textDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      physics: const BouncingScrollPhysics(),
      children: [
        _FirebaseControlPanel(
          status: _firebaseStatus,
          lastSyncedAt: _firebaseLastSyncedAt,
          latestPath: _firebaseLatestPath,
          testing: _testingConnection,
          onTest: _testingConnection ? null : _testFirebase,
        ),
        const SizedBox(height: 12),
        AhsPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              const _SettingRow(
                icon: Icons.sync_rounded,
                title: 'Live check interval',
                subtitle: 'Firebase is checked while Live is open',
                trailing: _FixedInterval(),
              ),
              const Divider(height: 14),
              _SettingRow(
                icon: Icons.volume_up_outlined,
                title: 'Audible alerts',
                subtitle: 'Sound when a sensor is out of range',
                trailing: Switch(
                  value: _soundAlerts,
                  onChanged: _setSoundAlerts,
                ),
              ),
              const Divider(height: 14),
              _SettingRow(
                icon: Icons.notifications_active_outlined,
                title: 'System notifications',
                subtitle: 'Show Android alerts for anomalies',
                trailing: Switch(
                  value: _systemNotifications,
                  onChanged: _setSystemNotifications,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCompactCard(
          icon: Icons.storage_outlined,
          title: 'Local data',
          subtitle:
              '${_stats['plants'] ?? 0} plants · '
              '${_stats['sensorLogs'] ?? 0} readings',
          onTap: _clearLocalData,
        ),
        const SizedBox(height: 8),
        _SettingsCompactCard(
          icon: _batteryPercent < 20
              ? Icons.battery_alert_rounded
              : Icons.battery_charging_full_rounded,
          iconColor: _batteryPercent < 20
              ? AHSColors.critical
              : AHSColors.primary,
          title: 'Device battery',
          subtitle:
              '${_batteryPercent.round().clamp(0, 100)}% · Tap to mark charged',
          onTap: _markCharged,
        ),
        const SizedBox(height: 8),
        const _SettingsCompactCard(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'Version 3 · Chamber 01',
        ),
      ],
    );
  }
}

class _FixedInterval extends StatelessWidget {
  const _FixedInterval();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AHSColors.primaryGlow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '10 sec',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AHSColors.primary,
        ),
      ),
    );
  }
}

class _FirebaseControlPanel extends StatelessWidget {
  final String? status;
  final String? lastSyncedAt;
  final String? latestPath;
  final bool testing;
  final VoidCallback? onTest;

  const _FirebaseControlPanel({
    required this.status,
    required this.lastSyncedAt,
    required this.latestPath,
    required this.testing,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final online = status == 'online';
    final color = online ? AHSColors.stable : AHSColors.warning;
    final synced = DateTime.tryParse(lastSyncedAt ?? '');
    return AhsPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Firebase Control Panel',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onTest,
                icon: testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Test'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FirebaseInfoRow(
            label: 'Status',
            value: online ? 'Connected' : status ?? 'Not checked',
          ),
          _FirebaseInfoRow(
            label: 'Last synced',
            value: synced == null
                ? 'No sync yet'
                : '${synced.month.toString().padLeft(2, '0')}-${synced.day.toString().padLeft(2, '0')}-${synced.year} ${synced.hour.toString().padLeft(2, '0')}:${synced.minute.toString().padLeft(2, '0')}',
          ),
          _FirebaseInfoRow(label: 'Latest path', value: latestPath ?? '/'),
        ],
      ),
    );
  }
}

class _FirebaseInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _FirebaseInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AHSColors.primaryGlow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AHSColors.primary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
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
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class _SettingsCompactCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsCompactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AHSColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AHSColors.bgCard,
        borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
        border: Border.all(color: AHSColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: AHSColors.textSoft,
              size: 18,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
      child: content,
    );
  }
}
