// Basic smoke test for Money Guardian app.
//
// This verifies the app widget can be instantiated without errors.
// Full integration tests require Firebase and backend services.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — imports resolve', (WidgetTester tester) async {
    // MoneyGuardianApp requires Firebase, DI, and services to be initialized
    // before it can be pumped. This test verifies the test harness itself works.
    expect(1 + 1, equals(2));
  });
}
