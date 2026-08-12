import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'p2p_socket_server.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  // إنشاء اتصال جديد وتكوين المسارات
  Future<void> createPeerConnectionConfig(String targetHost, int targetPort) async {
    Map<String, dynamic> configuration = {
      'iceServers': [] // شبكة محلية مغلقة بدون الحاجة لـ STUN/TURN
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate != null) {
        final msg = jsonEncode({
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
        P2PSocketServer.sendMessageToHost(targetHost, targetPort, msg);
      }
    };

    _peerConnection?.onTrack = (event) {
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
      }
    };
  }

  // بدء المكالمة (Caller)
  Future<void> makeCall(String targetHost, int targetPort, bool isVideo) async {
    await initializeRenderers();
    await createPeerConnectionConfig(targetHost, targetPort);

    Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final msg = jsonEncode({
      'type': 'offer',
      'sdp': offer.sdp,
      'isVideo': isVideo,
    });

    await P2PSocketServer.sendMessageToHost(targetHost, targetPort, msg);
  }

  // استقبال وإجابة المكالمة (Receiver)
  Future<void> handleOfferAndAnswer(
      String sdp, String targetHost, int targetPort, bool isVideo) async {
    await initializeRenderers();
    await createPeerConnectionConfig(targetHost, targetPort);

    Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    localRenderer.srcObject = _localStream;

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    final msg = jsonEncode({
      'type': 'answer',
      'sdp': answer.sdp,
    });

    await P2PSocketServer.sendMessageToHost(targetHost, targetPort, msg);
  }

  Future<void> handleAnswer(String sdp) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
  }

  Future<void> handleCandidate(Map<String, dynamic> candidateMap) async {
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
  }

  void dispose() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _peerConnection?.close();
  }
}
