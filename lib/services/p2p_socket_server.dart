import 'dart:async';
import 'dart:io';

class P2PSocketServer {
  ServerSocket? _server;
  
  // بث الرسائل للواجهات (Stream Controller)
  static final StreamController<String> _messageStreamController = StreamController<String>.broadcast();
  static Stream<String> get messageStream => _messageStreamController.stream;

  // بدء خادم الاستماع المحلي
  Future<void> startServer(
    int port, {
    required Function(String callerId, String callerName, Socket socket) onRequestConnection,
    required Function(String senderId, String message) onMessageReceived,
  }) async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _server?.listen((Socket clientSocket) {
        clientSocket.listen((data) {
          String message = String.fromCharCodes(data).trim();
          
          // إرسال البيانات فوراً إلى الشاشة المفتوحة
          _messageStreamController.add(message);
          onMessageReceived(clientSocket.remoteAddress.address, message);
        });
      });
    } catch (e) {
      print("خطأ أثناء تشغيل السيرفر: $e");
    }
  }

  // دالة إرسال الرسائل الاستاتيكية المطلوبة من ChatDetailScreen
  static Future<bool> sendMessageToHost(String host, int port, String message) async {
    try {
      Socket socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      socket.write(message);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print("فشل إرسال الرسالة إلى $host:$port -> $e");
      return false;
    }
  }

  // إرسال طلب معرفة لجهاز آخر
  static Future<bool> sendConnectRequest(String host, int port) async {
    return await sendMessageToHost(host, port, "CONNECT_REQUEST");
  }

  void stop() {
    _server?.close();
  }
}
