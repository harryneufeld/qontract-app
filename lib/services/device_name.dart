import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Human-readable name of this device, shown in the list of signed-in devices.
/// Falls back to the platform name where the plugin is unavailable.
class DeviceName {
  static String? _cached;

  static Future<String> resolve() async {
    final cached = _cached;
    if (cached != null) return cached;
    String name;
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        name = '${(await info.webBrowserInfo).browserName.name} (web)';
      } else {
        name = switch (defaultTargetPlatform) {
          TargetPlatform.android => await _android(info),
          TargetPlatform.iOS => (await info.iosInfo).name,
          TargetPlatform.macOS => (await info.macOsInfo).computerName,
          TargetPlatform.windows => (await info.windowsInfo).computerName,
          TargetPlatform.linux => (await info.linuxInfo).prettyName,
          _ => defaultTargetPlatform.name,
        };
      }
    } catch (_) {
      name = kIsWeb ? 'Web browser' : defaultTargetPlatform.name;
    }
    name = name.trim();
    if (name.isEmpty) name = defaultTargetPlatform.name;
    return _cached = name.length > 100 ? name.substring(0, 100) : name;
  }

  static Future<String> _android(DeviceInfoPlugin info) async {
    final android = await info.androidInfo;
    final model = android.model;
    final brand = android.manufacturer;
    return model.toLowerCase().startsWith(brand.toLowerCase())
        ? model
        : '$brand $model';
  }
}
