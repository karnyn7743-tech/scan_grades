import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  // التأكد من تهيئة الـ Widgets قبل طلب الأذونات
  WidgetsFlutterBinding.ensureInitialized();

  // طلب أذونات الكاميرا والتخزين عند بدء التشغيل
  // (هذا يحسن تجربة المستخدم بدلاً من طلبها لاحقاً)
  await [
    Permission.camera,
    Permission.storage,
    Permission.manageExternalStorage, // للأندرويد 11+
  ].request();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدخال الدرجات',
      
      // إلغاء شريط Debug
      debugShowCheckedModeBanner: false,
      
      // إتجاه النصوص من اليمين لليسار (للدعم الكامل للغة العربية)
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      
      // الثيم الأساسي
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Cairo', // يمكنك إضافة خط Cairo في pubspec.yaml
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      
      // الصفحة الرئيسية (شاشة البداية)
      home: HomeScreen(),
    );
  }
}
