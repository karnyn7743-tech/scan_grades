import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredService {
  final String? name;
  final String? host;
  final int? port;

  DiscoveredService({this.name, this.host, this.port});
}

class NetworkDiscoveryService {
  static const int _discoveryPort = 8888;
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;

  /// 1️⃣ بدء الاستماع والتسجيل التلقائي للأجهزة المتصلة
  Future<void> startListening(Function(DiscoveredService) onDeviceFound) async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = _socket?.receive();
          if (dg != null) {
            String message = utf8.decode(dg.data).trim();
            
            // استقبال إشارة طلب الاكتشاف والرد عليها فوراً
            if (message.startsWith("DISCOVER_REQ")) {
              _sendResponse(dg.address);
            } 
            // استقبال إشارة استجابة من جهاز آخر في الشبكة
            else if (message.startsWith("DISCOVER_RESP")) {
              List<String> parts = message.split("|");
              String deviceName = parts.length > 1 ? parts[1] : "جهاز محلي";
              int port = parts.length > 2 ? int.tryParse(parts[2]) ?? 4040 : 4040;

              onDeviceFound(
                DiscoveredService(
                  name: deviceName,
                  host: dg.address.address,
                  port: port,
                ),
              );
            }
          }
        }
      });
    } catch (e) {
      print("خطأ في بدء خدمة الاكتشاف: $e");
    }
  }

  /// 2️⃣ إرسال إشارة بث عام (Broadcast) كل ثانيتين لاكتشاف الأجهزة فوراً
  Future<void> startBroadcasting(int localPort, {String deviceName = "طالوت_الهاشمي"}) async {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _sendDiscoveryBroadcast(localPort, deviceName);
    });
    // إرسال حزمة أولى فورية
    _sendDiscoveryBroadcast(localPort, deviceName);
  }

  void _sendDiscoveryBroadcast(int localPort, String deviceName) {
    try {
      String payload = "DISCOVER_REQ|$deviceName|$localPort";
      List<int> data = utf8.encode(payload);
      _socket?.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
    } catch (e) {
      print("خطأ في إرسال حزمة البث: $e");
    }
  }

  void _sendResponse(InternetAddress targetAddress) {
    try {
      String payload = "DISCOVER_RESP|طالوت_الهاشمي|4040";
      List<int> data = utf8.encode(payload);
      _socket?.send(data, targetAddress, _discoveryPort);
    } catch (e) {
      print("خطأ في رد الاستجابة: $e");
    }
  }

  /// 3️⃣ إيقاف خدمة الاكتشاف
  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
