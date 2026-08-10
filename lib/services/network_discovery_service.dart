import 'package:nsd/nsd.dart';

class NetworkDiscoveryService {
  Discovery? _discovery;

  Future<void> startDiscovery(Function(Service service) onServiceFound) async {
    _discovery = await startDiscovery('_localchat._tcp');
    _discovery?.addListener(() {
      for (var service in _discovery?.services ?? []) {
        onServiceFound(service);
      }
    });
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
    }
  }
}
