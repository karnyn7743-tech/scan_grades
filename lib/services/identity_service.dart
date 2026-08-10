import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class IdentityService {
  static const _storage = FlutterSecureStorage();
  
  static const _keyDeviceId = 'device_id';
  static const _keyDeviceName = 'device_name';

  // جلب أو إنشاء هوية فريدة وثابتة للجهاز
  static Future<String> getOrCreateDeviceId() async {
    String? id = await _storage.read(key: _keyDeviceId);
    if (id == null) {
      id = const Uuid().v4(); // توليد UUID جديد فريد جداً
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }

  // حفظ وحفظ اسم صاحب الجهاز
  static Future<void> setDeviceName(String name) async {
    await _storage.write(key: _keyDeviceName, value: name);
  }

  static Future<String> getDeviceName() async {
    return await _storage.read(key: _keyDeviceName) ?? 'جهاز غير معروف';
  }

  // إدارة قوائم القبول والحظر لمنع التخمين والإزعاج
  static Future<void> trustDevice(String deviceId, String name) async {
    await _storage.write(key: 'trusted_$deviceId', value: name);
  }

  static Future<void> blockDevice(String deviceId) async {
    await _storage.write(key: 'blocked_$deviceId', value: 'true');
  }

  static Future<bool> isTrusted(String deviceId) async {
    String? val = await _storage.read(key: 'trusted_$deviceId');
    return val != null;
  }

  static Future<bool> isBlocked(String deviceId) async {
    String? val = await _storage.read(key: 'blocked_$deviceId');
    return val == 'true';
  }
}
