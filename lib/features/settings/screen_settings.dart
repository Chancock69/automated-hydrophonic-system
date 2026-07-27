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
      if (!mounted) return;
      setState(() {
        _soundAlerts = sound != 'false';
        _systemNotifications = notifications != 'false';
        _stats = stats;
        _batteryPercent = battery;
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
        // Compact action cards — 2 rows × 2
        _SettingsCompactCard(
          icon: Icons.cloud_outlined,
          title: 'Firebase',
          subtitle: _testingConnection ? 'Checking…' : 'Test source',
          onTap: _testingConnection ? null : _testFirebase,
          trailing: _testingConnection
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const SizedBox(height: 8),
        _SettingsCompactCard(
          icon: Icons.storage_outlined,
          title: 'Local data',
          subtitle:
              '${_stats['plants'] ?? 0} plants · '
              '${_stats['sensorLogs'] ?? 0} readings',
          onTap: reload,
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
          subtitle: 'Version 1.0.0 · Chamber 01',
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
  final Widget? trailing;

  const _SettingsCompactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AHSColors.primary,
    this.onTap,
    this.trailing,
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
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ] else if (onTap != null) ...[
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
