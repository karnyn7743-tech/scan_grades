import 'package:nsd/nsd.dart' as nsd;

class NetworkDiscoveryService {
  nsd.Discovery? _discovery;
  nsd.Registration? _registration;

  // بدء بث وجود الجهاز على الشبكة
  Future<void> startBroadcasting(int port) async {
    _registration = await nsd.register(
      const nsd.Service(
        name: 'LocalChatDevice',
        type: '_localchat._tcp',
        port: 4040,
      ),
    );
  }

  // بدء البحث عن الأجهزة القريبة (تم تغيير اسم الدالة المباشرة إلى startListening)
  Future<void> startListening(Function(nsd.Service service) onServiceFound) async {
    _discovery = await nsd.startDiscovery('_localchat._tcp');
    _discovery?.addListener(() {
      final services = _discovery?.services ?? [];
      for (var service in services) {
        onServiceFound(service);
      }
    });
  }

  // إيقاف الخدمة والبث
  Future<void> stop() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
    }
    if (_registration != null) {
      await nsd.unregister(_registration!);
    }
  }
}
