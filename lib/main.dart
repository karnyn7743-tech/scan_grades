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

class StugraScanApp extends StatefulWidget {
  const StugraScanApp({super.key});

  @override
  State<StugraScanApp> createState() => _StugraScanAppState();
}

class _StugraScanAppState extends State<StugraScanApp> {
  // متغيّر للتحكم في الوضع الليلي والنهاري للتطبيق بالكامل
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StugraScan',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: MainScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: (bool newTheme) {
          setState(() {
            _isDarkMode = newTheme;
          });
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

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
  px.Excel? _excelInstance;

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

  Future<void> _processCapturedImage(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrValue = barcodes.first.rawValue!;
      
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

      int subjectColumnIndex = 4 + _subjects.indexOf(_selectedSubject!);

      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        var cellA = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value;
        var cellB = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value;

        if (cellA.toString().trim() == _secretIdResult.trim() || cellB.toString().trim() == _secretIdResult.trim()) {
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

      final bytes = _excelInstance!.encode();
      if (bytes != null) {
        final file = File(_selectedFilePath!);
        await file.writeAsBytes(bytes, flush: true);
        
        setState(() {
          _gradedStudents += 1;
          _secretIdResult = "سيظهر هنا الرقم السري";
          _gradeController.clear();
        });

        _showSnackBar("💾 تم حفظ الدرجة بنجاح في الملف الأصلي!");

        // عند إعادة التشغيل التلقائي للكاميرا، نضمن بقاء الفلاش يعمل إذا كان المستخدم قد فعله
        if (_isScanningActive) {
          await _cameraController.start();
          if (_isTorchOn) {
            await _cameraController.toggleTorch();
          }
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

  void _toggleScanning() async {
    if (_selectedSubject == null) {
      _showSnackBar("يرجى اختيار المادة المراد رصدها أولاً قبل بدء المسح!");
      return;
    }

    setState(() {
      _isScanningActive = !_isScanningActive;
    });

    if (_isScanningActive) {
      await _cameraController.start();
      // تشغيل فلاش المصابيح تلقائياً عند بدء المسح إذا كانت وضعيته On
      if (_isTorchOn) {
        await _cameraController.toggleTorch();
      }
    } else {
      await _cameraController.stop();
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
    // تنسيق الألوان لتتغير ديناميكياً مع الثيم (ليلي / نهاري)
    Color appBarColor = widget.isDarkMode ? const Color(0xFF7B1FA2) : Colors.purple;
    Color backgroundColor = widget.isDarkMode ? const Color(0xFF4A148C) : Colors.purple.shade50;
    Color fieldColor = widget.isDarkMode ? const Color(0xFF212121) : Colors.white;
    Color textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    bool isSaveButtonEnabled = _secretIdResult != "سيظهر هنا الرقم السري" && !_isLoading;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("برنامج إسقاط الدرجات بالأكواد"),
        centerTitle: true,
        backgroundColor: appBarColor,
        actions: [
          // 1. زر التحكم بالفلاش وتجهيزه للمسح الضوئي
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'تحضير الفلاش للمسح الضوئي',
            onPressed: () async {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              // إذا كانت الكاميرا تعمل بالفعل، نغير حالة الفلاش فوراً
              if (_isScanningActive) {
                await _cameraController.toggleTorch();
              } else {
                _showSnackBar(_isTorchOn ? "💡 تم تحضير الفلاش (سيعمل تلقائياً عند فتح الكاميرا)" : "🔕 تم إيقاف الفلاش التلقائي");
              }
            }, 
          ),
          // 2. زر التبديل بين الوضع الليلي والنهاري
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'الوضع النهاري' : 'الوضع الليلي',
            onPressed: () {
              widget.onThemeChanged(!widget.isDarkMode);
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
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(
                _fileName,
                style: TextStyle(color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "اختر المادة :",
                style: TextStyle(
                  color: textColor,
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
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: const Text(
                    "انقر لتحديد المادة المفتوحة ورصدها",
                    style: TextStyle(color: Colors.grey),
                  ),
                  value: _selectedSubject,
                  items: _subjects.isEmpty ? null : _subjects
                      .map(
                        (sub) => DropdownMenuItem(
                          value: sub,
                          child: Text(
                            sub,
                            style: TextStyle(color: textColor),
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

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "الرقم السري :",
                style: TextStyle(
                  color: textColor,
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
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(
                _secretIdResult,
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
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
                      Text(
                        "الدرجة (يمكنك تعديلها) :",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: fieldColor,
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                      Text(
                        "العداد :",
                        style: TextStyle(
                          color: textColor,
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
                          border: Border.all(color: Colors.grey.shade500),
                        ),
                        child: Text(
                          "$_gradedStudents / $_totalStudents",
                          style: const TextStyle(
                            color: Colors.green,
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
