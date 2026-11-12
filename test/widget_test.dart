import 'package:flutter_test/flutter_test.dart';
import 'package:savera/main.dart';
import 'package:savera/pages/landing_page.dart';

void main() {
  testWidgets('WelcomeScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(halamanPertama: WelcomeScreen()));
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
