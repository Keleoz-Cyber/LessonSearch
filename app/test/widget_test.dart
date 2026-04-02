import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lesson_search/app.dart';

void main() {
  testWidgets('Home page shows three entry cards', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    expect(find.text('点名'), findsOneWidget);
    expect(find.text('记名'), findsOneWidget);
    expect(find.text('查课记录'), findsOneWidget);
  });
}
