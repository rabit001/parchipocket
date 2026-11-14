import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/main.dart';
import 'package:parchipocket/shared/widgets/ui.dart';

void main() {
  testWidgets('shows ParchiPocket welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ParchiPocketApp());
    expect(find.byKey(PpBrandLogo.imageKey), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
