import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  // 🔑 كلمة السر الخاصة بك كمطور (غير هذه السلسلة إلى أي كلمة سر سريّة خاصة بك)
  static const String _secretSalt = "MyCustomAppSecret_2026_@Key";
  static const String _licenseKeyPref = "app_license_key";

  /// الحصول على المعرّف الفريد للجهاز (Device ID)
  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // معرّف الأندرويد الفريد
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "UNKNOWN_IOS_DEVICE";
      }
    } catch (e) {
      print("خطأ في قراءة معرّف الجهاز: $e");
    }
    return "UNKNOWN_DEVICE";
  }

  /// خوارزمية توليد مفتاح التفعيل بناءً على معرّف الجهاز والـ Salt
  static String generateLicenseKey(String deviceId) {
    final rawData = "$deviceId|$_secretSalt";
    final bytes = utf8.encode(rawData);
    final digest = sha256.convert(bytes);
    
    // نأخذ أول 16 حرفاً وننسقها في 4 مجموعات (XXXX-XXXX-XXXX-XXXX)
    final hexString = digest.toString().toUpperCase();
    final keyPart = hexString.substring(0, 16);
    
    return "${keyPart.substring(0, 4)}-${keyPart.substring(4, 8)}-${keyPart.substring(8, 12)}-${keyPart.substring(12, 16)}";
  }

  /// التحقق مما إذا كان التطبيق مفعلاً مسبقاً
  static Future<bool> isAppActivated() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_licenseKeyPref);
    if (savedKey == null || savedKey.isEmpty) return false;

    final deviceId = await getDeviceId();
    final expectedKey = generateLicenseKey(deviceId);

    return savedKey.trim().toUpperCase() == expectedKey.toUpperCase();
  }

  /// تفعيل التطبيق بطلب الرمز من المستخدم وحفظه
  static Future<bool> activateApp(String inputKey) async {
    final deviceId = await getDeviceId();
    final expectedKey = generateLicenseKey(deviceId);

    if (inputKey.trim().toUpperCase() == expectedKey.toUpperCase()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKeyPref, inputKey.trim().toUpperCase());
      return true; // تم التفعيل بنجاح
    }
    return false; // المفتاح غير صحيح
  }
}
