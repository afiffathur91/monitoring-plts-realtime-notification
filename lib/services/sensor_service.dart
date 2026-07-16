import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';

class SensorService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Stream<List<String>> getDeviceList() {
    return _dbRef.child('devices').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data.keys.cast<String>().toList();
    });
  }

  Stream<SensorData> getSensorDataStream(String deviceId) {
    return _dbRef.child('devices/$deviceId/data').limitToLast(1).onValue.map((event) {
      if (!event.snapshot.exists) {
        return SensorData(
          voltage: 0.0,
          current: 0.0,
          power: 0.0,
          timestamp: DateTime.now(),
        );
      }
      final raw = event.snapshot.children.first.value;
      final Map<String, dynamic> dataMap = (raw is Map)
          ? Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)))
          : <String, dynamic>{};
      return SensorData.fromMap(dataMap);
    });
  }

  Future<List<SensorData>> getHistoricalData(String deviceId) async {
    final snapshot = await _dbRef.child('devices/$deviceId/data').limitToLast(100).get();
    if (!snapshot.exists) return [];

    final data = snapshot.value as Map;
    return data.values
        .map((value) {
          final Map<String, dynamic> m = (value is Map)
              ? Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)))
              : <String, dynamic>{};
          return SensorData.fromMap(m);
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}