import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'services/excel_service.dart';
import 'services/ocr_barcode_service.dart';
import 'utils/digit_converter.dart';

void main() {
  // تهيئة واجهات فلوتر الأساسية بشكل سليم ومستقر
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StugraScanApp());
}

class StugraScanApp extends StatefulWidget {
  const StugraScanApp({super.key});

  @override
  State<StugraScanApp> createState() => _StugraScanAppState();
}

class _StugraScanAppState extends State<StugraScanApp> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StugraScan',
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: MainScreen(
        isDarkMode: isDarkMode,
        onThemeChanged: (val) => setState(() => isDarkMode = val),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MainScreen({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ExcelService _excelService = ExcelService();
  final OcrBarcodeService _ocrBarcodeService = OcrBarcodeService();
  
  CameraController? _cameraController;
  String _fileName = "لم يتم اختيار ملف";
  List<String> _subjects = [];
  String? _selectedSubject;
  int _selectedSubjectIndex = -1;
  
  String _secretIdResult = "سيظهر هنا الرقم السري";
  final TextEditingController _gradeController = TextEditingController();
  
  int _totalStudents = 0;
  int _gradedStudents = 0;
  bool _isFlashOn = false;
  int? _activeRowIndex;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    // استدعاء جلب الصلاحيات وتهيئة الكاميرا بعد تحميل الواجهات لمنع الانهيار
    _initializeCameraAndPermissions();
  }

  Future<void> _initializeCameraAndPermissions() async {
    // 1. طلب الصلاحيات بشكل تتابعي آمن ومتوافق مع نظام أندرويد
    var cameraStatus = await Permission.camera.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    // 2. فحص حالة الاستجابة واستدعاء الكاميرات داخل البلوك بشكل محمي
    if (cameraStatus.isGranted) {
      try {
        final availableDevices = await availableCameras();
        if (availableDevices.isNotEmpty) {
          _cameraController = CameraController(
            availableDevices.first,
            ResolutionPreset.medium,
            enableAudio: false,
          );

          await _cameraController!.initialize();
          if (mounted) {
            setState(() {
              _isCameraInitialized = true;
            });
          }
        }
      } catch (e) {
        debugPrint("تعذر تهيئة عتاد الكاميرا الداخلي: $e");
      }
    }
  }

  Future<void> _pickExcelFile() async {
    String targetPath = "/storage/emulated/0/Download/درجات الطلاب";
    Directory targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      setState(() {
        _fileName = result.files.single.name;
        _subjects = _excelService.getSubjectHeaders(filePath);
        _selectedSubject = null;
        _selectedSubjectIndex = -1;
        _totalStudents = 0;
        _gradedStudents = 0;
      });
    }
  }

  void _updateStats() {
    if (_selectedSubjectIndex != -1) {
      var stats = _excelService.getStatistics(_selectedSubjectIndex);
      setState(() {
        _totalStudents = stats['total']!;
        _gradedStudents = stats['graded']!;
      });
    }
  }

  Future<void> _captureAndScan() async {
    if (_selectedSubjectIndex == -1 || _cameraController == null || !_cameraController!.value.isInitialized) {
      _showDialog("تنبيه", "الرجاء اختيار ملف إكسل والمادة أولاً وتفعيل الكاميرا.");
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      final results = await _ocrBarcodeService.processImageSection(image);
      
      String rawText = results['text'] ?? "";
      String scannedQrCode = results['qr'] ?? "";

      if (scannedQrCode.isEmpty) {
        _showDialog("تنبيه", "لم يتم العثور على رمز استجابة سريع (QR) في هذه المنطقة!");
        return;
      }

      var status = _excelService.checkStudentStatus(scannedQrCode, _selectedSubjectIndex);
      if (!status['exists']) {
        _showDialog("تنبيه", "طالب غير موجود!");
        return;
      }

      if (status['hasGrade']) {
        _showDialog("تنبيه", "تم بالفعل إدخل درجة هذا الطالب مسبقاً.");
        return;
      }

      int expectedCode = _selectedSubjectIndex - 3; 
      
      if (!rawText.contains(expectedCode.toString())) {
        _showDialog("تنبيه", "المادة التي ستدخل درجاتها ليست التي تم اختيارها!");
        return;
      }

      String cleanGrade = DigitConverter.cleanAndConvert(rawText.replaceAll(expectedCode.toString(), ""));

      setState(() {
        _secretIdResult = scannedQrCode;
        _activeRowIndex = status['rowIndex'];
        _gradeController.text = cleanGrade;
      });

    } catch (e) {
      _showDialog("خطأ", "حدث خطأ أثناء التقاط الصورة: $e");
    }
  }

  void _saveGradeToExcel() {
    if (_activeRowIndex != null && _selectedSubjectIndex != -1 && _gradeController.text.isNotEmpty) {
      _excelService.saveGrade(_activeRowIndex!, _selectedSubjectIndex, _gradeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم حفظ الدرجة في الملف بنجاح أوفلاين")),
      );
      _updateStats();
      
      setState(() {
        _secretIdResult = "سيظهر هنا الرقم السري";
        _gradeController.clear();
        _activeRowIndex = null;
      });
    }
  }

  void _toggleFlash() async {
    if (_cameraController != null && _isCameraInitialized) {
      setState(() => _isFlashOn = !_isFlashOn);
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right),
        content: Text(content, textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("موافق"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ocrBarcodeService.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color primaryPurple = const Color(0xFF7B1FA2);
    Color fieldColor = const Color(0xFF212121);

    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF4A148C) : Colors.white,
      appBar: AppBar(
        title: const Text("برنامج إسقاط الدرجات بالأكواد"),
        centerTitle: true,
        backgroundColor: primaryPurple,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
          Switch(
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: _pickExcelFile,
              child: const Text("اختر ملف الأكسيل", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: Text(_fileName, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            
            const Align(alignment: Alignment.centerRight, child: Text("اختر المادة :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: Text(_subjects.isEmpty ? "اختر ملف Excel أولاً" : "انقر لتحديد المادة", style: const TextStyle(color: Colors.grey)),
                  value: _selectedSubject,
                  items: _subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubject = val;
                      _selectedSubjectIndex = _subjects.indexOf(val!) + 4;
                    });
                    _updateStats();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Align(alignment: Alignment.centerRight, child: Text("الرقم السري :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular(8)),
              child: Text(_secretIdResult, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),

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

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: _selectedSubjectIndex == -1 ? null : _captureAndScan,
              child: const Text("ابدأ المسح", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: _activeRowIndex == null ? null : _saveGradeToExcel,
              child: const Text("حفظ الدرجة", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey, width: 2)),
              child: _isCameraInitialized && _cameraController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CameraPreview(_cameraController!),
                    )
                  : const Center(
                      child: Text(
                        "جاري تهيئة الكاميرا وطلب الصلاحيات بأمان...",
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
