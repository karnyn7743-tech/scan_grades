import 'package:flutter/material.dart';
import 'dart:io';
import '../services/identity_service.dart';
import '../services/network_discovery_service.dart';
import '../services/p2p_socket_server.dart';
import '../widgets/consent_dialog.dart';
import 'chat_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final P2PSocketServer _socketServer = P2PSocketServer();
  
  // حفظ البيانات باستعمال IP المباشر فقط كمفتاح رئيسي
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
      onRequestConnection: _handleIncomingConnectionRequest,
      onMessageReceived: (senderIp, msg) async {
        if (msg == "CONNECT_ACCEPTED") {
          // توثيق الجهاز عبر الـ IP المباشر
          await IdentityService.trustDevice(senderIp, senderIp);
          if (mounted) {
            setState(() {});
          }
        }
      },
    );

    await _discoveryService.startBroadcasting(localPort);

    await _discoveryService.startListening((service) async {
      String resolvedIp = service.host ?? '';

      // استخراج الـ IP الصريح إذا كان المرسل قد أرسل اسم host بدلاً من IP
      if (resolvedIp.isNotEmpty && !_myLocalIps.contains(resolvedIp)) {
        try {
          // تحويل اسم المضيف إلى IP إن وجد
          final addresses = await InternetAddress.lookup(resolvedIp);
          if (addresses.isNotEmpty) {
            resolvedIp = addresses.first.address;
          }
        } catch (_) {}

        // حظر إضافة الجهاز إذا كان هو نفس الجهاز الحالي
        if (!_myLocalIps.contains(resolvedIp)) {
          final deviceName = service.name ?? 'جهاز محلي';
          final port = service.port ?? 4040;

          if (!_discoveredDevices.containsKey(resolvedIp)) {
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

  void _handleIncomingConnectionRequest(String callerId, String callerName, Socket socket) async {
    String clientIp = socket.remoteAddress.address;
    
    bool isTrusted = await IdentityService.isTrusted(clientIp);

    if (!isTrusted && mounted) {
      showConsentDialog(
        context: context,
        callerId: callerId,
        callerName: callerName,
        host: clientIp,
        onAccepted: () async {
          // توثيق الـ IP المباشر للطرفين
          await IdentityService.trustDevice(clientIp, callerName);
          
          // إرسال إشارة التأكيد عبر الـ IP المباشر
          await P2PSocketServer.sendMessageToHost(clientIp, localPort, "CONNECT_ACCEPTED");
          
          if (mounted) {
            setState(() {});
          }
        },
      );
    }
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
        title: const Text('طالوت الهاشمي للاتصالات المحلية (P2P)'),
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
                    'متصل بالشبكة المحلية - جاهز لاكتشاف الأجهزة القريبة بدون إنترنت',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? const Center(child: Text('جاري البحث عن أجهزة متصلة بالراوتر...'))
                : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      String targetIp = _discoveredDevices.keys.elementAt(index);
                      var deviceData = _discoveredDevices[targetIp]!;

                      return FutureBuilder<bool>(
                        future: IdentityService.isTrusted(targetIp),
                        builder: (context, snapshot) {
                          bool isTrusted = snapshot.data ?? false;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isTrusted ? Colors.green : Colors.grey,
                              child: Icon(
                                isTrusted ? Icons.person : Icons.lock_clock,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              isTrusted 
                                  ? '${deviceData['name']} (موثوق)' 
                                  : '${deviceData['name']} (غير معروف)',
                            ),
                            subtitle: Text('$targetIp:${deviceData['port']}'),
                            trailing: isTrusted
                                ? IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      _openChatRoom(deviceData['name'], targetIp, deviceData['port']);
                                    },
                                  )
                                : ElevatedButton(
                                    child: const Text('طلب معرفة'),
                                    onPressed: () async {
                                      String myId = await IdentityService.getOrCreateDeviceId();
                                      bool sent = await P2PSocketServer.sendConnectRequest(
                                        targetIp,
                                        deviceData['port'],
                                        myId,
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(sent
                                                ? 'تم إرسال طلب التعرف إلى $targetIp'
                                                : 'تعذر الاتصال بالجهاز $targetIp'),
                                          ),
                                        );
                                      }
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
          targetHost: targetIp, // يمرر الـ IP الصريح دائماً للشات
          targetPort: port,
        ),
      ),
    );
  }
}
