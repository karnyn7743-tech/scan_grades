import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const WifiP2PApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.microphone,
    Permission.camera,
    Permission.location,
    Permission.nearbyWifiDevices,
  ].request();
}

class WifiP2PApp extends StatelessWidget {
  const WifiP2PApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اتصال الواي فاي المحلي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
