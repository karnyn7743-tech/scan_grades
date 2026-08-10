import 'package:nsd/nsd.dart';

class NetworkDiscoveryService {
  Discovery? _discovery;
  Registration? _registration;

  // بدء بث وجود الجهاز على الشبكة
  Future<void> startBroadcasting(int port) async {
    _registration = await register(
      const Service(
        name: 'LocalChatDevice',
        type: '_localchat._tcp',
        port: 4040,
      ),
    );
  }

  // بدء البحث عن الأجهزة القريبة
  Future<void> startDiscovery(Function(Service service) onServiceFound) async {
    _discovery = await startDiscovery('_localchat._tcp');
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
      await stopDiscovery(_discovery!);
    }
    if (_registration != null) {
      await unregister(_registration!);
    }
  }
}
