import 'package:audioplayers/audioplayers.dart';

class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSoundEnabled = true;

  // Play notification sound
  Future<void> playNotificationSound() async {
    if (!_isSoundEnabled) return;
    
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }

  // Toggle sound
  void toggleSound(bool enabled) {
    _isSoundEnabled = enabled;
  }

  // Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}