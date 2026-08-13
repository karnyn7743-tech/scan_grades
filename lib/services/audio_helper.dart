import 'package:audioplayers/audioplayers.dart';

class SoundHelper {
  static final AudioPlayer _ringtonePlayer = AudioPlayer();
  static final AudioPlayer _notificationPlayer = AudioPlayer();

  // 🔔 تشغيل نغمة تنبيه قصيرة (رسالة / إشعار)
  static Future<void> playNotificationSound() async {
    await _notificationPlayer.play(
      AssetSource('sounds/notification.mp3'), // ضع ملف الصوت في assets/sounds/
      mode: PlayerMode.lowLatency,
    );
  }

  // 📞 تشغيل نغمة رنين المكالمة (تتكرر حتى الرد أو الإلغاء)
  static Future<void> startRingtone() async {
    await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    await _ringtonePlayer.play(
      AssetSource('sounds/ringtone.mp3'),
    );
  }

  // 🛑 إيقاف نغمة الرنين عند الرد أو رفض المكالمة
  static Future<void> stopRingtone() async {
    await _ringtonePlayer.stop();
  }
}
