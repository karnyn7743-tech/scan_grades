import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/background_service.dart';
import 'services/license_service.dart';
import 'views/activation_view.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. طلب الأذونات المطلوبة قبل بدء الخدمة
  await _requestPermissions();

  // 2. تهيئة وتشغيل خدمة الخلفية والإشعارات
  await BackgroundServiceHelper.initializeService();

  // 3. التحقق من حالة تفعيل التطبيق للجهاز
  bool isActivated = await LicenseService.isAppActivated();

  runApp(WifiP2PApp(isActivated: isActivated));
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

class WifiP2PApp extends StatefulWidget {
  final bool isActivated;

  const WifiP2PApp({Key? key, required this.isActivated}) : super(key: key);

  @override
  State<WifiP2PApp> createState() => _WifiP2PAppState();
}

class _WifiP2PAppState extends State<WifiP2PApp> {
  late bool _isActivated;

  @override
  void initState() {
    super.initState();
    _isActivated = widget.isActivated;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'طالوت الهاشمي للإتصالات المحلية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _isActivated
          ? const HomeScreen()
          : ActivationView(
              onActivated: () {
                setState(() {
                  _isActivated = true;
                });
              },
            ),
    );
  }
}
