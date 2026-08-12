import 'dartg:convert';
import 'package:flutter/material.dart';
import '../services/p2p_socket_server.dart';

class ChatDetailScreen extends StatefulWidget {
  final String targetDeviceId;
  final String targetHost;
  final int targetPort;

  const ChatDetailScreen({
    Key? key,
    required this.targetDeviceId,
    required this.targetHost,
    required this.targetPort,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    P2PSocketServer.messageStream.listen((data) {
      _handleIncomingData(data);
    });
  }

  void _handleIncomingData(String rawData) {
    if (!mounted) return;

    try {
      // محاولة فك الشفرة كبيانات JSON (مثل إشارات الفيديوهات أو الرسائل المُهيكلة)
      final decoded = jsonDecode(rawData);

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('type') &&
            (decoded['type'] == 'offer' ||
                decoded['type'] == 'answer' ||
                decoded['type'] == 'candidate')) {
          // معالجة إشارات الاتصال هنا إن وجدت
          return;
        }

        // في حال كان النص مشفراً داخل هيكل JSON
        if (decoded.containsKey('text')) {
          setState(() {
            _messages.add({
              'sender': widget.targetDeviceId,
              'text': decoded['text'].toString(),
            });
          });
          return;
        }
      }
    } catch (_) {
      // إذا لم يكن البيانات من نوع JSON (نص عادي مباشر)
    }

    // إضافة النص المباشر القادم إلى القائمة
    if (rawData != "CONNECT_ACCEPTED" && rawData.isNotEmpty) {
      setState(() {
        _messages.add({
          'sender': widget.targetDeviceId,
          'text': rawData,
        });
      });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // إضافة الرسالة لقائمة الرسائل الخاصة بي
    setState(() {
      _messages.add({
        'sender': 'me',
        'text': text,
      });
    });

    _msgController.clear();

    // إرسال النص إلى الطرف الآخر عبر السوكيت
    await P2PSocketServer.sendMessageToHost(
      widget.targetHost,
      widget.targetPort,
      text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetDeviceId),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue.shade200 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
