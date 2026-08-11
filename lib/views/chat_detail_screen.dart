import 'dart:convert';
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
    // الاشتراك بـ Stream الاستماع المباشر للرسائل الواردة
    P2PSocketServer.messageStream.listen((data) {
      _handleIncomingData(data);
    });
  }

  void _handleIncomingData(String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      // إذا كانت الرسالة تخص إشارات WebRTC للمكالمات الصوتية والمرئية
      if (decoded.containsKey('sdp') || decoded.containsKey('candidate')) {
        // تمريرها إلى WebRTC Helper
        return;
      }
    } catch (_) {
      // إذا كانت نص عادي (مراسلة نصية)
      if (mounted) {
        setState(() {
          _messages.add({'sender': widget.targetHost, 'text': rawData});
        });
      }
    }
  }

  void _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;

    // 1. إرسال عبر الـ Socket مباشرة إلى הـ IP
    await P2PSocketServer.sendMessageToHost(widget.targetHost, widget.targetPort, text);

    // 2. تحديث قائمة المراسلات في الشاشة
    setState(() {
      _messages.add({'sender': 'me', 'text': text});
    });
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetHost),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              // بدء مكالمة صوتية محلياً
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // بدء مكالمة فيديو محلياً
            },
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
                bool isMe = _messages[index]['sender'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_messages[index]['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
