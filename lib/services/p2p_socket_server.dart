import 'dart:convert';
import 'dart:io';
import 'identity_service.dart';

class P2PSocketServer {
  ServerSocket? _server;

  // بدء الاستماع للرسائل والطلبات الواردة
  Future<void> startServer(
    int port, {
    required Function(String callerId, String callerName, Socket socket) onRequestConnection,
    required Function(String senderId, String message) onMessageReceived,
  }) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    _server?.listen((Socket clientSocket) {
      clientSocket.transform(utf8.decoder).listen((data) async {
        try {
          final json = jsonDecode(data);
          final String type = json['type'] ?? 'MESSAGE';
          final String senderId = json['senderId'] ?? '';

          // التأكد أولاً: هل هذا الجهاز محظور؟
          if (senderId.isNotEmpty && await IdentityService.isBlocked(senderId)) {
            clientSocket.destroy();
            return;
          }

          if (type == 'CONNECT_REQUEST') {
            final String callerName = json['senderName'] ?? 'جهاز غير معروف';
            onRequestConnection(senderId, callerName, clientSocket);
          } else if (type == 'MESSAGE') {
            onMessageReceived(senderId, json['content'] ?? data);
          }
        } catch (e) {
          // التعامل مع النصوص المباشرة أو إشارات WebRTC التي قد لا تكون JSON معقد
          onMessageReceived('unknown', data);
        }
      });
    });
  }

  // إرسال نص أو بيانات استاتيكياً لجميع الشاشات (الشات والإشارات)
  static Future<void> sendMessage(String targetHost, int targetPort, String message) async {
    try {
      final socket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 3));
      socket.write(message);
      await socket.flush();
      await socket.close();
    } catch (e) {
      // التعامل مع فشل الاتصال بالشبكة
    }
  }

  // إرسال طلب تعرّف لجهاز آخر
  static Future<void> sendConnectRequest(String targetHost, int targetPort) async {
    final myId = await IdentityService.getOrCreateDeviceId();
    final myName = await IdentityService.getDeviceName();

    final payload = jsonEncode({
      'type': 'CONNECT_REQUEST',
      'senderId': myId,
      'senderName': myName,
    });

    await sendMessage(targetHost, targetPort, payload);
  }

  void stop() {
    _server?.close();
  }
}
