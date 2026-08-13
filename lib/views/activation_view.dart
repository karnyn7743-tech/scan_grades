import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/license_service.dart';

class ActivationView extends StatefulWidget {
  final VoidCallback onActivated;

  const ActivationView({Key? key, required this.onActivated}) : super(key: key);

  @override
  State<ActivationView> createState() => _ActivationViewState();
}

class _ActivationViewState extends State<ActivationView> {
  String _deviceId = "جاري التحميل...";
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await LicenseService.getDeviceId();
    setState(() {
      _deviceId = id;
    });
  }

  Future<void> _submitLicense() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await LicenseService.activateApp(_keyController.text);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      widget.onActivated(); // فتح التطبيق عند التفعيل
    } else {
      setState(() {
        _errorMessage = "رمز التفعيل غير صحيح لهذا الجهاز!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفعيل التطبيق'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            const Text(
              'التطبيق غير مفعّل',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'هذا التطبيق مخصص للاستخدام المصرح به فقط. يُرجى تزويد المطور بـ "معرّف الجهاز" للحصول على مفتاح التفعيل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 30),

            // كارت عرض معرّف الجهاز
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'معرّف الجهاز الخاص بك (Device ID):',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _deviceId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ معرّف الجهاز!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('نسخ المعرّف'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // حقل إدخال كود التفعيل
            TextField(
              controller: _keyController,
              textAlign: TextAlign.center,
              style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'أدخل مفتاح التفعيل (XXXX-XXXX-XXXX-XXXX)',
                errorText: _errorMessage,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.key),
              ),
            ),

            const SizedBox(height: 20),

            // زر التفعيل
            ElevatedButton(
              onPressed: _isLoading ? null : _submitLicense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تفعيل الآن', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
