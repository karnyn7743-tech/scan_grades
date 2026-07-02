import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StugraScanApp());
}

class StugraScanApp extends StatelessWidget {
  const StugraScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StugraScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // متغيرات وهمية فقط لعرض التنسيق كما هو
  final String _fileName = "لم يتم اختيار ملف (نسخة فحص صامتة)";
  final List<String> _subjects = ["القرآن الكريم", "التربية الإسلامية", "اللغة العربية", "الرياضيات"];
  String? _selectedSubject;
  final String _secretIdResult = "سيظهر هنا الرقم السري";
  final TextEditingController _gradeController = TextEditingController();
  
  final int _totalStudents = 0;
  final int _gradedStudents = 0;

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primaryPurple = const Color(0xFF7B1FA2);
    Color fieldColor = const Color(0xFF212121);

    return Scaffold(
      backgroundColor: const Color(0xFF4A148C),
      appBar: AppBar(
        title: const Text("برنامج إسقاط الدرجات بالأكواد"),
        centerTitle: true,
        backgroundColor: primaryPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () {}, // صامت
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // زر اختيار ملف الأكسيل
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                minimumSize: const Size.fromHeight(50)
              ),
              onPressed: () {}, // صامت
              child: const Text("اختر ملف الأكسيل الأصلي", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: Text(_fileName, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            
            // قائمة اختيار المادة
            const Align(alignment: Alignment.centerRight, child: Text("اختر المادة :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: const Text("انقر لتحديد المادة (تجريبي)", style: const TextStyle(color: Colors.grey)),
                  value: _selectedSubject,
                  items: _subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubject = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // الرقم السري
            const Align(alignment: Alignment.centerRight, child: Text("الرقم السري :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: Text(_secretIdResult, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),

            // الصف الخاص بالدرجة والعداد
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("الدرجة :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(fillColor: fieldColor, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("العداد :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade700)),
                        child: Text("$_gradedStudents / $_totalStudents", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // أزرار العمليات
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: () {}, // صامت
              child: const Text("ابدأ المسح", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: null, // معطل صامتاً
              child: const Text("حفظ وتعديل الملف الأصلي", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),

            // حاوية الكاميرا الصامتة
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey, width: 2)),
              child: const Center(
                child: Text(
                  "وضع الفحص الصامت للواجهة الرسومية فقط\n(الكاميرا معطلة مؤقتاً)",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
