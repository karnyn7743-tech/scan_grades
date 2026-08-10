import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'p2p_socket_server.dart';

typedef OnLocalStream = void Function(MediaStream stream);
typedef OnRemoteStream = void Function(MediaStream stream);

class WebRTCSignalingService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // إعدادات خوادم STUN المفتوحة للربط بين الأجهزة
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initialize({
    required OnLocalStream onLocalStream,
    required OnRemoteStream onRemoteStream,
  }) async {
    // 1. إنشاء الاتصال وقواعد ICE
    _peerConnection = await createPeerConnection(_iceServers);

    // 2. الوصول لوسائط الجهاز (الكاميرا والميكروفون)
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream(_localStream!);

    // إضافة المسارات الصوتية والمرئية للاتصال
    _localStream!.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // 3. الاستماع لوصول فيديو الطرف الآخر
    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream(event.streams[0]);
      }
    };
  }

  // إنشاء عرض اتصال (Offer) وإرساله للطرف الآخر
  Future<void> createAndSendOffer(String targetHost, int targetPort) async {
    if (_peerConnection == null) return;

    // إرسال مرشحات الشبكة (ICE Candidates)
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        P2PSocketServer.sendMessage(
          targetHost,
          targetPort,
          jsonEncode({
            'type': 'candidate',
            'candidate': candidate.toMap(),
          }),
        );
      }
    };

    // إنشاء SDP Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // إرسال العرض عبر الـ Socket
    P2PSocketServer.sendMessage(
      targetHost,
      targetPort,
      jsonEncode({
        'type': 'offer',
        'sdp': offer.sdp,
      }),
    );
  }

  // معالجة البيانات الواردة من الطرف الآخر (Offer / Answer / Candidate)
  Future<void> handleSignalingData(
    Map<String, dynamic> data,
    String senderHost,
    int senderPort,
  ) async {
    String type = data['type'];

    if (type == 'offer') {
      var description = RTCSessionDescription(data['sdp'], 'offer');
      await _peerConnection?.setRemoteDescription(description);

      // إنشاء الإجابة (Answer)
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // إرسال الإجابة
      P2PSocketServer.sendMessage(
        senderHost,
        senderPort,
        jsonEncode({
          'type': 'answer',
          'sdp': answer.sdp,
        }),
      );
    } else if (type == 'answer') {
      var description = RTCSessionDescription(data['sdp'], 'answer');
      await _peerConnection?.setRemoteDescription(description);
    } else if (type == 'candidate') {
      var candidateMap = data['candidate'];
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
    }
  }

  // إغلاق الاتصال وتحرير الكاميرا والميكروفون
  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
  }
}
