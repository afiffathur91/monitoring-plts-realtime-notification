class SolarNotification {
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;

  SolarNotification({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
  });

  factory SolarNotification.fromJson(Map<String, dynamic> json) {
    return SolarNotification(
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.info,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }
}

enum NotificationType {
  warning,
  error,
  info,
} 