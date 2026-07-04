import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام الدرجات',
      debugShowCheckedModeBanner: false,

      // === ثيم النهار (Light) ===
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.lightBlue,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.lightBlue.shade50,
        useMaterial3: true,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

      // === ثيم الليل (Dark) ===
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.indigo.shade700,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        fontFamily: 'Cairo',
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: Colors.indigo.shade900,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

      // === الوضع المختلط: يتبع إعدادات النظام ===
      themeMode: ThemeMode.system, // ← هذا السطر السحري

      home: const HomeScreen(),
    );
  }
}
