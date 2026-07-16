import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/solar_provider.dart';
import '../models/notification.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final solarProvider = Provider.of<SolarProvider>(context);
    final notifications = solarProvider.notifications;
    final now = DateTime.now();
    final today = <SolarNotification>[];
    final yesterday = <SolarNotification>[];
    for (final notif in notifications) {
      if (_isSameDay(notif.timestamp, now)) {
        today.add(notif);
      } else if (_isSameDay(notif.timestamp, now.subtract(const Duration(days: 1)))) {
        yesterday.add(notif);
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
            Icon(Icons.notifications, color: Colors.black),
            const SizedBox(width: 16),
          ],
        ),
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (today.isNotEmpty) ...[
                  const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...today.map((n) => _buildNotificationCard(context, n)),
                  const SizedBox(height: 18),
                ],
                if (yesterday.isNotEmpty) ...[
                  const Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...yesterday.map((n) => _buildNotificationCard(context, n)),
                ],
              ],
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64.0,
            color: Colors.grey,
          ),
          SizedBox(height: 16.0),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            'You will see notifications about system events here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, SolarNotification notification) {
    Color cardColor;
    Color iconColor;
    IconData iconData;
    switch (notification.type) {
      case NotificationType.warning:
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        iconData = Icons.warning_amber_rounded;
        break;
      case NotificationType.error:
        cardColor = Colors.red.shade50;
        iconColor = Colors.red;
        iconData = Icons.error_outline;
        break;
      case NotificationType.info:
      default:
        cardColor = Colors.green.shade50;
        iconColor = Colors.green;
        iconData = Icons.check_circle_outline;
        break;
    }
    final timeFormat = DateFormat('h:mm a');
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: iconColor, size: 28.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Text(
                notification.message,
                style: const TextStyle(fontSize: 15.0),
              ),
            ),
            const SizedBox(height: 12.0),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Text(
                timeFormat.format(notification.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 