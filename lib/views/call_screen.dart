import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_signaling_service.dart';

class CallScreen extends StatefulWidget {
  final WebRTCSignalingService signalingService;
  final String targetHost;
  final int targetPort;
  final String callerName;
  final bool isVideo;

  const CallScreen({
    Key? key,
    required this.signalingService,
    required this.targetHost,
    required this.targetPort,
    required this.callerName,
    required this.isVideo,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initRenderersAndStart();
  }

  Future<void> _initRenderersAndStart() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await widget.signalingService.initialize(
      onLocalStream: (stream) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      },
      onRemoteStream: (stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      },
    );

    // بدء طلب الاتصال
    await widget.signalingService.createAndSendOffer(
      widget.targetHost,
      widget.targetPort,
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _endCall() async {
    await widget.signalingService.dispose();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.callerName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // عرض فيديو الطرف الآخر
          Positioned.fill(
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          // عرض فيديو الكاميرا المحلية في الزاوية
          if (widget.isVideo)
            Positioned(
              right: 16,
              top: 16,
              width: 100,
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),

          // أزرار التحكم في أسفل الشاشة
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'btn_mute',
                  backgroundColor: _isMuted ? Colors.orange : Colors.white24,
                  onPressed: _toggleMute,
                  child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: 'btn_hangup',
                  backgroundColor: Colors.red,
                  onPressed: _endCall,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
