import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart'; 
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
  
  final MobileScannerController _cameraController = MobileScannerController(
    autoStart: false, 
    torchEnabled: false,
  );
  bool _isScanningActive = false;
  bool _isTorchOn = false;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  // كائن الإكسيل الحالي لحفظ التعديلات في الذاكرة قبل الكتابة على القرص
  px.Excel? _excelInstance;

  // 1. دالة اختيار ومعالجة ملف الإكسيل
  Future<void> _pickAndParseExcel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        _selectedFilePath = result.files.single.path!;
        String nameOfFile = result.files.single.name;

        var bytes = File(_selectedFilePath!).readAsBytesSync();
        _excelInstance = px.Excel.decodeBytes(bytes);

        if (_excelInstance!.tables.isNotEmpty) {
          var sheet = _excelInstance!.tables.values.first;
          List<String> tempSubjects = [];
          
          if (sheet.maxRows > 0) {
            var row = sheet.rows.first;
            // الأعمدة من E إلى S تعني برمجياً الإندكس من 4 إلى 18
            for (int i = 4; i <= 18; i++) {
              if (i < row.length && row[i] != null) {
                tempSubjects.add(row[i]!.value.toString());
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

  // 2. دالة معالجة الصورة الذكية عبر الكاميرا
  Future<void> _processCapturedImage(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrValue = barcodes.first.rawValue!;
      
      // إيقاف مؤقت للسماح للمستخدم بالمراجعة والتعديل يدوياً
      _cameraController.stop();

      if (capture.image != null) {
        final InputImage inputImage = InputImage.fromBytes(
          bytes: capture.image!,
          metadata: InputImageMetadata(
            size: Size(capture.size.width, capture.size.height),
            rotation: InputImageRotation.rotation0deg, 
            format: InputImageFormat.nv21, 
            bytesPerRow: capture.size.width.toInt(), 
          ),
        );

        try {
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          List<Map<String, dynamic>> textElements = [];

          for (TextBlock block in recognizedText.blocks) {
            for (TextLine line in block.lines) {
              String cleanText = _extractDigits(line.text.trim());
              if (cleanText.isNotEmpty) {
                textElements.add({
                  'text': cleanText,
                  'x': line.boundingBox.left, 
                });
              }
            }
          }

          String detectedSubjectCode = "";
          String detectedGrade = "";

          if (textElements.isNotEmpty) {
            textElements.sort((a, b) => a['x'].compareTo(b['x']));

            if (textElements.length >= 2) {
              detectedSubjectCode = textElements.first['text']; 
              detectedGrade = textElements.last['text'];        
            } else if (textElements.length == 1) {
              detectedGrade = textElements.first['text'];
            }
          }

          int currentSubjectIndex = _subjects.indexOf(_selectedSubject!) + 1; 

          if (detectedSubjectCode.isNotEmpty && detectedSubjectCode != currentSubjectIndex.toString()) {
            _showSnackBar("⚠️ كود المادة ($detectedSubjectCode) لا يطابق المادة المختارة!");
            _cameraController.start(); 
            return;
          }

          setState(() {
            _secretIdResult = qrValue; 
            if (detectedGrade.isNotEmpty) {
              _gradeController.text = detectedGrade; 
            }
          });

        } catch (e) {
          setState(() {
            _secretIdResult = qrValue;
          });
          _showSnackBar("تم التقاط الرقم السري. يرجى كتابة الدرجة يدوياً.");
        }
      } else {
        setState(() {
          _secretIdResult = qrValue;
        });
      }
    }
  }

  // 3. دالة البحث وحفظ الدرجة في ملف الأكسيل الأصلي وإعادة تشغيل الكاميرا
  Future<void> _saveGradeToExcel() async {
    if (_excelInstance == null || _selectedFilePath == null) {
      _showSnackBar("⚠️ خطأ: لم يتم تحميل ملف إكسيل!");
      return;
    }
    if (_secretIdResult == "سيظهر هنا الرقم السري" || _secretIdResult.isEmpty) {
      _showSnackBar("⚠️ خطأ: لا يوجد رقم سري لحفظه!");
      return;
    }
    if (_gradeController.text.isEmpty) {
      _showSnackBar("⚠️ يرجى إدخال أو مراجعة الدرجة أولاً!");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var sheet = _excelInstance!.tables.values.first;
      bool targetFound = false;

      // تحديد رقم العمود الخاص بالمادة المختارة
      // الترتيب يبدأ من العمود E (اندكس 4)
      int subjectColumnIndex = 4 + _subjects.indexOf(_selectedSubject!);

      // البحث عن صف الطالب بواسطة الرقم السري (بافتراض أن الرقم السري في العمود الأول A أو الثاني B)
      // سنبحث في أول عمودين للتأكد من مطابقة الرقم السري
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        var cellA = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value;
        var cellB = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value;

        if (cellA.toString().trim() == _secretIdResult.trim() || cellB.toString().trim() == _secretIdResult.trim()) {
          // إسقاط الدرجة في خانة المادة المحددة لهذا الصف
          var targetCell = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: subjectColumnIndex, rowIndex: rowIndex));
          targetCell.value = px.TextCellValue(_gradeController.text);
          targetFound = true;
          break;
        }
      }

      if (!targetFound) {
        _showSnackBar("❌ لم يتم العثور على الرقم السري ($_secretIdResult) داخل ملف الإكسيل!");
        setState(() { _isLoading = false; });
        return;
      }

      // حفظ التعديلات وكتابتها في نفس مسار الملف الأصلي تماماً
      final bytes = _excelInstance!.encode();
      if (bytes != null) {
        final file = File(_selectedFilePath!);
        await file.writeAsBytes(bytes, flush: true);
        
        setState(() {
          _gradedStudents += 1;
          // تصفير الحقول للعملية التالية
          _secretIdResult = "سيظهر هنا الرقم السري";
          _gradeController.clear();
        });

        _showSnackBar("💾 تم حفظ الدرجة بنجاح في الملف الأصلي!");

        // إعادة تفعيل الكاميرا تلقائياً للورقة التالية
        if (_isScanningActive) {
          _cameraController.start();
        }
      }
    } catch (e) {
      _showSnackBar("❌ فشل أثناء حفظ وتعديل الملف: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

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
    _textRecognizer.close(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primaryPurple = const Color(0xFF7B1FA2);
    Color fieldColor = const Color(0xFF212121);

    // تفعيل زر الحفظ فقط عند وجود بيانات جاهزة للحفظ
    bool isSaveButtonEnabled = _secretIdResult != "سيظهر هنا الرقم السري" && !_isLoading;

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
                        "الدرجة المكتشفة (يمكنك تعديلها) :",
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
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
            
            // زر حفظ الدرجة المحدث
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: isSaveButtonEnabled ? _saveGradeToExcel : null, 
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                : const Text(
                    "تأكيد وحفظ الدرجة في الملف الأصلي",
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
            ),
            const SizedBox(height: 20),

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
