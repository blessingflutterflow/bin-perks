import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _enabled = true;

  /// Enable or disable sound effects
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Play a notification sound (bell-like)
  Future<void> playBellSound() async {
    if (!_enabled) return;

    try {
      // Play notification sound - works on both Android and iOS
      await FlutterRingtonePlayer().playNotification();
    } catch (e) {
      // Silently fail if sound can't be played
    }
  }

  /// Play sound when rating is selected
  Future<void> playRatingSound(int ratingIndex) async {
    // Play the notification sound for any rating
    await playBellSound();
  }
}
