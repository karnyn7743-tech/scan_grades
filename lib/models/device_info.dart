class DeviceInfo {
  final String id;
  final String host;
  final int port;
  final String name;
  final bool isTrusted;

  DeviceInfo({
    required this.id,
    required this.host,
    required this.port,
    required this.name,
    this.isTrusted = false,
  });
}
