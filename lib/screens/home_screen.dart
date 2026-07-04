import 'package:flutter/material.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';
import 'grade_entry_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50, // لون أزرق سماوي فاتح
      appBar: AppBar(
        title: const Text('نظام إدارة الدرجات'),
        backgroundColor: Colors.lightBlue.shade300,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الزر الأول
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

            // الزر الثاني
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

            // الزر الثالث
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
