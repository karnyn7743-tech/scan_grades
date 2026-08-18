import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsService {
  static const String _contactsKey = 'app_contacts_map';

  /// حفظ أو تحديث جهة اتصال (ربط الرقم/الـ ID بالاسم)
  static Future<void> saveContact(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> contacts = await getContacts();
    contacts[id] = name;
    await prefs.setString(_contactsKey, jsonEncode(contacts));
  }

  /// الحصول على قائمة كل جهات الاتصال المحفوظة
  static Future<Map<String, String>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_contactsKey);
    if (data == null || data.isEmpty) return {};
    try {
      Map<String, dynamic> decoded = jsonDecode(data);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  /// إرجاع اسم المتصل إن كان محفوضاً، وإلا إرجاع الاسم المرسل أو الـ ID نفسه
  static Future<String> getDisplayName(String id, {String? defaultName}) async {
    Map<String, String> contacts = await getContacts();
    if (contacts.containsKey(id) && contacts[id]!.isNotEmpty) {
      return contacts[id]!; // الاسم المحفوظ محلياً
    }
    // إذا لم يكن محفوظاً، نستخدم الاسم القادم في طلب الاتصال أو الـ ID
    return (defaultName != null && defaultName.isNotEmpty) ? defaultName : id;
  }

  /// حذف جهة اتصال
  static Future<void> deleteContact(String id) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String> contacts = await getContacts();
    contacts.remove(id);
    await prefs.setString(_contactsKey, jsonEncode(contacts));
  }
}
