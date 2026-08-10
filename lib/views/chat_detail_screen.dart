import 'package:flutter/material.dart';
import '../services/p2p_socket_server.dart';
import '../services/webrtc_signaling_service.dart';
import 'call_screen.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  final WebRTCSignalingService _signalingService = WebRTCSignalingService();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      P2PSocketServer.sendMessage(widget.targetHost, widget.targetPort, text);
      setState(() {
        _messages.add("أنا: $text");
      });
      _messageController.clear();
    }
  }

  void _startCall(bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          signalingService: _signalingService,
          targetHost: widget.targetHost,
          targetPort: widget.targetPort,
          callerName: widget.targetDeviceId,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('محادثة: ${widget.targetDeviceId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _startCall(false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startCall(true),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_messages[index]),
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
                    controller: _messageController,
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
