import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class OcrBarcodeService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  /// دالة لمعالجة الصورة الملتقطة من الكاميرا واستخراج الكود والدرجة والـ QR منها أوفلاين
  Future<Map<String, String>> processImageSection(XFile imageFile) async {
    final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
    
    String detectedText = "";
    String detectedQr = "";

    try {
      // 1. قراءة النصوص المطبوعة والمكتوبة بخط اليد (كود المادة والدرجة)
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      detectedText = recognizedText.text;

      // 2. قراءة الـ QR Code الموجود في نفس المنطقة
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        detectedQr = barcodes.first.rawValue ?? "";
      }
    } catch (e) {
      print("خطأ أثناء معالجة الصورة أوفلاين: $e");
    }

    return {
      'text': detectedText, // يحتوي على الأرقام المطبوعة واليدوية
      'qr': detectedQr      // يحتوي على الرقم السري للطالب
    };
  }

  /// إغلاق المحركات عند قفل التطبيق لتحرير ذاكرة الهاتف
  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}