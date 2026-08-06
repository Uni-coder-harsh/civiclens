import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civiclens/app.dart';

void main() {
  testWidgets('CivicLens app Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CivicLensApp(),
      ),
    );
    expect(find.byType(CivicLensApp), findsOneWidget);
  });
}
