import 'package:flutter_test/flutter_test.dart';

import 'package:vome/main.dart';

void main() {
  testWidgets('Audiary app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiaryApp());
    await tester.pump();

    expect(find.text('Audiary'), findsOneWidget);
  });
}
