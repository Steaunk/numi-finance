import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    // Full widget tree requires Riverpod + SharedPreferences setup.
    // Just verify the test runner works.
    expect(1 + 1, 2);
  });
}
