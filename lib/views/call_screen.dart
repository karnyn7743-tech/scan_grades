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
  CallState _currentState = CallState.calling;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    widget.signalingService.onLocalStreamReady = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    widget.signalingService.onRemoteStreamReady = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };

    widget.signalingService.onCallStateChanged = (state) {
      setState(() {
        _currentState = state;
      });
    };
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
      body: Stack(
        children: [
          // عرض فيديو الشخص البعيد
          if (widget.isVideo)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // عرض الكاميرا المحلية في مربع صغير
          if (widget.isVideo)
            Positioned(
              top: 40,
              right: 20,
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // تفاصيل المتصل والحالة
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.callerName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentState == CallState.connected
                      ? 'متصل الآن (Local P2P)'
                      : 'جاري الاتصال عبر الواي فاي...',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // زر إنهاء المكالمة
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                onPressed: () async {
                  await widget.signalingService.hangUp(widget.targetHost, widget.targetPort);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
