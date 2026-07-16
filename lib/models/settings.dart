class Settings {
  final double minVoltage;
  final double maxVoltage;
  final double minCurrent;
  final double maxCurrent;
  final double minPower;
  final double maxPower;
  final bool notificationSoundEnabled;
  final int notificationCooldownMinutes;
  final bool showWattLampu;
  /// Token bot Telegram (dari @BotFather)
  final String telegramBotToken;
  /// Chat ID Telegram (untuk terima notifikasi)
  final String telegramChatId;
  /// Webhook URL untuk WhatsApp/Google Assistant (IFTTT, Zapier, dll)
  final String notificationWebhookUrl;

  Settings({
    this.minVoltage = 0.0,
    this.maxVoltage = 30.0,
    this.minCurrent = 0.0,
    this.maxCurrent = 10.0,
    this.minPower = 0.0,
    this.maxPower = 300.0,
    this.notificationSoundEnabled = true,
    this.notificationCooldownMinutes = 5,
    this.showWattLampu = false,
    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.notificationWebhookUrl = '',
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      minVoltage: json['minVoltage']?.toDouble() ?? 0.0,
      maxVoltage: json['maxVoltage']?.toDouble() ?? 30.0,
      minCurrent: json['minCurrent']?.toDouble() ?? 0.0,
      maxCurrent: json['maxCurrent']?.toDouble() ?? 10.0,
      minPower: json['minPower']?.toDouble() ?? 0.0,
      maxPower: json['maxPower']?.toDouble() ?? 300.0,
      notificationSoundEnabled: json['notificationSoundEnabled'] ?? true,
      notificationCooldownMinutes: json['notificationCooldownMinutes'] ?? 5,
      showWattLampu: json['showWattLampu'] ?? false,
      telegramBotToken: json['telegramBotToken']?.toString() ?? '',
      telegramChatId: json['telegramChatId']?.toString() ?? '',
      notificationWebhookUrl: json['notificationWebhookUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minVoltage': minVoltage,
      'maxVoltage': maxVoltage,
      'minCurrent': minCurrent,
      'maxCurrent': maxCurrent,
      'minPower': minPower,
      'maxPower': maxPower,
      'notificationSoundEnabled': notificationSoundEnabled,
      'notificationCooldownMinutes': notificationCooldownMinutes,
      'showWattLampu': showWattLampu,
      'telegramBotToken': telegramBotToken,
      'telegramChatId': telegramChatId,
      'notificationWebhookUrl': notificationWebhookUrl,
    };
  }

  Settings copyWith({
    double? minVoltage,
    double? maxVoltage,
    double? minCurrent,
    double? maxCurrent,
    double? minPower,
    double? maxPower,
    bool? notificationSoundEnabled,
    int? notificationCooldownMinutes,
    bool? showWattLampu,
    String? telegramBotToken,
    String? telegramChatId,
    String? notificationWebhookUrl,
  }) {
    return Settings(
      minVoltage: minVoltage ?? this.minVoltage,
      maxVoltage: maxVoltage ?? this.maxVoltage,
      minCurrent: minCurrent ?? this.minCurrent,
      maxCurrent: maxCurrent ?? this.maxCurrent,
      minPower: minPower ?? this.minPower,
      maxPower: maxPower ?? this.maxPower,
      notificationSoundEnabled: notificationSoundEnabled ?? this.notificationSoundEnabled,
      notificationCooldownMinutes: notificationCooldownMinutes ?? this.notificationCooldownMinutes,
      showWattLampu: showWattLampu ?? this.showWattLampu,
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      telegramChatId: telegramChatId ?? this.telegramChatId,
      notificationWebhookUrl: notificationWebhookUrl ?? this.notificationWebhookUrl,
    );
  }
} 