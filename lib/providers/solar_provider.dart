import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/solar_data.dart';
import '../models/notification.dart';
import '../models/settings.dart';
import '../services/solar_service.dart';
import '../services/export_service.dart';
import '../services/notification_sound_service.dart';
import '../services/firebase_database_service.dart';

class SolarProvider extends ChangeNotifier {
  /// Banyak titik terakhir yang diunduh dari Realtime DB untuk History/daftar.
  /// Hanya titik ini yang ada di memori — filter "Kemarin" kosong jika data lama
  /// sudah "tergeser" keluar dari jendela ini (bukan karena Firebase menghapus).
  static const int historyDataLimit = 10000;

  static const String _selectedDeviceKey = 'selected_device_id';
  final _firebaseDB = FirebaseDatabaseService();
  final SolarService _solarService = SolarService();
  final ExportService _exportService = ExportService();
  final NotificationSoundService _notificationSound = NotificationSoundService();
  
  List<SolarData> _solarData = [];
  List<SolarNotification> _notifications = [];
  Settings _settings = Settings();
  bool _isLoading = false;
  String? _error;
  String? _currentDeviceId;
  StreamSubscription<DatabaseEvent>? _deviceDataSubscription;
  StreamSubscription<DatabaseEvent>? _latestDataSubscription;
  bool _isRecoveringDevice = false;
  SolarData? _latestRealtime;
  
  // Data simulation timer
  Timer? _simulationTimer;
  
