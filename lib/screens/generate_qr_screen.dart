import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrscan_plus/qrscan_plus.dart' as scanner;

class GenerateQRScreen extends StatefulWidget {
  const GenerateQRScreen({super.key});

  @override
  State<GenerateQRScreen> createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  String? _excelPath;
  bool _isLoading = false;
  List<Map<String, String>> _students = [];
  String _statusMessage = '';

  // ===================== دالة المسار العام لمجلد Downloads =====================
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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadLastExcelFile();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> _loadLastExcelFile() async {
    try {
      final String gradesDir = await _getGradesDirectoryPath();
      final Directory dir = Directory(gradesDir);
      if (!await dir.exists()) return;

      final List<FileSystemEntity> files = await dir.list().toList();
      for (var entity in files) {
        if (entity is File && (entity.path.endsWith('.xlsx') || entity.path.endsWith('.xls'))) {
          setState(() {
            _excelPath = entity.path;
          });
          await _parseExcel();
          break;
        }
      }
    } catch (e) {
      print('خطأ في تحميل آخر ملف: $e');
    }
  }

  Future<void> _pickExcelFile() async {
    setState(() { _isLoading = true; });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm, 'xlsb],
      );

      if (result != null && result.files.single.path != null) {
        final String sourcePath = result.files.single.path!;
        final String fileName = result.files.single.name;

        final String gradesDir = await _getGradesDirectoryPath();
        final String targetPath = '$gradesDir/$fileName';

        if (await File(targetPath).exists()) {
          await File(targetPath).delete();
        }
        await File(sourcePath).copy(targetPath);

        setState(() {
          _excelPath = targetPath;
        });

        await _parseExcel();
        _showMessage('✅ تم نسخ الملف إلى: $targetPath');
      } else {
        _showMessage('لم يتم اختيار ملف');
      }
    } catch (e) {
      _showMessage('خطأ: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _parseExcel() async {
    if (_excelPath == null) return;

    try {
      final bytes = await File(_excelPath!).readAsBytes();
      final excel = px.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      _students.clear();

      for (int row = 1; row < sheet.maxRows; row++) {
        final cellA = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value;
        final cellB = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value;
        final cellD = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value;

        if (cellA != null && cellA.toString().trim().isNotEmpty &&
            cellD != null && cellD.toString().trim().isNotEmpty) {
          _students.add({
            'id': cellA.toString().trim(),
            'name': cellB?.toString().trim() ?? '',
            'secret': cellD.toString().trim(),
          });
        }
      }

      setState(() {
        _statusMessage = 'تم تحميل ${_students.length} طالب';
      });

      _showDuplicatesDialog();

    } catch (e) {
      _showMessage('خطأ في قراءة الملف: $e');
    }
  }

  void _showDuplicatesDialog() {
    final Map<String, List<String>> duplicateMap = {};
    final Map<String, String> secretToName = {};

    for (var student in _students) {
      final secret = student['secret']!;
      final name = student['name']!;

      if (secretToName.containsKey(secret)) {
        duplicateMap.putIfAbsent(secret, () => [secretToName[secret]!]);
        duplicateMap[secret]!.add(name);
      } else {
        secretToName[secret] = name;
      }
    }

    final duplicates = duplicateMap.keys.where((key) => duplicateMap[key]!.length > 1).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('التحقق من التكرار'),
        content: duplicates.isEmpty
            ? const Text('✅ لا يوجد تكرار في الأرقام السرية. يمكنك المتابعة لتوليد الـ QR Codes.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ تم العثور على تكرار في الأرقام السرية التالية:'),
                  const SizedBox(height: 10),
                  ...duplicates.map((secret) {
                    final names = duplicateMap[secret]!.join('، ');
                    return Text('• الرقم السري "$secret" مكرر للطلاب: $names');
                  }).toList(),
                  const SizedBox(height: 10),
                  const Text('يرجى تعديل البيانات في ملف Excel ثم إعادة المحاولة.'),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          if (duplicates.isEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateQRCodes();
              },
              child: const Text('توليد QR Codes'),
            ),
        ],
      ),
    );
  }

  Future<void> _generateQRCodes() async {
    if (_students.isEmpty) {
      _showMessage('لا يوجد طلاب لتوليد QR Codes لهم');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // حفظ مجلد qr_pict في Downloads/درجات الطلاب
      final String gradesDir = await _getGradesDirectoryPath();
      final String qrFolderPath = '$gradesDir/qr_pict';

      final Directory qrFolder = Directory(qrFolderPath);
      if (await qrFolder.exists()) {
        await qrFolder.delete(recursive: true);
      }
      await qrFolder.create(recursive: true);

      int count = 0;
      for (var student in _students) {
        final String id = student['id']!;
        final String secret = student['secret']!;

        final Uint8List qrBytes = await scanner.generateBarCode(secret);

        final String filePath = '$qrFolderPath/$id.png';
        final File file = File(filePath);
        await file.writeAsBytes(qrBytes);

        count++;
      }

      setState(() {
        _statusMessage = '✅ تم توليد $count رمز QR في المجلد: $qrFolderPath';
      });

      _showMessage('تم توليد $count رمز QR بنجاح في:\n$qrFolderPath');

    } catch (e) {
      _showMessage('خطأ في توليد QR Codes: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تكوين رموز استجابة سريعة للطلاب'),
        backgroundColor: Colors.lightBlue.shade300,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickExcelFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختيار ملف الأكسيل'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            if (_excelPath != null)
              Text('📁 ${_excelPath!.split('/').last}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              Text(_statusMessage, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
