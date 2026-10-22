import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/main.dart';

void main() {
  testWidgets('shows ParchiPocket welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ParchiPocketApp());
    expect(find.text('ParchiPocket'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
