import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';

/// Initializes runtime application security via freeRASP.
///
/// In release builds this enables:
/// - Root/jailbreak detection
/// - Debugger detection
/// - Emulator detection
/// - Tamper detection
/// - Unofficial installer detection
///
/// In debug builds all callbacks are no-ops so development is unaffected.
class AppSecurity {
  AppSecurity._();

  static bool _initialized = false;

  /// Initialize freeRASP. Safe to call multiple times; only runs once.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Skip in debug mode — detection callbacks would interfere with dev
    if (kDebugMode) {
      debugPrint('[AppSecurity] Debug mode — skipping freeRASP init');
      return;
    }

    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'com.moneyguardian.app',
        signingCertHashes: [
          // TODO: Replace with your release signing cert SHA-256 hash
          // Run: keytool -list -v -keystore your-keystore.jks
          // Take the SHA-256 fingerprint and convert to Base64
        ],
      ),
      iosConfig: IOSConfig(
        bundleIds: ['com.moneyguardian.app'],
        teamId: '', // TODO: Set your Apple Developer Team ID
      ),
      watcherMail: 'security@moneyguardian.app',
      isProd: true,
    );

    // Define what happens when threats are detected
    final callback = ThreatCallback(
      onPrivilegedAccess: () {
        debugPrint('[AppSecurity] Root/jailbreak detected');
        // In production: show warning, limit features, or exit
      },
      onDebug: () {
        debugPrint('[AppSecurity] Debugger detected');
      },
      onSimulator: () {
        debugPrint('[AppSecurity] Emulator detected');
      },
      onAppIntegrity: () {
        debugPrint('[AppSecurity] App integrity compromised');
      },
      onUnofficialStore: () {
        debugPrint('[AppSecurity] Unofficial store install detected');
      },
      onHooks: () {
        debugPrint('[AppSecurity] Hook (Frida/Xposed) detected');
      },
      onDeviceBinding: () {
        debugPrint('[AppSecurity] Device binding mismatch');
      },
      onObfuscationIssues: () {
        debugPrint('[AppSecurity] Obfuscation issues detected');
      },
      onPasscode: () {
        debugPrint('[AppSecurity] No device passcode set');
      },
      onDevMode: () {
        debugPrint('[AppSecurity] Developer mode enabled');
      },
    );

    try {
      Talsec.instance.attachListener(callback);
      await Talsec.instance.start(config);
      debugPrint('[AppSecurity] freeRASP initialized');
    } catch (e) {
      debugPrint('[AppSecurity] Failed to initialize freeRASP: $e');
      // Non-fatal: app should still work without RASP
    }
  }
}
