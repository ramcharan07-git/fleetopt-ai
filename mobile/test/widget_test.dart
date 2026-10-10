import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleetopt_ai/main.dart';

void main() {
  testWidgets('FleetOpt AI App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: FleetOptApp(),
      ),
    );

    // Verify FleetOpt AI branding renders
    expect(find.text('FleetOpt AI'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
