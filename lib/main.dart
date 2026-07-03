import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart'; // استيراد المكتبة لحل مشكلة XFile المفقودة

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
          setState(() { _isDarkMode = newTheme; });
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
    returnImage: true, // فرض إعادة البايتات الصورية الكاملة بدقة عالية
  );
  bool _isScanningActive = false;
  bool _isTorchOn = false;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  px.Excel? _excelInstance;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    await Permission.storage.request();
    await Permission.camera.request();
  }

  Future<void> _pickAndParseExcel() async {
    await _requestStoragePermission();
    setState(() { _isLoading = true; });

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
        }
      }
    } catch (e) {
      setState(() { _fileName = "فشل في قراءة ملف الأكسيل"; });
      _showSnackBar("حدث خطأ أثناء المعالجة: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  String _convertArabicHindiDigits(String input) {
    var arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String output = input;
    for (int i = 0; i < arabicNumbers.length; i++) {
      output = output.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    return output.replaceAll(RegExp(r'[^0-9]'), ''); 
  }

  // معالجة بايتات اللقطة المستقرة لحل مشكلة التعارض البرمجي القديم
  Future<void> _processCapturedImage(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrValue = barcodes.first.rawValue!;
      
      // إيقاف الفحص الحي مؤقتاً لتثبيت القراءة
      await _cameraController.stop();

      setState(() {
        _secretIdResult = qrValue;
        _gradeController.clear();
      });

      // التحقق من وصول البايتات الصورية النقية من الكاميرا
      if (capture.image != null) {
        // إعطاء مهلة 200 ملي ثانية لتأكيد معالجة مصفوفة النصوص بوضوح
        await Future.delayed(const Duration(milliseconds: 200));

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
              String convertedText = _convertArabicHindiDigits(line.text.trim());
              if (convertedText.isNotEmpty) {
                textElements.add({
                  'text': convertedText,
                  'x': line.boundingBox.left, 
                });
              }
            }
          }

          if (textElements.isNotEmpty) {
            // الترتيب الأفقي التنازلي (من اليمين لليسار)
            textElements.sort((a, b) => b['x'].compareTo(a['x']));

            String detectedSubjectCode = textElements.first['text'];
            String detectedGrade = textElements.length > 1 ? textElements.last['text'] : "";

            int currentSubjectOrder = _subjects.indexOf(_selectedSubject!) + 1;

            // تنبيه مطابقة المادة المدخلة مع القائمة المحددة
            if (detectedSubjectCode != currentSubjectOrder.toString()) {
              _showDialogAlert(
                title: "⚠️ تنبيه مطابقة المادة",
                message: "كود المادة المقروء من الورقة ($detectedSubjectCode) لا يطابق المادة المختارة من القائمة (${_selectedSubject} - رقم $currentSubjectOrder).\n\nسيتم إغلاق الكاميرا لحماية البيانات.",
                shouldCloseCamera: true
              );
              return; 
            }

            setState(() {
              if (detectedGrade.isNotEmpty) {
                _gradeController.text = detectedGrade;
                _showSnackBar("✅ تم مطابقة المادة وقراءة الدرجة ($detectedGrade) بنجاح.");
              } else {
                _showSnackBar("ℹ️ تم مطابقة المادة، يرجى كتابة الدرجة يدوياً.");
              }
            });
          } else {
            _showSnackBar("ℹ️ لم يتم رصد أرقام واضحة حول الـ QR. يرجى إدخال البيانات يدوياً.");
          }
        } catch (e) {
          _showSnackBar("تنبيه الـ OCR: لم تتم قراءة النصوص، يرجى الإدخال اليدوي.");
        }
      }
    }
  }

  Future<void> _saveGradeToExcel() async {
    if (_excelInstance == null || _selectedFilePath == null) {
      _showSnackBar("⚠️ خطأ: لم يتم تحميل ملف إكسيل!");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      var sheet = _excelInstance!.tables.values.first;
      bool targetFound = false;
      int subjectColumnIndex = 4 + _subjects.indexOf(_selectedSubject!);

      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        var cellA = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value;
        var cellB = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value;

        if (cellA.toString().trim() == _secretIdResult.trim() || cellB.toString().trim() == _secretIdResult.trim()) {
          targetFound = true;

          var existingValue = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: subjectColumnIndex, rowIndex: rowIndex)).value;
          if (existingValue != null && existingValue.toString().trim().isNotEmpty) {
            setState(() { _isLoading = false; });
            _showDialogAlert(
              title: "⚠️ تنبيه: رصد مسبق!",
              message: "هذا الطالب (الرقم السري: $_secretIdResult) تم رصد درجته مسبقاً في مادة $_selectedSubject وهي (${existingValue.toString()}).",
              shouldCloseCamera: false
            );
            return; 
          }

          sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: subjectColumnIndex, rowIndex: rowIndex)).value = px.TextCellValue(_gradeController.text);
          break;
        }
      }

      if (!targetFound) {
        _showSnackBar("❌ لم يتم العثور على الرقم السري ($_secretIdResult) في الملف!");
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

        _showSnackBar("💾 تم حفظ وتأكيد الدرجة في ملف الكنترول بنجاح!");

        if (_isScanningActive) {
          await _cameraController.start();
          if (_isTorchOn) await _cameraController.toggleTorch();
        }
      }
    } catch (e) {
      _showSnackBar("❌ فشل كتابة وتعديل الملف: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showDialogAlert({required String title, required String message, required bool shouldCloseCamera}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text("حسناً"),
              onPressed: () {
                Navigator.of(context).pop();
                if (shouldCloseCamera) {
                  setState(() { _isScanningActive = false; });
                } else {
                  if (_isScanningActive) _cameraController.start();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleScanning() async {
    if (_selectedSubject == null) {
      _showSnackBar("يرجى اختيار المادة المراد رصدها أولاً قبل بدء المسح!");
      return;
    }

    setState(() { _isScanningActive = !_isScanningActive; });

    if (_isScanningActive) {
      await _cameraController.start();
      if (_isTorchOn) await _cameraController.toggleTorch();
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
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              setState(() { _isTorchOn = !_isTorchOn; });
              if (_isScanningActive) await _cameraController.toggleTorch();
            }, 
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: _isLoading ? null : _pickAndParseExcel, 
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("اختر ملف الأكسيل الأصلي", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: Text(_fileName, style: TextStyle(color: textColor), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),

            Align(alignment: Alignment.centerRight, child: Text("اختر المادة :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: const Text("انقر لتحديد المادة المفتوحة ورصدها", style: TextStyle(color: Colors.grey)),
                  value: _selectedSubject,
                  items: _subjects.isEmpty ? null : _subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub, style: TextStyle(color: textColor)))).toList(),
                  onChanged: (val) { setState(() { _selectedSubject = val; }); },
                ),
              ),
            ),
            const SizedBox(height: 12),

            Align(alignment: Alignment.centerRight, child: Text("الرقم السري :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: Text(_secretIdResult, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("الدرجة (يمكنك تعديلها) :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: fieldColor,
                          filled: true,
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                      Text("العداد :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade500)),
                        child: Text("$_gradedStudents / $_totalStudents", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isScanningActive ? Colors.red : Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: _toggleScanning, 
              child: Text(_isScanningActive ? "إيقاف المسح مؤقتاً" : "ابدأ المسح بالكاميرا", style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size.fromHeight(50)),
              onPressed: isSaveButtonEnabled ? _saveGradeToExcel : null, 
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                : const Text("تأكيد وحفظ الدرجة في الملف الأصلي", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isScanningActive ? Colors.greenAccent : Colors.grey, width: 2)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isScanningActive
                    ? MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          _processCapturedImage(capture);
                        },
                      )
                    : const Center(child: Text("انقر فوق 'ابدأ المسح بالكاميرا' لتشغيل الفحص الحي", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
