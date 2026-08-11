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
    P2PSocketServer.messageStream.listen((data) {
      _handleIncomingData(data);
    });
  }

  void _handleIncomingData(String rawData) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded.containsKey('type') && (decoded['type'] == 'offer' || decoded['type'] == 'answer' || decoded['type'] == 'candidate')) {
        // معالجة إشارات WebRTC للاتصال الصوتي والفيديو
        return;
      }
    } catch (_) {
      if (mounted && rawData != "CONNECT_ACCEPTED") {
        setState(() {
          _messages.add({'sender': widget.targetHost, 'text': rawData});
        });
      }
    }
  }

  void _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;

    bool success = await P2PSocketServer.sendMessageToHost(
      widget.targetHost,
      widget.targetPort,
      text,
    );

    if (success) {
      setState(() {
        _messages.add({'sender': 'me', 'text': text});
      });
      _msgController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال الرسالة، تأكد من اتصال الجهاز الآخر بنفس الشبكة')),
        );
      }
    }
  }

  void _startCall({required bool isVideo}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVideo ? 'جاري بدء مكالمة الفيديو...' : 'جاري بدء المكالمة الصوتية...'),
      ),
    );
    // إرسال طلب البدء لتبادل إشارات WebRTC عبر الـ IP
    final callSignal = jsonEncode({
      'type': 'call_request',
      'isVideo': isVideo,
      'caller': widget.targetHost,
    });
    await P2PSocketServer.sendMessageToHost(widget.targetHost, widget.targetPort, callSignal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetHost),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.green),
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.blue),
            onPressed: () => _startCall(isVideo: true),
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
