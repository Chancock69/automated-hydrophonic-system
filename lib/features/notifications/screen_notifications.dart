import 'dart:async';

import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/data/models/app_notification.dart';
import 'package:ahs/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final ValueChanged<int>? onUnreadChanged;

  const NotificationsScreen({super.key, this.onUnreadChanged});

  @override
  NotificationsScreenState createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);
    final notifications = await DatabaseHelper.instance.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _loading = false;
    });
    widget.onUnreadChanged?.call(_unreadCount);
  }

  int get _unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> _markRead(AppNotification notification) async {
    final id = notification.id;
    if (id == null || notification.isRead) return;
    await DatabaseHelper.instance.markNotificationRead(id);
    await reload();
  }

  Future<void> _markAllRead() async {
    await DatabaseHelper.instance.markAllNotificationsRead();
    await reload();
  }

  Future<void> _clearAll() async {
    final confirmed = await showAhsConfirmDialog(
      context: context,
      title: 'Clear all alerts?',
      message: 'This will permanently remove all saved notifications.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await DatabaseHelper.instance.clearNotifications();
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 430;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        10,
        compact ? 12 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AhsPanel(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AHSColors.primaryGlow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AHSColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_unreadCount unread',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_notifications.length} saved alerts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh notifications',
                  onPressed: reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (_unreadCount > 0)
                  IconButton(
                    tooltip: 'Mark all as read',
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all_rounded),
                  ),
                if (_notifications.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear alerts',
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _notifications.isEmpty
                ? const _EmptyNotifications()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () => _markRead(notification),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: notification.isRead
          ? notification.title
          : 'Unread: ${notification.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AHSTheme.panelRadius),
        child: AhsPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: notification.isRead
                          ? AHSColors.bg
                          : AHSColors.criticalGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sensors_rounded,
                      color: notification.isRead
                          ? AHSColors.textMid
                          : AHSColors.critical,
                    ),
                  ),
                  const Spacer(),
                  if (!notification.isRead)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AHSColors.critical,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                notification.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 17,
                    color: AHSColors.textSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'MM-dd-yyyy  h:mm a',
                      ).format(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    notification.isRead ? 'Read' : 'Tap to read',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AHSColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AHSColors.primaryGlow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 32,
                color: AHSColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Sensor alerts from the active chamber will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
