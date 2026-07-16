import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/solar_data.dart';
import '../models/notification.dart';
import '../models/settings.dart';
import '../services/notification_sound_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_delivery_service.dart';

class SolarService {
  final NotificationSoundService _notificationSound = NotificationSoundService();
  static const String _solarDataKey = 'solar_data';
  static const String _notificationsKey = 'notifications';
  static const String _settingsKey = 'settings';
  // Keep track of when we last sent each kind of notification to avoid repeats
  final Map<String, DateTime> _lastNotificationAt = {};
  // Default cooldown between identical notifications
  Duration _notificationCooldown = const Duration(minutes: 5);
  
  // Fetch solar data
  Future<List<SolarData>> getSolarData() async {
    // In a real app, you would make an API call here
    // This is just a simulation for demo purposes
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString(_solarDataKey);
    
    if (dataJson != null) {
      final List<dynamic> dataList = json.decode(dataJson);
      return dataList.map((json) => SolarData.fromJson(json)).toList();
    }
    
    // Generate some initial data if none exists
    final List<SolarData> initialData = _generateRandomData();
    await _saveSolarData(initialData);
    return initialData;
  }
  
  // Generate random solar data for demo purposes
  List<SolarData> _generateRandomData() {
    final Random random = Random();
    final List<SolarData> data = [];
    final now = DateTime.now();
    
    for (int i = 0; i < 24; i++) {
      final voltage = 12.0 + random.nextDouble() * 5.0;
      final current = 1.0 + random.nextDouble() * 4.0;
      final power = voltage * current;
      
      data.add(SolarData(
        voltage: voltage,
        current: current,
        power: power,
        timestamp: now.subtract(Duration(hours: 24 - i)),
      ));
    }
    
    return data;
  }
  
