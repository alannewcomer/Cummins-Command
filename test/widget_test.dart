import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CumminsCommandApp()),
    );
    // Verify the app renders something
    expect(find.byType(CumminsCommandApp), findsOneWidget);
  });
}
