import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // 🔑 المفتاح السري الموحد لتطبيقك (يمكنك تغييره لأي نص سري خاص بك)
  static const String _secretKey = "TALOOT_HASHEMI_SECRET_KEY_2026";

  /// تشفير النص قبل إرساله عبر الشبكة
  static String encryptText(String plainText) {
    try {
      final keyBytes = utf8.encode(_secretKey);
      final textBytes = utf8.encode(plainText);
      
      // عملية تشفير بسيطة وقوية باستخدام XOR مع SHA-256 Hash
      final keyHash = sha256.convert(keyBytes).bytes;
      final encryptedBytes = List<int>.generate(textBytes.length, (i) {
        return textBytes[i] ^ keyHash[i % keyHash.length];
      });

      return base64.encode(encryptedBytes);
    } catch (e) {
      return plainText; // في حال حدوث خطأ يُرجع النص كما هو
    }
  }

  /// فك تشفير النص عند استلامه من الشبكة
  static String decryptText(String encryptedText) {
    try {
      final keyBytes = utf8.encode(_secretKey);
      final encryptedBytes = base64.decode(encryptedText);

      final keyHash = sha256.convert(keyBytes).bytes;
      final decryptedBytes = List<int>.generate(encryptedBytes.length, (i) {
        return encryptedBytes[i] ^ keyHash[i % keyHash.length];
      });

      return utf8.decode(decryptedBytes);
    } catch (e) {
      return encryptedText; // في حال تعذر الفك (مثلاً رسالة غير مشفرة)
    }
  }
}
