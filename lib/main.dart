import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ===== متغير عام للتحكم في الثيم =====
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'نظام الدرجات',
          debugShowCheckedModeBanner: false,

          // === ثيم النهار ===
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.lightBlue.shade700,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.lightBlue.shade50,
            cardColor: Colors.white,
            useMaterial3: true,
            fontFamily: 'Cairo',
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              foregroundColor: Colors.white,
              backgroundColor: Colors.lightBlue,
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
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.black87),
              bodyMedium: TextStyle(color: Colors.black87),
              titleLarge: TextStyle(color: Colors.black87),
            ),
          ),

          // === ثيم الليل ===
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.indigo.shade700,
            primarySwatch: Colors.indigo,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
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
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
              titleLarge: TextStyle(color: Colors.white),
            ),
          ),

          // === التبديل بين الثيمات ===
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          home: HomeScreen(
            onThemeToggle: _toggleTheme, // ← نمرر الدالة
          ),
        );
      },
    );
  }

  // ===== دالة تبديل الثيم =====
  void _toggleTheme() {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
  }
}
