import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart'; 
// استيراد مكتبة التعرف على النصوص من جوجل مكسوّة بالكامل
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  String _fileName = "لم يتم اختيار ملف الكنترول بعد";
  String? _selectedFilePath;
  List<String> _subjects = []; 
  String? _selectedSubject;
  bool _isLoading = false;

  String _secretIdResult = "سيظهر هنا الرقم السري";
  final TextEditingController _gradeController = TextEditingController();

  int _totalStudents = 0;
  int _gradedStudents = 0;
  
  // متحكم الكاميرا وفلاش المصابيح
  final MobileScannerController _cameraController = MobileScannerController(
    autoStart: false, 
    torchEnabled: false,
  );
  bool _isScanningActive = false;
  bool _isTorchOn = false;

  // تعريف قارئ النصوص (OCR)
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> _pickAndParseExcel() async {
    setState(() {
      _isLoading = true;
      _subjects.clear();
      _selectedSubject = null;
      _fileName = "جاري قراءة الملف...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        _selectedFilePath = result.files.single.path;
        String nameOfFile = result.files.single.name;
        
        var bytes = File(_selectedFilePath!).readAsBytesSync();
        var excel = px.Excel.decodeBytes(bytes);
        
        String firstSheet = excel.tables.keys.first;
        var sheet = excel.tables[firstSheet];

        if (sheet != null && sheet.maxColumns > 0) {
          var firstRow = sheet.rows.first; 
          List<String> tempSubjects = [];

          int startColumn = 4;  // E
          int endColumn = 18;  // S

          for (int i = startColumn; i <= endColumn; i++) {
            if (i < firstRow.length) {
              var cellValue = firstRow[i]?.value;
              if (cellValue != null) {
                String subjectName = cellValue.toString().trim();
                if (subjectName.isNotEmpty) {
                  tempSubjects.add(subjectName);
                }
              }
            }
          }

          setState(() {
            _fileName = nameOfFile;
            _subjects = tempSubjects;
            _totalStudents = sheet.maxRows > 1 ? sheet.maxRows - 1 : 0; 
            _gradedStudents = 0; 
          });

          if (_subjects.isEmpty) {
            _showSnackBar("تنبيه: لم يتم العثور على مواد في الأعمدة من E إلى S في الصف الأول.");
          }
        }
      } else {
        setState(() {
          _fileName = _selectedFilePath != null ? _selectedFilePath!.split('/').last : "لم يتم اختيار ملف الكنترول بعد";
        });
      }
    } catch (e) {
      setState(() {
        _fileName = "فشل في قراءة ملف الأكسيل";
      });
      _showSnackBar("حدث خطأ أثناء المعالجة: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة معالجة الصورة الحية والتعرف الذكي على الكود والدرجة والمادة
  Future<void> _processCapturedImage(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    
    // 1. التقاط الرقم السري من الـ QR Code أولاً
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrValue = barcodes.first.rawValue!;
      
      // إيقاف مؤقت لمنع التكرار أثناء المعالجة
      _cameraController.stop();

      if (capture.image != null) {
        final InputImage inputImage = InputImage.fromBytes(
          bytes: capture.image!,
          metadata: InputImageMetadata(
            size: Size(capture.width!.toDouble(), capture.height!.toDouble()),
            rotation: InputImageRotation.rotation0, 
            format: InputImageFormat.nv21, 
            bytesPerRow: capture.width!,
          ),
        );

        try {
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          
          // تجميع الأسطر النصية المكتشفة مع إحداثياتها الأفقية (محور X)
          List<Map<String, dynamic>> textElements = [];

          for (TextBlock block in recognizedText.blocks) {
            for (TextLine line in block.lines) {
              String cleanText = _extractDigits(line.text.trim());
              if (cleanText.isNotEmpty) {
                textElements.add({
                  'text': cleanText,
                  'x': line.boundingBox.left, // الإحداثي الأفقي للعنصر
                });
              }
            }
          }

          String detectedSubjectCode = "";
          String detectedGrade = "";

          if (textElements.isNotEmpty) {
            // فرز العناصر بناءً على موقعها الأفقي (من اليمين إلى اليسار)
            textElements.sort((a, b) => a['x'].compareTo(b['x']));

            // بناءً على الصورة: كود المادة في جهة، والدرجة في الجهة المقابلة تماماً
            if (textElements.length >= 2) {
              detectedSubjectCode = textElements.first['text']; // الأقرب لجهة اليمين (كود المادة المطبوع)
              detectedGrade = textElements.last['text'];        // الأقرب لجهة اليسار (الدرجة بخط اليد)
            } else if (textElements.length == 1) {
              detectedGrade = textElements.first['text'];
            }
          }

          // الحصول على الترتيب (Index) للمادة المختارة حالياً من القائمة لمطابقتها
          int currentSubjectIndex = _subjects.indexOf(_selectedSubject!) + 1; 

          // التحقق الأمني من كود المادة
          if (detectedSubjectCode.isNotEmpty && detectedSubjectCode != currentSubjectIndex.toString()) {
            _showSnackBar("⚠️ تنبيه: كود المادة المقروء ($detectedSubjectCode) لا يطابق المادة المختارة ($_selectedSubject)!");
            _cameraController.start(); // إعادة تشغيل الكاميرا للمحاولة مجدداً
            setState(() {
              _isScanningActive = true;
            });
            return;
          }

          // رصد البيانات بنجاح وتحديث الواجهة
          setState(() {
            _secretIdResult = qrValue; // عرض الرقم السري
            if (detectedGrade.isNotEmpty) {
              _gradeController.text = detectedGrade; // عرض الدرجة تلقائياً
            }
            _gradedStudents += 1; // تحديث عداد الطلاب
            _isScanningActive = false;
          });

          _showSnackBar("✅ تم رصد الطالب بنجاح بمادة $_selectedSubject");

        } catch (e) {
          // حل احتياطي في حال وجود قيود على معالجة الصورة الحية
          setState(() {
            _secretIdResult = qrValue;
            _gradedStudents += 1;
            _isScanningActive = false;
          });
          _showSnackBar("تم التقاط الرقم السري: $qrValue (أدخل الدرجة يدوياً)");
        }
      } else {
        setState(() {
          _secretIdResult = qrValue;
          _gradedStudents += 1;
          _isScanningActive = false;
        });
      }
    }
  }

  // دالة مساعدة لتنقية الأرقام من النصوص وحذف أي فراغات أو أحرف إضافية
  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // تفعيل الكاميرا لبدء الفحص والمسح
  void _toggleScanning() {
    if (_selectedSubject == null) {
      _showSnackBar("يرجى اختيار المادة المراد رصدها أولاً قبل بدء المسح!");
      return;
    }

    setState(() {
      _isScanningActive = !_isScanningActive;
    });

    if (_isScanningActive) {
      _cameraController.start();
    } else {
      _cameraController.stop();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _cameraController.dispose();
    _textRecognizer.dispose(); // إغلاق مستخرج النصوص لتحرير الذاكرة
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
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              if (_isScanningActive) {
                _cameraController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              }
            }, 
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _isLoading ? null : _pickAndParseExcel, 
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    "اختر ملف الأكسيل الأصلي",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _fileName,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "اختر المادة :",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: Text(
                    _subjects.isEmpty ? "يرجى اختيار ملف الأكسيل لجلب المواد" : "انقر لتحديد المادة المفتوحة ورصدها",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  value: _selectedSubject,
                  items: _subjects.isEmpty ? null : _subjects
                      .map(
                        (sub) => DropdownMenuItem(
                          value: sub,
                          child: Text(
                            sub,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubject = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "الرقم السري :",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _secretIdResult,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "الدرجة :",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          fillColor: fieldColor,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "العداد :",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fieldColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade700),
                        ),
                        child: Text(
                          "$_gradedStudents / $_totalStudents",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanningActive ? Colors.red : Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _toggleScanning, 
              child: Text(
                _isScanningActive ? "إيقاف المسح مؤقتاً" : "ابدأ المسح بالكاميرا",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: null, 
              child: const Text(
                "حفظ وتعديل الملف الأصلي",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // حاوية الكاميرا المرتبطة بدالة الـ OCR الجديدة
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isScanningActive ? Colors.greenAccent : Colors.grey, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isScanningActive
                    ? MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          _processCapturedImage(capture);
                        },
                      )
                    : const Center(
                        child: Text(
                          "انقر فوق 'ابدأ المسح بالكاميرا' لتشغيل الفحص الحي",
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
