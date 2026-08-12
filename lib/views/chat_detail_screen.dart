import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/p2p_socket_server.dart';
import '../services/webrtc_service.dart';

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
  final WebRTCService _webrtcService = WebRTCService();

  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    P2PSocketServer.messageStream.listen((data) {
      _handleIncomingData(data);
    });
  }

  void _handleIncomingData(String rawData) async {
    if (!mounted) return;

    try {
      final decoded = jsonDecode(rawData);

      if (decoded is Map<String, dynamic> && decoded.containsKey('type')) {
        String type = decoded['type'];

        // استقبال الطلب وإظهار حوار التنبيه بالجرس
        if (type == 'offer') {
          _showIncomingCallDialog(
            isVideo: decoded['isVideo'] ?? false,
            sdp: decoded['sdp'],
          );
          return;
        } else if (type == 'answer') {
          await _webrtcService.handleAnswer(decoded['sdp']);
          return;
        } else if (type == 'candidate') {
          await _webrtcService.handleCandidate(decoded['candidate']);
          return;
        } else if (type == 'hangup') {
          // إنهاء الخط عند الطرف الآخر عند استلام أمر الإغلاق
          await _webrtcService.dispose();
          if (mounted) {
            setState(() { _inCall = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إنهاء المكالمة من الطرف الآخر')),
            );
          }
          return;
        }
      }
    } catch (_) {}

    if (rawData != "CONNECT_ACCEPTED" && rawData.isNotEmpty) {
      setState(() {
        _messages.add({
          'sender': widget.targetDeviceId,
          'text': rawData,
        });
      });
    }
  }

  // تنبيه وجرس للمكالمة الواردة
  void _showIncomingCallDialog({required bool isVideo, required String sdp}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('مكالمة ${isVideo ? "فيديو" : "صوتية"} واردة'),
          content: Text('يتصل بك: ${widget.targetDeviceId}'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _webrtcService.hangup(widget.targetHost, widget.targetPort);
              },
              child: const Text('رفض', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() { _inCall = true; });
                await _webrtcService.handleOfferAndAnswer(
                  sdp,
                  widget.targetHost,
                  widget.targetPort,
                  isVideo,
                );
                setState(() {});
              },
              child: const Text('رد'),
            ),
          ],
        );
      },
    );
  }

  void _startCall({required bool isVideo}) async {
    setState(() { _inCall = true; });
    await _webrtcService.makeCall(widget.targetHost, widget.targetPort, isVideo);
    setState(() {});
  }

  void _endCall() async {
    await _webrtcService.hangup(widget.targetHost, widget.targetPort);
    if (mounted) {
      setState(() { _inCall = false; });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'me', 'text': text});
    });

    _msgController.clear();
    await P2PSocketServer.sendMessageToHost(
      widget.targetHost,
      widget.targetPort,
      text,
    );
  }

  @override
  void dispose() {
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetDeviceId),
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
          if (_inCall)
            Container(
              height: 200,
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(child: RTCVideoView(_webrtcService.localRenderer, mirror: true)),
                  Expanded(child: RTCVideoView(_webrtcService.remoteRenderer)),
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.red, size: 30),
                    onPressed: _endCall,
                  )
                ],
              ),
            ),
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