  List<SolarData> get solarData => _solarData;
  List<SolarNotification> get notifications => _notifications;
  Settings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Ambil data terbaru yang valid (hindari record terakhir yang kosong/0).
  // Fallback ke elemen terakhir jika semua record bernilai 0.
  SolarData? get latestData {
    // Kalau sudah ada stream khusus 1 data terbaru, gunakan itu untuk Dashboard/Realtime
    if (_latestRealtime != null) return _latestRealtime;
    if (_solarData.isEmpty) return null;
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final d = _solarData[i];
      final e = d.energy ?? 0;
      if (d.voltage != 0 || d.current != 0 || d.power != 0 || e != 0) {
        return d;
      }
    }
    return _solarData.last;
  }

  /// Ambil nilai terbaru yang "valid" per metrik (dipakai agar kartu metrik tidak tersangkut di sampel yang bernilai 0).
  double? get latestVoltage {
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final v = _solarData[i].voltage;
      if (v != 0) return v;
    }
    return null;
  }

  double? get latestCurrent {
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final v = _solarData[i].current;
      if (v != 0) return v;
    }
    return null;
  }

  double? get latestPower {
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final v = _solarData[i].power;
      if (v != 0) return v;
    }
    return null;
  }

  double? get latestEnergyWh {
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final v = _solarData[i].energy;
      if (v != null && v != 0) return v;
    }
    return null;
  }
  
  // Get voltage data points for chart
  List<SolarData> get voltageData => List.from(_solarData);
  
  // Get current data points for chart
  List<SolarData> get currentData => List.from(_solarData);
  
  // Get power data points for chart
  List<SolarData> get powerData => List.from(_solarData);
  
  String? get currentDeviceId => _currentDeviceId;

  SolarData? _latestValidFrom(List<SolarData> data) {
    for (int i = data.length - 1; i >= 0; i--) {
      final d = data[i];
      final energy = d.energy ?? 0;
      if (d.voltage != 0 || d.current != 0 || d.power != 0 || energy != 0) {
        return d;
      }
    }
    return null;
  }

  SolarData? get latestDataForVoltage {
    if (_solarData.isEmpty) return null;
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final d = _solarData[i];
      if (d.voltage != 0) return d;
    }
    return null;
  }

  SolarData? get latestDataForCurrent {
    if (_solarData.isEmpty) return null;
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final d = _solarData[i];
      if (d.current != 0) return d;
    }
    return null;
  }

  SolarData? get latestDataForPower {
    if (_solarData.isEmpty) return null;
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final d = _solarData[i];
      if (d.power != 0) return d;
    }
    return null;
  }

  SolarData? get latestDataForEnergyWh {
    if (_solarData.isEmpty) return null;
    for (int i = _solarData.length - 1; i >= 0; i--) {
      final d = _solarData[i];
      final e = d.energy;
      if (e != null && e != 0) return d;
    }
    return null;
  }
  
  // Initialize the provider
  Future<void> init({String? deviceId}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      if (deviceId != null && deviceId.isNotEmpty) {
        _currentDeviceId = deviceId;
        await _saveSelectedDeviceId(deviceId);
      } else {
        _currentDeviceId = await _getInitialDeviceId();
      }

      if (_currentDeviceId != null) {
        _listenToDeviceData();
      } else {
        // Fallback to local demo data if no device exists yet
        _solarData = await _solarService.getSolarData();
      }

      _notifications = await _solarService.getNotifications();
      _settings = await _solarService.getSettings();
      // Apply notification sound preference
      _notificationSound.toggleSound(_settings.notificationSoundEnabled);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Generate a new data point
  Future<void> generateNewDataPoint() async {
    try {
      // Generate a new data point
      await _solarService.generateNewDataPoint();
      
      // Update local data
      _solarData = await _solarService.getSolarData();
      _notifications = await _solarService.getNotifications();
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // Save new settings
  Future<void> saveSettings(Settings newSettings) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _solarService.saveSettings(newSettings);
      _settings = newSettings;
      // Apply immediately
      _notificationSound.toggleSound(newSettings.notificationSoundEnabled);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Refresh data
  Future<void> refreshData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _solarData = await _solarService.getSolarData();
      _notifications = await _solarService.getNotifications();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Clear all notifications - we'll just remove them one by one
  Future<void> clearAllNotifications() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // To clear notifications, we'll get the current list, then re-add a single notification and fetch again
      // This is a workaround since we don't have direct access to the private method
      if (_notifications.isNotEmpty) {
        // Create a temporary notification to reset the list
        final tempNotification = SolarNotification(
          title: 'Notifications Cleared',
          message: 'All notifications have been cleared',
          timestamp: DateTime.now(),
          type: NotificationType.info,
        );
        
        // Add the temporary notification
        await _solarService.addNotification(tempNotification);
        
        // Re-fetch notifications (should only contain our temp notification)
        _notifications = await _solarService.getNotifications();
        
        // Actually, let's clear this one too to have a clean slate
        if (_notifications.isNotEmpty) {
          await _solarService.addNotification(tempNotification);
          _notifications = [];
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Export data to CSV and share
  Future<void> exportDataToCSV() async {
    try {
      await _exportService.exportAndShareCSV(_solarData);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Export data to PDF and share
  Future<void> exportDataToPDF({String title = 'Laporan Data PLTS', List<SolarData>? data}) async {
    try {
      await _exportService.exportAndSharePDF(data ?? _solarData, title: title);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Export list tertentu ke CSV (untuk drill-down)
  Future<void> exportDataToCSVWith(List<SolarData> data) async {
    try {
      await _exportService.exportAndShareCSV(data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Export list tertentu ke PDF (untuk drill-down)
  Future<void> exportDataToPDFWith(List<SolarData> data, {String title = 'Laporan Data PLTS'}) async {
    try {
      await _exportService.exportAndSharePDF(data, title: title);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Toggle notification sound
  void toggleNotificationSound(bool enabled) {
    _notificationSound.toggleSound(enabled);
  }

  // Play notification sound
  Future<void> playNotificationSound() async {
    await _notificationSound.playNotificationSound();
  }

  // Dispose
  @override
  void dispose() {
    stopDataSimulation();
    _deviceDataSubscription?.cancel();
    _latestDataSubscription?.cancel();
    _notificationSound.dispose();
    super.dispose();
  }

  Future<String?> _fetchFirstDeviceId() async {
    final snapshot = await _firebaseDB.devicesRef.get().timeout(const Duration(seconds: 6));
    if (!snapshot.exists) return null;
    final data = snapshot.value;
    if (data is Map && data.isNotEmpty) {
      final normalized = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
      String? latestDeviceId;
      int latestLastSeen = -1;

      normalized.forEach((deviceId, rawValue) {
        if (rawValue is! Map) return;
        final valueMap = Map<String, dynamic>.from(
          rawValue.map((k, v) => MapEntry(k.toString(), v)),
        );
        final lastSeen = _parseLastSeen(valueMap['lastSeen']);
        if (lastSeen > latestLastSeen) {
          latestLastSeen = lastSeen;
          latestDeviceId = deviceId;
        }
      });

      // Fallback: jika tidak ada lastSeen valid, pakai device pertama.
      return latestDeviceId ?? normalized.keys.first;
    }
    return null;
  }

  int _parseLastSeen(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Future<String?> _getInitialDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_selectedDeviceKey);
    if (saved != null && saved.isNotEmpty) {
      try {
        final savedSnapshot =
            await _firebaseDB.devicesRef.child(saved).get().timeout(const Duration(seconds: 6));
        if (savedSnapshot.exists) {
          return saved;
        }
      } catch (_) {
        // Jika timeout/permission/network, jangan menggantung—lanjut fallback.
      }
    }
    String? latest;
    try {
      latest = await _fetchFirstDeviceId();
    } catch (_) {
      latest = null;
    }
    if (latest != null) {
      await _saveSelectedDeviceId(latest);
    }
    return latest;
  }

  Future<void> _saveSelectedDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDeviceKey, deviceId);
  }

  void _listenToDeviceData() {
    _deviceDataSubscription?.cancel();
    _latestDataSubscription?.cancel();
    final deviceId = _currentDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      _solarData = [];
      _latestRealtime = null;
      notifyListeners();
      return;
    }

    // Stream khusus untuk data TERBARU saja (anti-stuck untuk Dashboard/Real-time)
    _latestDataSubscription = _firebaseDB
        .deviceDataRef(deviceId)
        .limitToLast(1)
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      if (value is Map && value.isNotEmpty) {
        final entry = value.entries.first;
        if (entry.value is Map) {
          final map = Map<String, dynamic>.from(
            (entry.value as Map).map((k, v) => MapEntry(k.toString(), v)),
          );
          map.putIfAbsent('timestamp', () {
            final ts = int.tryParse(entry.key.toString());
            if (ts == null) return DateTime.now().millisecondsSinceEpoch;
            if (ts < 10000000000) return ts * 1000;
            return ts;
          });
          _latestRealtime = SolarData.fromJson(map);
          notifyListeners();
        }
      }
    }, onError: (_) {
      // Abaikan error di stream terbaru; masih ada stream history sebagai fallback
    });

    _deviceDataSubscription = _firebaseDB
        .deviceDataRef(deviceId)
        .limitToLast(historyDataLimit)
        .onValue
        .listen((event) async {
      final value = event.snapshot.value;
      if (value is Map && value.isNotEmpty) {
        final entries = value.entries.toList()
          ..sort((a, b) {
            final aTs = int.tryParse(a.key.toString()) ?? 0;
            final bTs = int.tryParse(b.key.toString()) ?? 0;
            return aTs.compareTo(bTs);
          });

        final List<SolarData> newData = [];
        for (final entry in entries) {
          if (entry.value is Map) {
            final map = Map<String, dynamic>.from(
              (entry.value as Map).map((k, v) => MapEntry(k.toString(), v)),
            );
            map.putIfAbsent('timestamp', () {
              final ts = int.tryParse(entry.key.toString());
              if (ts == null) return DateTime.now().millisecondsSinceEpoch;
              if (ts < 10000000000) {
                return ts * 1000;
              }
              return ts;
            });
            newData.add(SolarData.fromJson(map));
          }
        }
        _solarData = newData;
        // Update latest realtime juga jika belum terisi
        if (_latestRealtime == null && newData.isNotEmpty) {
          _latestRealtime = newData.last;
        }
        // Cek threshold dan tampilkan notifikasi jika melewati batas
        if (newData.isNotEmpty) {
          final latest = _latestValidFrom(newData);
          if (latest == null) {
            notifyListeners();
            return;
          }
          final settings = _settings;
          _solarService.checkThresholdsAndNotify(latest, settings).then((_) async {
            _notifications = await _solarService.getNotifications();
            notifyListeners();
          });
        }
      } else {
        _solarData = [];
        // Auto-recover: jika device saat ini tidak punya data, pindah ke device aktif terbaru.
        if (!_isRecoveringDevice) {
          _isRecoveringDevice = true;
          try {
            final fallbackDevice = await _fetchFirstDeviceId();
            if (fallbackDevice != null &&
                fallbackDevice.isNotEmpty &&
                fallbackDevice != _currentDeviceId) {
              _currentDeviceId = fallbackDevice;
              await _saveSelectedDeviceId(fallbackDevice);
              _listenToDeviceData();
              return;
            }
          } catch (_) {
            // ignore, keep current state
          } finally {
            _isRecoveringDevice = false;
          }
        }
      }
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });

    // Fallback awal: ambil snapshot sekali jika stream belum mengisi data.
    _loadDeviceDataOnce(deviceId);
  }

  Future<void> _loadDeviceDataOnce(String deviceId) async {
    try {
      final snapshot = await _firebaseDB
          .deviceDataRef(deviceId)
          .limitToLast(historyDataLimit)
          .get()
          .timeout(const Duration(seconds: 6));
      if (!snapshot.exists) return;
      final value = snapshot.value;
      if (value is! Map || value.isEmpty) return;

      final entries = value.entries.toList()
        ..sort((a, b) {
          final aTs = int.tryParse(a.key.toString()) ?? 0;
          final bTs = int.tryParse(b.key.toString()) ?? 0;
          return aTs.compareTo(bTs);
        });

      final List<SolarData> newData = [];
      for (final entry in entries) {
        if (entry.value is Map) {
          final map = Map<String, dynamic>.from(
            (entry.value as Map).map((k, v) => MapEntry(k.toString(), v)),
          );
          map.putIfAbsent('timestamp', () {
            final ts = int.tryParse(entry.key.toString());
            if (ts == null) return DateTime.now().millisecondsSinceEpoch;
            if (ts < 10000000000) return ts * 1000;
            return ts;
          });
          newData.add(SolarData.fromJson(map));
        }
      }

      if (newData.isNotEmpty) {
        _solarData = newData;
        notifyListeners();
      }
    } catch (_) {
      // ignore fallback errors
    }
  }

  Future<void> selectDevice(String deviceId) async {
    if (deviceId.isEmpty || deviceId == _currentDeviceId) return;
    _currentDeviceId = deviceId;
    await _saveSelectedDeviceId(deviceId);
    _solarData = [];
    notifyListeners();
    _listenToDeviceData();
  }

  void stopDataSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }
} 