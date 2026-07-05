import 'package:flutter/material.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';
import 'grade_entry_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onThemeToggle;

  const HomeScreen({super.key, required this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('كنترول الأتمتة المصغرة للإمتحانات'),
        centerTitle: true,
        actions: [
          // ===== زر تبديل الوضع =====
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: onThemeToggle,
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMainButton(
              context,
              title: 'تكوين رموز إستجابة سريعة للطلاب',
              icon: Icons.qr_code,
              color: Theme.of(context).primaryColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GenerateQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              title: 'قراءة رموز الإستجابة السريعة للطلاب',
              icon: Icons.qr_code_scanner,
              color: Theme.of(context).primaryColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              title: 'إدخال الدرجات من أوراق الإجابة',
              icon: Icons.edit_note,
              color: Theme.of(context).primaryColor,
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
