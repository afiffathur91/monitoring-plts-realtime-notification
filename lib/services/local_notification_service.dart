import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Layanan notifikasi lokal untuk menampilkan pop-up di HP saat batas ambang dilampaui.
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _idCounter = 0;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'plts_threshold_channel',
    'Notifikasi PLTS',
    channelDescription: 'Notifikasi saat tegangan/arus/daya melewati batas',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  static const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  /// Inisialisasi plugin. Panggil sekali di main.dart.
  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  void _onSelectNotification(NotificationResponse response) {
    // Bisa navigasi ke halaman notifikasi jika payload dipakai
  }

  /// Menampilkan notifikasi pop-up di HP (title + body).
  Future<void> showNotification(String title, String body) async {
    if (!_initialized) await initialize();

    final id = _idCounter++;
    if (_idCounter > 100000) _idCounter = 0;

    const details = NotificationDetails(
      android: _androidDetails,
      iOS: _iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }
}
