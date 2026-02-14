import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for biometric preferences stored in secure storage.
class _BiometricKeys {
  static const String enabled = 'biometric_enabled';
}

/// Service wrapping local_auth for biometric authentication.
///
/// Handles checking device capability, enrolling/unenrolling, and
/// authenticating the user via Face ID or fingerprint.
@lazySingleton
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Check if the device supports any biometric authentication.
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Check if biometrics are available (enrolled on device).
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Get the list of available biometric types on this device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Whether the user has enabled biometric login for the app.
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _BiometricKeys.enabled);
    return value == 'true';
  }

  /// Enable biometric login. Returns true if authentication succeeded.
  Future<bool> enableBiometric() async {
    final authenticated = await authenticate(reason: 'Verify your identity to enable biometric login');
    if (authenticated) {
      await _storage.write(key: _BiometricKeys.enabled, value: 'true');
    }
    return authenticated;
  }

  /// Disable biometric login.
  Future<void> disableBiometric() async {
    await _storage.delete(key: _BiometricKeys.enabled);
  }

  /// Authenticate the user using biometrics.
  ///
  /// Returns true if authentication succeeded, false otherwise.
  Future<bool> authenticate({
    String reason = 'Authenticate to access Money Guardian',
  }) async {
    try {
      final canAuth = await canCheckBiometrics();
      final isSupported = await isDeviceSupported();

      if (!canAuth || !isSupported) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
