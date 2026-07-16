class SensorData {
  final double voltage;
  final double current;
  final double power;
  final DateTime timestamp;

  SensorData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.timestamp,
  });

  factory SensorData.fromMap(Map<String, dynamic> map) {
    // Handle timestamp - Arduino sends epoch time in seconds, not milliseconds
    DateTime timestamp;
    final ts = map['timestamp'];
    if (ts == null) {
      timestamp = DateTime.now();
    } else if (ts is int) {
      // If timestamp is less than year 2000 in seconds, it's likely in seconds
      // Otherwise it's in milliseconds
      if (ts < 946684800) { // Year 2000 in seconds
        timestamp = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      } else {
        timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } else if (ts is String) {
      timestamp = DateTime.parse(ts);
    } else {
      timestamp = DateTime.now();
    }

    return SensorData(
      voltage: (map['Voltage'] as num? ?? 0).toDouble(),
      current: (map['Current'] as num? ?? 0).toDouble(),
      power: (map['Power'] as num? ?? 0).toDouble(),
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Voltage': voltage,
      'Current': current,
      'Power': power,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}