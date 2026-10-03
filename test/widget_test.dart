import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/main.dart';

void main() {
  testWidgets('PRISM app loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PrismApp());
    await tester.pump();

    expect(find.text('PRISM'), findsOneWidget);
    expect(find.text('Flood Hazard Awareness'), findsOneWidget);
  });
}
