import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/excel_service.dart';
import '../services/qr_service.dart';
import '../services/ocr_service.dart';
import '../services/image_service.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ExcelService _excelService = ExcelService();
  final QrService _qrService = QrService();
  final OcrService _ocrService = OcrService();
  final ImageService _imageService = ImageService();

  String _filePath = "لم يتم اختيار ملف بعد";
  List<String> _subjectsList = [];
  String? _selectedSubject;

  String _studentName = "في انتظار المسح...";
  String _studentCode = "----";
  final TextEditingController _gradeController = TextEditingController();

  bool _isFileLoaded = false;
  int _scanCounter = 0;

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      bool success = _excelService.loadExcel(result.files.single.bytes!);
      if (success) {
        setState(() {
          _filePath = result.files.single.name;
          _isFileLoaded = true;
          _subjectsList = _excelService.getSubjects();
          _selectedSubject =
              _subjectsList.isNotEmpty ? _subjectsList.first : null;
          _scanCounter = 0;
        });
      }
    }
  }

  // دالة زر بدء المسح (قرائة الـ QR من العمود 4 ثم الـ OCR من اليسار)
  Future<void> _startLiveScan() async {
    if (!_isFileLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف أكسيل أولاً')),
      );
      return;
    }

    var imageBytes = await _imageService.pickImage();
    if (imageBytes == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('جاري معالجة الـ QR وقراءة الدرجة عبر الـ OCR...')),
    );

    String scannedQR =
        await _qrService.scanQrFromImage(imageBytes, _scanCounter);
    var studentInfo = _excelService.getStudentByQR(scannedQR);
    String scannedGrade = await _ocrService.readGradeFromLeftOfQr(imageBytes);

    if (studentInfo != null) {
      setState(() {
        _studentName = studentInfo['name']!;
        _studentCode = studentInfo['code']!;
        _gradeController.text = scannedGrade;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('الكود السري ($scannedQR) غير موجود في العمود الرابع!')),
      );
    }
  }

  void _saveData() {
    if (_studentCode == "----" ||
        _gradeController.text.isEmpty ||
        _selectedSubject == null) return;

    bool success = _excelService.saveGrade(
        _studentCode, _selectedSubject!, _gradeController.text);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رصد درجة الطالب $_studentName بنجاح!')),
      );
      setState(() {
        _scanCounter++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام أبو الخضر لرصد الدرجات المطور'),
          centerTitle: true,
          backgroundColor: Colors.blue.shade800,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickExcelFile,
                        icon: const Icon(Icons.file_open),
                        label: const Text('اختيار ملف الأكسيل لكشف الدرجات'),
                      ),
                      const SizedBox(height: 10),
                      Text('الملف الحالي: $_filePath',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Text('اختر المادة المراد رصدها: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedSubject,
                          isExpanded: true,
                          items: _subjectsList
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedSubject = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Card(
                color: Colors.blue.shade50,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('📊 شاشة المراقبة والتحقق المستمر',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('اسم الطالب: $_studentName',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          Text('الرقم السري: $_studentCode',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('الدرجة المقروءة (OCR): ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _gradeController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _saveData,
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green, size: 38),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _startLiveScan,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text('البدء بمسح كود QR والدرجة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
