import 'package:nsd/nsd.dart';
import 'identity_service.dart';

class NetworkDiscoveryService {
  Discovery? _discovery;
  Registration? _registration;

  // 1. الإعلان عن وجود الجهاز على الشبكة بدون كشف هويته للغرباء
  Future<void> startBroadcasting(int socketPort) async {
    final myId = await IdentityService.getOrCreateDeviceId();
    
    // يتم تسجيل الخدمة برمز معرّف الجهاز والمنفذ المخصص للرسائل
    _registration = await register(
      Service(
        name: myId, // الاسم المعلن بالشبكة هو المعرّف فقط دون اسم المستخدم
        type: '_localchat._tcp',
        port: socketPort,
      ),
    );
  }

  // 2. البحث عن الأجهزة القريبة المتصلة بنفس الراوتر
  Future<void> startDiscovery(Function(String deviceId, String host, int port) onDeviceFound) async {
    _discovery = await startDiscovery('_localchat._tcp');
    
    _discovery?.addListener(() {
      for (var service in _discovery!.services) {
        if (service.name != null && service.host != null && service.port != null) {
          onDeviceFound(service.name!, service.host!, service.port!);
        }
      }
    });
  }

  Future<void> stop() async {
    if (_registration != null) await unregister(_registration!);
    if (_discovery != null) await stopDiscovery(_discovery!);
  }
}
