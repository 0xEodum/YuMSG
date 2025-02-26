class DeviceInfo {
  final String id;
  final String name;
  final DateTime lastActive;
  final bool isCurrentDevice;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.lastActive,
    required this.isCurrentDevice,
  });
}