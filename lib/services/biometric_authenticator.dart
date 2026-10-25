import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Device unlock (fingerprint, face or the device passcode), behind an
/// interface so tests do not need the platform plugin.
abstract class BiometricAuthenticator {
  /// True on iOS and Android devices that have a biometric or screen lock set up.
  Future<bool> isAvailable();

  /// Asks the user to unlock; false when cancelled or failed.
  Future<bool> authenticate(String reason);
}

class LocalAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  static bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> isAvailable() async {
    if (!_supportedPlatform) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // biometricOnly stays false: the device passcode is the fallback.
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
