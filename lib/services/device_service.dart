import 'package:firebase_database/firebase_database.dart';
import '../models/device.dart';

class DeviceService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get stream of all devices
  Stream<List<Device>> getDevicesStream() {
    return _dbRef.child('devices').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      
      final data = event.snapshot.value as Map;
      return data.entries.map((entry) {
        final String id = entry.key.toString();
        final Map<String, dynamic> valueMap = (entry.value is Map)
            ? Map<String, dynamic>.from((entry.value as Map).map((k, v) => MapEntry(k.toString(), v)))
            : <String, dynamic>{};
        return Device.fromMap(valueMap, id);
      }).toList();
    });
  }

  // Get a single device
  Future<Device?> getDevice(String deviceId) async {
    final snapshot = await _dbRef.child('devices/$deviceId').get();
    if (!snapshot.exists) return null;

    final raw = snapshot.value;
    final Map<String, dynamic> valueMap = (raw is Map)
        ? Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
    return Device.fromMap(valueMap, deviceId);
  }

  // Update device name
  Future<void> updateDeviceName(String deviceId, String newName) async {
    await _dbRef.child('devices/$deviceId').update({
      'name': newName,
    });
  }

  // Delete device
  Future<void> deleteDevice(String deviceId) async {
    await _dbRef.child('devices/$deviceId').remove();
  }

  // Check if device exists by ID
  Future<bool> deviceExists(String deviceId) async {
    final snapshot = await _dbRef.child('devices/$deviceId').get();
    return snapshot.exists;
  }

  // Create a minimal device node so the app can link the ID before the device sends data
  Future<void> createDevice(String deviceId) async {
    await _dbRef.child('devices/$deviceId').update({
      'name': 'Device $deviceId',
      'status': 'Offline',
      'claimed': true,
      'createdAt': ServerValue.timestamp,
    });
  }
}