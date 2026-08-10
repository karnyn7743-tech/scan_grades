// داخل ChatDetailScreen
IconButton(
  icon: const Icon(Icons.phone),
  onPressed: () async {
    // 1. تشغيل الوسائط
    final stream = await _webRTCService.getLocalMedia(false);
    
    // 2. إنشاء الاتصال وإرسال الـ Offer
    await _webRTCService.createPeerConnection((offer) {
      // إرسال الـ offer عبر Socket للطرف الآخر
      _sendSocketData({
        'type': 'RTC_OFFER',
        'sdp': offer.sdp,
        'senderId': myId,
      });
    });
  },
),
