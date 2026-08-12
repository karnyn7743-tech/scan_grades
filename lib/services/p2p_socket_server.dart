import 'dart:async';
import 'dart:convert';
import 'dart:io';

class P2PSocketServer {
  ServerSocket? _server;
  
  static final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  static Stream<String> get messageStream => _messageStreamController.stream;

  Future<void> startServer(
    int port, {
    required Function(String callerId, String callerName, Socket socket) onRequestConnection,
    required Function(String senderId, String message) onMessageReceived,
  }) async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _server?.listen((Socket clientSocket) {
        clientSocket.listen((data) {
          // فك تشفير البيانات المتمثلة ببايتات UTF-8 بدقة لمنع تشوه الحروف العربية
          String message = utf8.decode(data, allowMalformed: true).trim();
          String remoteIp = clientSocket.remoteAddress.address;

          if (message.startsWith("CONNECT_REQUEST")) {
            List<String> parts = message.split("|");
            String callerName = parts.length > 1 ? parts[1] : "جهاز محلي";
            onRequestConnection(remoteIp, callerName, clientSocket);
          } else if (message == "CONNECT_ACCEPTED") {
            onMessageReceived(remoteIp, "CONNECT_ACCEPTED");
          } else {
            _messageStreamController.add(message);
            onMessageReceived(remoteIp, message);
          }
        });
      });
    } catch (e) {
      print("خطأ أثناء تشغيل السيرفر: $e");
    }
  }

  static Future<bool> sendMessageToHost(String host, int port, String message) async {
    try {
      Socket socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
      
      // تحويل النص العربي إلى UTF-8 Bytes وإرساله مباشرة
      List<int> bytes = utf8.encode(message);
      socket.add(bytes);
      
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      await socket.close();
      return true;
    } catch (e) {
      print("خطأ في إرسال البيانات إلى $host: $e");
      return false;
    }
  }

  static Future<bool> sendConnectRequest(String host, int port, String myName) async {
    return await sendMessageToHost(host, port, "CONNECT_REQUEST|$myName");
  }

  void stop() {
    _server?.close();
  }
}
