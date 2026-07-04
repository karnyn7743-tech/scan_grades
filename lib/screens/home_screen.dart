import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';
import 'grade_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ===================== دالة المسار الموحد =====================
  Future<String> _getGradesDirectoryPath() async {
    final Directory? downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      throw Exception('لا يمكن الوصول إلى مجلد Downloads');
    }
    final String path = '${downloadsDir.path}/درجات الطلاب';
    final Directory dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  // ===================== طلب الصلاحيات =====================
  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  // ===================== اختيار ملف Excel ونسخه إلى المجلد الموحد =====================
  Future<void> _pickExcelFile() async {
    await _requestPermissions();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم اختيار ملف')),
        );
        return;
      }

      final String sourcePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      // الحصول على المجلد الموحد
      final String gradesDir = await _getGradesDirectoryPath();
      final String targetPath = '$gradesDir/$fileName';

      // حذف الملف القديم إذا كان موجوداً
      if (await File(targetPath).exists()) {
        await File(targetPath).delete();
      }

      // نسخ الملف إلى المجلد الموحد
      await File(sourcePath).copy(targetPath);

      // تخزين المسار الجديد في Session (يمكنك استخدام SharedPreferences لاحقاً)
      // سنمرر المسار إلى الشاشات الأخرى عبر الـ Navigator

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم نسخ الملف إلى: $targetPath'),
          backgroundColor: Colors.green,
        ),
      );

      // هنا يمكنك حفظ المسار في متغير عام أو تمريره للشاشات
      // لكننا سنكتفي بعرض رسالة نجاح، وسيتم التعامل مع المسار في كل شاشة على حدة

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===================== واجهة المستخدم =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text('نظام إدارة الدرجات'),
        backgroundColor: Colors.lightBlue.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickExcelFile,
            tooltip: 'اختيار ملف Excel',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الزر الأول: توليد QR Codes
            _buildMainButton(
              context,
              title: 'تكوين QR Code للأرقام السرية للطلاب',
              icon: Icons.qr_code,
              color: Colors.lightBlue.shade700,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GenerateQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // الزر الثاني: قراءة QR فقط
            _buildMainButton(
              context,
              title: 'قراءة الـ QR Code للطلاب',
              icon: Icons.qr_code_scanner,
              color: Colors.lightBlue.shade600,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            // الزر الثالث: إدخال الدرجات
            _buildMainButton(
              context,
              title: 'إدخال الدرجات من أوراق الإجابة',
              icon: Icons.edit_note,
              color: Colors.lightBlue.shade800,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GradeEntryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 32, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
