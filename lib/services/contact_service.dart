import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContactService {
  static const String _contactsKey = 'saved_p2p_contacts';

  // حفظ أو تحديث اسم جهة اتصال برقم الـ Device ID
  static Future<void> saveContact(String deviceId, String customName) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> contacts = await getContacts();
    contacts[deviceId] = customName;
    await prefs.setString(_contactsKey, jsonEncode(contacts));
  }

  // استرجاع جميع جهات الاتصال المحفوظة
  static Future<Map<String, String>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_contactsKey);
    if (data == null) return {};
    try {
      Map<String, dynamic> decoded = jsonDecode(data);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  // الحصول على اسم الجهة المحفوظة إن وجدت
  static Future<String?> getContactName(String deviceId) async {
    Map<String, String> contacts = await getContacts();
    return contacts[deviceId];
  }
}
