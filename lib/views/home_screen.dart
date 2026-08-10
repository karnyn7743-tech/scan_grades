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
  
  // قائمة الأجهزة المكتشفة حالياً بالشبكة المحلية
  final Map<String, Map<String, dynamic>> _discoveredDevices = {};
  final int localPort = 4040;

  @override
  void initState() {
    super.initState();
    _initNetworkServices();
  }

  Future<void> _initNetworkServices() async {
    // 1. تشغيل خادم الاستماع للرسائل والطلبات الواردة
    await _socketServer.startServer(
      localPort,
      onRequestConnection: _handleIncomingConnectionRequest,
      onMessageReceived: _handleIncomingMessage,
    );

    // 2. إعلان وجود الجهاز على الشبكة محلياً
    await _discoveryService.startBroadcasting(localPort);

    // 3. لبحث عن الأجهزة الأخرى متصلة بنفس الراوتر
    await _discoveryService.startDiscovery((deviceId, host, port) async {
      final myId = await IdentityService.getOrCreateDeviceId();
      if (deviceId != myId) { // تجاهل هذا الجهاز نفسه
        setState(() {
          _discoveredDevices[deviceId] = {
            'host': host,
            'port': port,
          };
        });
      }
    });
  }

  // معالجة طلب التعرف الوارد من جهاز آخر
  void _handleIncomingConnectionRequest(String callerId, String callerName, Socket socket) async {
    bool isTrusted = await IdentityService.isTrusted(callerId);
    
    if (!isTrusted && mounted) {
      showConsentDialog(
        context: context,
        callerId: callerId,
        callerName: callerName,
        onAccepted: () {
          setState(() {}); // تحديث الواجهة عند القبول
        },
      );
    }
  }

  void _handleIncomingMessage(String senderId, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رسالة جديدة: $message')),
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
                      String deviceId = _discoveredDevices.keys.elementAt(index);
                      var deviceData = _discoveredDevices[deviceId]!;

                      return FutureBuilder<bool>(
                        future: IdentityService.isTrusted(deviceId),
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
                              isTrusted ? 'جهاز موثوق ($deviceId)' : 'جهاز غير معروف',
                            ),
                            subtitle: Text('${deviceData['host']}:${deviceData['port']}'),
                            trailing: isTrusted
                                ? IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      _openChatRoom(deviceId, deviceData['host'], deviceData['port']);
                                    },
                                  )
                                : ElevatedButton(
                                    child: const Text('طلب معرفة'),
                                    onPressed: () async {
                                      await P2PSocketServer.sendConnectRequest(
                                        deviceData['host'],
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

  void _openChatRoom(String deviceId, String host, int port) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          targetDeviceId: deviceId,
          targetHost: host,
          targetPort: port,
        ),
      ),
    );
  }
}
