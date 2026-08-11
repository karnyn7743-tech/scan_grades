import 'package:flutter/material.dart';
import '../services/identity_service.dart';

void showConsentDialog({
  required BuildContext context,
  required String callerId,
  required String callerName,
  String? host,
  required VoidCallback onAccepted,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('طلب اتصال جديد 🔒'),
      content: Text(
        'الجهاز المسجّل باسم "$callerName" يحاول التواصل معك.\n\nهل تعرف هذا الشخص وتوافق على إضافته؟',
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await IdentityService.blockDevice(callerId);
            if (host != null) await IdentityService.blockDevice(host);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('رفض وحظر', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () async {
            // حفظ الجهاز بالـ ID وبالعنوان IP لضمان ظهور أيقونة الشات مباشرة
            await IdentityService.trustDevice(callerId, callerName);
            if (host != null) {
              await IdentityService.trustDevice(host, callerName);
            }
            if (context.mounted) {
              Navigator.pop(context);
              onAccepted();
            }
          },
          child: const Text('قبول وتخزين'),
        ),
      ],
    ),
  );
}