  // Save solar data
  Future<void> _saveSolarData(List<SolarData> data) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = data.map((item) => item.toJson()).toList();
    await prefs.setString(_solarDataKey, json.encode(jsonList));
  }
  
  // Add a new solar data point
  Future<void> addSolarData(SolarData data) async {
    final List<SolarData> existingData = await getSolarData();
    existingData.add(data);
    
    // Keep only the last 24 hours of data
    if (existingData.length > 24) {
      existingData.removeAt(0);
    }
    
    await _saveSolarData(existingData);
    
    // Check if the new data point requires a notification
    final settings = await getSettings();
    if (data.voltage < settings.minVoltage) {
      await addNotification(
        SolarNotification(
          title: 'Tegangan di bawah batas',
          message: 'Tegangan (${data.voltage.toStringAsFixed(2)} V) di bawah batas minimum (${settings.minVoltage.toStringAsFixed(2)} V)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    } else if (data.current > settings.maxCurrent) {
      await addNotification(
        SolarNotification(
          title: 'Arus melebihi batas',
          message: 'Arus (${data.current.toStringAsFixed(2)} A) melebihi batas maksimum (${settings.maxCurrent.toStringAsFixed(2)} A)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
  }

  /// Cek threshold dan tambahkan notifikasi jika melewati batas (untuk data realtime dari Firebase).
  Future<void> checkThresholdsAndNotify(SolarData data, Settings settings) async {
    if (data.voltage < settings.minVoltage) {
      await addNotification(
        SolarNotification(
          title: 'Tegangan di bawah batas',
          message: 'Tegangan (${data.voltage.toStringAsFixed(2)} V) di bawah batas minimum (${settings.minVoltage.toStringAsFixed(2)} V)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
    if (data.voltage > settings.maxVoltage) {
      await addNotification(
        SolarNotification(
          title: 'Tegangan melebihi batas',
          message: 'Tegangan (${data.voltage.toStringAsFixed(2)} V) melebihi batas maksimum (${settings.maxVoltage.toStringAsFixed(2)} V)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
    if (data.current < settings.minCurrent) {
      await addNotification(
        SolarNotification(
          title: 'Arus di bawah batas',
          message: 'Arus (${data.current.toStringAsFixed(2)} A) di bawah batas minimum (${settings.minCurrent.toStringAsFixed(2)} A)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
    if (data.current > settings.maxCurrent) {
      await addNotification(
        SolarNotification(
          title: 'Arus melebihi batas',
          message: 'Arus (${data.current.toStringAsFixed(2)} A) melebihi batas maksimum (${settings.maxCurrent.toStringAsFixed(2)} A)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
    if (data.power < settings.minPower) {
      await addNotification(
        SolarNotification(
          title: 'Daya di bawah batas',
          message: 'Daya (${data.power.toStringAsFixed(2)} W) di bawah batas minimum (${settings.minPower.toStringAsFixed(2)} W)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
    if (data.power > settings.maxPower) {
      await addNotification(
        SolarNotification(
          title: 'Daya melebihi batas',
          message: 'Daya (${data.power.toStringAsFixed(2)} W) melebihi batas maksimum (${settings.maxPower.toStringAsFixed(2)} W)',
          timestamp: DateTime.now(),
          type: NotificationType.warning,
        ),
      );
    }
  }
  
  // Get notifications
  Future<List<SolarNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString(_notificationsKey);
    
    if (notificationsJson != null) {
      final List<dynamic> notificationsList = json.decode(notificationsJson);
      return notificationsList.map((json) => SolarNotification.fromJson(json)).toList();
    }
    
    return [];
  }
  
  // Add a notification
  Future<void> addNotification(SolarNotification notification) async {
    // Update cooldown from settings (so user-set value is respected)
    try {
      final settings = await getSettings();
      _notificationCooldown = Duration(minutes: settings.notificationCooldownMinutes);
    } catch (_) {
      // ignore and use existing cooldown
    }

    // Build a key for this notification type/title so we can debounce repeats
    final key = '${notification.type}_${notification.title}';
    final now = DateTime.now();

    // If we sent the same notification recently, skip to avoid repeating
    final last = _lastNotificationAt[key];
    if (last != null && now.difference(last) < _notificationCooldown) {
      // Skip adding/playing for repeated notifications within the cooldown
      return;
    }

    // Record this notification timestamp
    _lastNotificationAt[key] = now;

    final List<SolarNotification> existingNotifications = await getNotifications();
    existingNotifications.add(notification);
    
    // Keep only the latest 50 notifications
    if (existingNotifications.length > 50) {
      existingNotifications.removeAt(0);
    }
    
    await _saveNotifications(existingNotifications);
    
    // Play notification sound
    await _notificationSound.playNotificationSound();
    
    // Tampilkan notifikasi pop-up di HP
    await LocalNotificationService().showNotification(notification.title, notification.message);
    // Kirim ke Telegram / Webhook (WhatsApp, Google Assistant, IFTTT)
    final settings = await getSettings();
    await NotificationDeliveryService().deliver(notification, settings);
  }
  
  // Save notifications
  Future<void> _saveNotifications(List<SolarNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = notifications.map((item) => item.toJson()).toList();
    await prefs.setString(_notificationsKey, json.encode(jsonList));
  }
  
  // Get settings
  Future<Settings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    
    if (settingsJson != null) {
      final Map<String, dynamic> settingsMap = json.decode(settingsJson);
      return Settings.fromJson(settingsMap);
    }
    
    // Return default settings if none exist
    return Settings();
  }
  
  // Save settings
  Future<void> saveSettings(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }
  
  // Generate a new data point (for demo/simulation purposes)
  Future<SolarData> generateNewDataPoint() async {
    final Random random = Random();
    final settings = await getSettings();
    
    // Generate values within the set thresholds with some random variation
    final double voltage = settings.minVoltage + 
        random.nextDouble() * (settings.maxVoltage - settings.minVoltage);
    
    final double current = settings.minCurrent + 
        random.nextDouble() * (settings.maxCurrent - settings.minCurrent);
    
    final double power = voltage * current;
    
    final SolarData newData = SolarData(
      voltage: voltage,
      current: current,
      power: power,
      timestamp: DateTime.now(),
    );
    
    await addSolarData(newData);
    return newData;
  }
} 