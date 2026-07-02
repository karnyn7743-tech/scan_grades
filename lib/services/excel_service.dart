import 'dart:io';
import 'package:excel/excel.dart';

class ExcelService {
  String? currentFilePath;
  Excel? excelInstance;
  String? sheetName;

  // جلب الأسماء من العمود E (كود 1) إلى S (كود 15)
  List<String> getSubjectHeaders(String filePath) {
    currentFilePath = filePath;
    var bytes = File(filePath).readAsBytesSync();
    excelInstance = Excel.decodeBytes(bytes);
    sheetName = excelInstance!.tables.keys.first;
    
    var sheet = excelInstance!.tables[sheetName]!;
    List<String> subjects = [];
    
    if (sheet.maxCols > 4) {
      // من العمود 4 (Index 4 وهو E) إلى العمود 18 (Index 18 وهو S)
      for (int i = 4; i <= 18; i++) {
        if (i < sheet.maxCols && sheet.rows[0][i] != null) {
          subjects.add(sheet.rows[0][i]!.value.toString());
        }
      }
    }
    return subjects;
  }

  // التحقق من وجود رقم سري مسجل وحالة الدرجة مسبقاً
  Map<String, dynamic> checkStudentStatus(String secretId, int subjectColumnIndex) {
    var sheet = excelInstance!.tables[sheetName]!;
    for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      var row = sheet.rows[rowIndex];
      if (row[3]?.value.toString() == secretId) { // العمود D (Index 3) الرقم السري
        var existingGrade = row[subjectColumnIndex]?.value;
        if (existingGrade != null && existingGrade.toString().trim().isNotEmpty) {
          return {'exists': true, 'hasGrade': true, 'rowIndex': rowIndex};
        }
        return {'exists': true, 'hasGrade': false, 'rowIndex': rowIndex};
      }
    }
    return {'exists': false, 'hasGrade': false, 'rowIndex': -1};
  }

  // حفظ الدرجة في الخلية المستهدفة بشكل فوري
  void saveGrade(int rowIndex, int subjectColumnIndex, String grade) {
    var sheet = excelInstance!.tables[sheetName]!;
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: subjectColumnIndex, rowIndex: rowIndex),
      CellValue.withValue(double.tryParse(grade) ?? grade),
    );
    
    // حفظ التعديلات على الملف الأصلي أوفلاين
    var fileBytes = excelInstance!.encode();
    if (fileBytes != null && currentFilePath != null) {
      File(currentFilePath!)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }
  }

  // حساب الإحصائيات (العدد الكلي والطلاب الذين تم رصد درجاتهم)
  Map<String, int> getStatistics(int subjectColumnIndex) {
    var sheet = excelInstance!.tables[sheetName]!;
    int totalStudents = sheet.maxRows - 1;
    int gradedStudents = 0;

    for (int i = 1; i < sheet.maxRows; i++) {
      var cellValue = sheet.rows[i][subjectColumnIndex]?.value;
      if (cellValue != null && cellValue.toString().trim().isNotEmpty) {
        gradedStudents++;
      }
    }
    return {'total': totalStudents, 'graded': gradedStudents};
  }
}