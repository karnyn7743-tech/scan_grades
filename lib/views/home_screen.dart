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
  
  // مفتاح القائمة هو IP الجهاز لمنع التكرار نهائياً
  final Map<String, Map<String, dynamic>> _discoveredDevices = {};
  final int localPort = 4040;

  @override
  void initState() {
    super.initState();
    _initNetworkServices();
  }

  Future<void> _initNetworkServices() async {
    await _socketServer.startServer(
      localPort,
      onRequestConnection: _handleIncomingConnectionRequest,
      onMessageReceived: _handleIncomingMessage,
    );

    await _discoveryService.startBroadcasting(localPort);

    await _discoveryService.startListening((service) async {
      final host = service.host ?? '';
      final deviceName = service.name ?? 'جهاز محلي';
      final port = service.port ?? 4040;

      // تجميع الأجهزة حسب الـ IP لترشيح التكرارات
      if (host.isNotEmpty) {
        final myIp = await IdentityService.getDeviceName(); // أو IP المحلي
        if (host != myIp) {
          setState(() {
            _discoveredDevices[host] = {
              'name': deviceName,
              'port': port,
            };
          });
        }
      }
    });
  }

  void _handleIncomingConnectionRequest(String callerId, String callerName, Socket socket) async {
    String clientIp = socket.remoteAddress.address;
    bool isTrusted = await IdentityService.isTrusted(callerId) || await IdentityService.isTrusted(clientIp);
    
    if (!isTrusted && mounted) {
      showConsentDialog(
        context: context,
        callerId: callerId,
        callerName: callerName,
        host: clientIp,
        onAccepted: () {
          setState(() {});
        },
      );
    }
  }

  void _handleIncomingMessage(String senderId, String message) {
    // عدم إظهار الإشعار إذا كانت الرسالة عبارة عن إشارات اتصال WebRTC
    if (mounted && !message.contains('"type":"offer"') && !message.contains('"type":"answer"')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رسالة من $senderId: $message')),
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
                      String deviceName = deviceData['name'];

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
                              isTrusted ? 'جهاز موثوق ($targetIp)' : 'جهاز غير معروف',
                            ),
                            subtitle: Text('$targetIp:${deviceData['port']}'),
                            trailing: isTrusted
                                ? IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      _openChatRoom(deviceName, targetIp, deviceData['port']);
                                    },
                                  )
                                : ElevatedButton(
                                    child: const Text('طلب معرفة'),
                                    onPressed: () async {
                                      await P2PSocketServer.sendConnectRequest(
                                        targetIp,
                                        deviceData['port'],
                                      );
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
    );
  }
}
