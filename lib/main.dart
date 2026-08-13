import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/background_service.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // طلب الأذونات المطلوبة قبل بدء الخدمة
  await _requestPermissions();

  // تهيئة وتشغيل خدمة الخلفية والإشعارات
  await BackgroundServiceHelper.initializeService();

  runApp(const WifiP2PApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.microphone,
    Permission.camera,
    Permission.location,
    Permission.nearbyWifiDevices,
    Permission.notification, // طلب إذن الإشعارات لأندرويد 13+
  ].request();
}

class WifiP2PApp extends StatelessWidget {
  const WifiP2PApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'طالوت الهاشمي للإتصالات المحلية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
