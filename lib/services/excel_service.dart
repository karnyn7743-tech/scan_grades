import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelService {
  Excel? _excel;

  bool loadExcel(Uint8List bytes) {
    try {
      _excel = Excel.decodeBytes(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  List<String> getSubjects() {
    if (_excel == null) return [];
    var sheet = _excel!.tables[_excel!.tables.keys.first];
    if (sheet == null || sheet.maxRows == 0) return [];

    List<String> subjects = [];
    var firstRow = sheet.rows.first;
    for (int i = 4; i < firstRow.length; i++) {
      if (firstRow[i] != null && firstRow[i]!.value != null) {
        subjects.add(firstRow[i]!.value.toString());
      }
    }
    return subjects;
  }

  Map<String, String>? getStudentByQR(String qrCode) {
    if (_excel == null) return null;
    var sheet = _excel!.tables[_excel!.tables.keys.first];
    if (sheet == null) return null;

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.length > 3 &&
          row[3] != null &&
          row[3]!.value.toString() == qrCode) {
        return {
          'name': row[1]?.value?.toString() ?? "طالب مجهول",
          'code': qrCode,
          'rowIndex': i.toString()
        };
      }
    }
    return null;
  }

  bool saveGrade(String qrCode, String subject, String grade) {
    if (_excel == null) return false;
    var sheet = _excel!.tables[_excel!.tables.keys.first];
    if (sheet == null) return false;

    int studentRow = -1;
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.length > 3 &&
          row[3] != null &&
          row[3]!.value.toString() == qrCode) {
        studentRow = i;
        break;
      }
    }

    int subjectCol = -1;
    var firstRow = sheet.rows.first;
    for (int j = 4; j < firstRow.length; j++) {
      if (firstRow[j] != null && firstRow[j]!.value.toString() == subject) {
        subjectCol = j;
        break;
      }
    }

    if (studentRow != -1 && subjectCol != -1) {
      // تعديل طريقة التحديث لتتوافق تماماً مع المكتبة محلياً وتتخلص من مشاكل الأنواع
      var cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: subjectCol, rowIndex: studentRow));
      cell.value = TextCellValue(grade);
      return true;
    }
    return false;
  }
}
