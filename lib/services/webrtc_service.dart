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

  Future<void> createPeerConnectionConfig(String targetHost, int targetPort) async {
    // إغلاق الاتصال السابق إن وجد لضمان إعادة التوصيل بنجاح
    await _closePeerConnection();

    Map<String, dynamic> configuration = {'iceServers': []};
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

  // إرسال إشارة إغلاق الخط وإغلاق الموارد محليةً
  Future<void> hangup(String targetHost, int targetPort) async {
    try {
      final msg = jsonEncode({'type': 'hangup'});
      await P2PSocketServer.sendMessageToHost(targetHost, targetPort, msg);
    } catch (_) {}
    await dispose();
  }

  Future<void> _closePeerConnection() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;
  }

  Future<void> dispose() async {
    await _closePeerConnection();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
