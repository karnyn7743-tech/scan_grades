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
      onMessageReceived: (sender, msg) async {
        // عند استلام الموافقة من الطرف الآخر
        if (msg == "CONNECT_ACCEPTED") {
          // توثيق الجهاز المرسل فوراً باستعمال الـ IP والاسم
          await IdentityService.trustDevice(sender, sender);
          if (mounted) {
            setState(() {}); // تحديث الواجهة فوراً ليتحول إلى جهاز موثوق
          }
        }
      },
    );

    await _discoveryService.startBroadcasting(localPort);

    await _discoveryService.startListening((service) async {
      final host = service.host ?? '';
      final deviceName = service.name ?? 'جهاز محلي';
      final port = service.port ?? 4040;

      if (host.isNotEmpty && !_myLocalIps.contains(host)) {
        if (!_discoveredDevices.containsKey(host)) {
          setState(() {
            _discoveredDevices[host] = {
              'name': deviceName,
              'port': port,
              'host': host,
            };
          });
        }
      }
    });
  }

  void _handleIncomingConnectionRequest(String callerId, String callerName, Socket socket) async {
    String clientIp = socket.remoteAddress.address;
    
    // التحقق بالـ IP وباسم المتصل
    bool isTrusted = await IdentityService.isTrusted(clientIp) || 
                     await IdentityService.isTrusted(callerId);

    if (!isTrusted && mounted) {
      showConsentDialog(
        context: context,
        callerId: callerId,
        callerName: callerName,
        host: clientIp,
        onAccepted: () async {
          // حفظ التوثيق للطرفين (الـ IP واسم الجهاز)
          await IdentityService.trustDevice(clientIp, callerName);
          await IdentityService.trustDevice(callerId, callerName);
          
          // إبلاغ الطرف الآخر بتم القبول
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

  // دالة فحص مشتركة تطابق الـ Host والـ IP
  Future<bool> _checkDeviceTrust(String targetKey) async {
    bool trustedByKey = await IdentityService.isTrusted(targetKey);
    if (trustedByKey) return true;
    
    var data = _discoveredDevices[targetKey];
    if (data != null && data['host'] != null) {
      return await IdentityService.isTrusted(data['host']);
    }
    return false;
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
                      String targetKey = _discoveredDevices.keys.elementAt(index);
                      var deviceData = _discoveredDevices[targetKey]!;
                      String targetHost = deviceData['host'] ?? targetKey;

                      return FutureBuilder<bool>(
                        future: _checkDeviceTrust(targetKey),
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
                              isTrusted ? 'جهاز موثوق ($targetKey)' : 'جهاز غير معروف ($targetKey)',
                            ),
                            subtitle: Text('$targetHost:${deviceData['port']}'),
                            trailing: isTrusted
                                ? IconButton(
                                    icon: const Icon(Icons.chat, color: Colors.blue),
                                    onPressed: () {
                                      _openChatRoom(targetKey, targetHost, deviceData['port']);
                                    },
                                  )
                                : ElevatedButton(
                                    child: const Text('طلب معرفة'),
                                    onPressed: () async {
                                      String myId = await IdentityService.getOrCreateDeviceId();
                                      bool sent = await P2PSocketServer.sendConnectRequest(
                                        targetHost,
                                        deviceData['port'],
                                        myId,
                                      );

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(sent
                                                ? 'تم إرسال طلب التعرف إلى $targetKey'
                                                : 'تعذر الاتصال بالجهاز $targetKey'),
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
          targetHost: targetIp,
          targetPort: port,
        ),
      ),
    );
  }
}
