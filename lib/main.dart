import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // طلب أذونات الكاميرا والتخزين
  await [Permission.camera, Permission.storage].request();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدخال الدرجات',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo', // يمكنك إضافة خط Cairo من pubspec.yaml
        direction: TextDirection.rtl,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
