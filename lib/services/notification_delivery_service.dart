import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification.dart';
import '../models/settings.dart';

/// Mengirim notifikasi ke Telegram, webhook (WhatsApp/Google Assistant/IFTTT), dll.
class NotificationDeliveryService {
  static const String _telegramApiBase = 'https://api.telegram.org';

  /// Kirim ke Telegram Bot jika token dan chat ID diisi.
  /// [chatId] bisa string "1902668272" atau int. Tanpa parse_mode agar teks aman.
  Future<bool> sendToTelegram(SolarNotification notification, Settings settings) async {
    final token = settings.telegramBotToken.trim();
    final chatId = settings.telegramChatId.trim();
    if (token.isEmpty || chatId.isEmpty) return false;

    final text = '🔔 ${notification.title}\n\n${notification.message}';
    final uri = Uri.parse('$_telegramApiBase/bot$token/sendMessage');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
        }),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Kirim pesan uji ke Telegram. Mengembalikan pesan error jika gagal.
  Future<String?> sendTestToTelegram(String botToken, String chatId) async {
    final token = botToken.trim();
    final cid = chatId.trim();
    if (token.isEmpty) return 'Isi Token Bot Telegram terlebih dahulu';
    if (cid.isEmpty) return 'Isi Chat ID Telegram terlebih dahulu';

    final uri = Uri.parse('$_telegramApiBase/bot$token/sendMessage');
    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': cid,
          'text': '✅ Test dari PLTS Monitoring\nNotifikasi Telegram berhasil terhubung.',
        }),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final desc = body?['description'] ?? res.body;
      return 'Telegram: $desc';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Kirim ke Webhook (IFTTT, Zapier, Google Assistant trigger, dll).
  /// Payload JSON: title, message, timestamp, type.
  Future<bool> sendToWebhook(SolarNotification notification, Settings settings) async {
    final url = settings.notificationWebhookUrl.trim();
    if (url.isEmpty) return false;

    final body = {
      'title': notification.title,
      'message': notification.message,
      'timestamp': notification.timestamp.toIso8601String(),
      'type': notification.type.toString().split('.').last,
    };
    try {
      final uri = Uri.parse(url);
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Kirim ke semua channel yang dikonfigurasi (Telegram + Webhook).
  Future<void> deliver(SolarNotification notification, Settings settings) async {
    await Future.wait([
      sendToTelegram(notification, settings),
      sendToWebhook(notification, settings),
    ]);
  }
}
