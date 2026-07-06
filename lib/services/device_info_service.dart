import 'dart:io';

class DeviceInfoService {
  Future<DeviceStatus> load() async {

    final stat = await Directory('/storage/emulated/0').stat();

    // سيتم استبدال هذه القيم لاحقًا بقيم حقيقية
    return DeviceStatus(
      androidVersion: Platform.operatingSystemVersion,
      storageUsed: 0,
      storageFree: 0,
      batteryLevel: 0,
      deviceHealth: 97,
      lastUpdate: DateTime.now(),
    );
  }
}

class DeviceStatus {
  final String androidVersion;
  final int storageUsed;
  final int storageFree;
  final int batteryLevel;
  final int deviceHealth;
  final DateTime lastUpdate;

  DeviceStatus({
    required this.androidVersion,
    required this.storageUsed,
    required this.storageFree,
    required this.batteryLevel,
    required this.deviceHealth,
    required this.lastUpdate,
  });
}
