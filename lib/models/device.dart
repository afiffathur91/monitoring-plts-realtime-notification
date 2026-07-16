class Device {
  final String id;
  final String name;
  final DateTime lastSeen;
  final bool isOnline;
  final String status;

  Device({
    required this.id,
    required this.name,
    required this.lastSeen,
    required this.isOnline,
    required this.status,
  });

  factory Device.fromMap(Map<String, dynamic> map, String deviceId) {
    // Get the latest data timestamp as lastSeen
    final Map<String, dynamic>? data = () {
      final raw = map['data'];
      if (raw is Map) {
        return Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
      }
      return null;
    }();
    
    DateTime lastSeen = DateTime.fromMillisecondsSinceEpoch(0);
    if (data != null && data.isNotEmpty) {
      try {
        // Keys are epoch timestamps in seconds from Arduino
        final latestTimestamp = data.keys
            .map((k) {
              final ts = int.tryParse(k.toString());
              if (ts == null) return 0;
              // If timestamp is less than year 2000 in seconds, it's in seconds
              // Otherwise it might be in milliseconds
              if (ts < 946684800) { // Year 2000 in seconds
                return ts;
              } else if (ts < 946684800000) { // Year 2000 in milliseconds
                return ts ~/ 1000; // Convert to seconds
              } else {
                return ts ~/ 1000; // Very large number, assume milliseconds
              }
            })
            .where((ts) => ts > 0)
            .reduce((a, b) => a > b ? a : b);
        
        if (latestTimestamp > 0) {
          lastSeen = DateTime.fromMillisecondsSinceEpoch(latestTimestamp * 1000, isUtc: true).toLocal();
        }
      } catch (e) {
        // If parsing fails, use current time or check for lastSeen field
        if (map['lastSeen'] != null) {
          final ls = map['lastSeen'];
          if (ls is int) {
            lastSeen = DateTime.fromMillisecondsSinceEpoch(ls, isUtc: true).toLocal();
          } else if (ls is String) {
            final dt = DateTime.parse(ls);
            lastSeen = dt.isUtc ? dt.toLocal() : dt;
          }
        }
      }
    } else if (map['lastSeen'] != null) {
      // Fallback to lastSeen field if data is empty
      final ls = map['lastSeen'];
      if (ls is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(ls, isUtc: true).toLocal();
      } else if (ls is String) {
        final dt = DateTime.parse(ls);
        lastSeen = dt.isUtc ? dt.toLocal() : dt;
      }
    }

    // Device is considered online if last seen within last 2 minutes (120 seconds)
    // Arduino sends data every 5 seconds, so 2 minutes is reasonable
    final now = DateTime.now();
    final timeDiff = now.difference(lastSeen).inSeconds;
    final isOnline = timeDiff >= 0 && timeDiff < 120;
    
    return Device(
      id: deviceId,
      name: map['name'] ?? 'Device $deviceId',
      lastSeen: lastSeen,
      isOnline: isOnline,
      status: isOnline ? 'Online' : 'Offline',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isOnline': isOnline,
      'status': status,
    };
  }
}