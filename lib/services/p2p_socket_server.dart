import 'dart:convert';
import 'dart:io';
import 'identity_service.dart';

class P2PSocketServer {
  ServerSocket? _server;

  // بدء الاستماع للرسائل والطلبات الواردة على منفذ محلي (مثلاً 4040)
  Future<void> startServer(
    int port, {
    required Function(String callerId, String callerName, Socket socket) onRequestConnection,
    required Function(String senderId, String message) onMessageReceived,
  }) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    _server?.listen((Socket clientSocket) {
      clientSocket.transform(utf8.decoder).listen((data) async {
        final json = jsonDecode(data);
        final String type = json['type'];
        final String senderId = json['senderId'];

        // التأكد أولاً: هل هذا الجهاز محظور؟
        if (await IdentityService.isBlocked(senderId)) {
          clientSocket.destroy(); // إسقاط الاتصال فوراً
          return;
        }

        if (type == 'CONNECT_REQUEST') {
          // جهاز جديد يتصل أو يحاول التخمين -> عرض إشعار القبول/الرفض
          final String callerName = json['senderName'];
          onRequestConnection(senderId, callerName, clientSocket);
        } else if (type == 'MESSAGE') {
          // التأكد من أن الجهاز موثوق مسبقاً قبل استقبال الرسالة
          if (await IdentityService.isTrusted(senderId)) {
            onMessageReceived(senderId, json['content']);
          }
        }
      });
    });
  }

  // إرسال طلب تعرّف لجهاز آخر (يتضمن اسم الجهاز للطرف الآخر للقبول)
  static Future<void> sendConnectRequest(String targetHost, int targetPort) async {
    final socket = await Socket.connect(targetHost, targetPort);
    final myId = await IdentityService.getOrCreateDeviceId();
    final myName = await IdentityService.getDeviceName();

    final payload = jsonEncode({
      'type': 'CONNECT_REQUEST',
      'senderId': myId,
      'senderName': myName,
    });

    socket.write(payload);
    await socket.flush();
    await socket.close();
  }

  void stop() {
    _server?.close();
  }
}
