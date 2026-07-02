class StudentModel {
  final String id;          // رقم قيد الطالب (العمود A)
  final String name;        // اسم الطالب (العمود B)
  final String studentClass;// الصف (العمود C)
  final String secretId;    // الرقم السري وهو المعيار عند مسح الـ QR (العمود D)
  final Map<int, String> grades; // خريطة لتخزين درجات المواد (المفاتيح من 1 إلى 15 للأعمدة من E إلى S)

  StudentModel({
    required this.id,
    required this.name,
    required this.studentClass,
    required this.secretId,
    required this.grades,
  });

  /// دالة لتحويل صف من ملف الإكسل إلى كائن طالب (Student Object) لسهولة التعامل معه
  factory StudentModel.fromExcelRow(List<dynamic> row) {
    Map<int, String> studentGrades = {};
    
    // جلب الدرجات تلقائياً من العمود E (ترتيبه 4) إلى العمود S (ترتيبه 18)
    for (int i = 4; i <= 18; i++) {
      if (i < row.length && row[i] != null) {
        int subjectCode = i - 3; // العمود E (Index 4) يعطي كود مادة (1)، والـ F يعطي (2)... وهكذا
        studentGrades[subjectCode] = row[i].value.toString().trim();
      }
    }

    return StudentModel(
      id: row[0]?.value.toString().trim() ?? "",
      name: row[1]?.value.toString().trim() ?? "",
      studentClass: row[2]?.value.toString().trim() ?? "",
      secretId: row[3]?.value.toString().trim() ?? "",
      grades: studentGrades,
    );
  }
}