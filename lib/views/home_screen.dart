import 'package:flutter/material.dart';
import 'dart:io';
import '../services/identity_service.dart';
import '../services/network_discovery_service.dart';
import '../services/p2p_socket_server.dart';
import '../services/contact_service.dart';
import 'chat_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final P2PSocketServer _socketServer = P2PSocketServer();
  
  final Map<String, Map<String, dynamic>> _discoveredDevices = {};
  final int localPort = 4040;
  List<String> _myLocalIps = [];

  @override
  void initState() {
    super.initState();
    _fetchMyLocalIps().then((_) {
      _initNetworkServices();
    });
  }

  Future<void> _fetchMyLocalIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      _myLocalIps = interfaces
          .expand((interface) => interface.addresses)
          .map((addr) => addr.address)
          .toList();
      _myLocalIps.add('127.0.0.1');
    } catch (e) {
      print("خطأ في جلب عناوين IP المحلية: $e");
    }
  }

  Future<void> _initNetworkServices() async {
    await _socketServer.startServer(
      localPort,
      onRequestConnection: (callerId, callerName, socket) {},
      onMessageReceived: (senderIp, msg) {},
    );

    await _discoveryService.startBroadcasting(localPort);

    await _discoveryService.startListening((service) async {
      String resolvedIp = service.host ?? '';

      if (resolvedIp.isNotEmpty) {
        // تحويل أي Hostname إلى IP حقيقي مباشر
        try {
          final addresses = await InternetAddress.lookup(resolvedIp);
          if (addresses.isNotEmpty) {
            resolvedIp = addresses.first.address;
          }
        } catch (_) {}

        // استبعاد IP الجهاز الحالي
        if (!_myLocalIps.contains(resolvedIp)) {
          final deviceName = service.name ?? 'جهاز محلي';
          final port = service.port ?? 4040;

          // جعل كل جهاز جديد موثوقاً تلقائياً
          await IdentityService.trustDevice(resolvedIp, deviceName);

          if (mounted) {
            setState(() {
              _discoveredDevices[resolvedIp] = {
                'name': deviceName,
                'port': port,
                'ip': resolvedIp,
              };
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _discoveryService.stop();
    _socketServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طالوت الهاشمي للاتصالات المحلية'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.wifi, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'متصل بالشبكة المحلية - جميع الأجهزة متصلة وموثوقة تلقائياً',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? const Center(child: Text('جاري البحث عن أجهزة متصلة بالشبكة...'))
                : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      String targetIp = _discoveredDevices.keys.elementAt(index);
                      var deviceData = _discoveredDevices[targetIp]!;
                      String deviceName = deviceData['name'];

                      return FutureBuilder<String?>(
                        future: ContactService.getContactName(deviceName),
                        builder: (context, snapshot) {
                          String displayName = (snapshot.hasData &&
                                  snapshot.data != null &&
                                  snapshot.data!.isNotEmpty)
                              ? snapshot.data!
                              : deviceName;

                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text('$displayName (موثوق)'),
                            subtitle: Text('$targetIp:${deviceData['port']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat, color: Colors.blue, size: 28),
                              onPressed: () {
                                _openChatRoom(deviceName, targetIp, deviceData['port']);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openChatRoom(String deviceName, String targetIp, int port) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          targetDeviceId: deviceName,
          targetHost: targetIp,
          targetPort: port,
        ),
      ),
    ).then((_) {
      // إعادة بناء الصفحة عند العودة لتحديث الاسم إذا تم حفظه أو تعديله
      if (mounted) {
        setState(() {});
      }
    });
  }
}
