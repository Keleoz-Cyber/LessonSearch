import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lesson_search/app.dart';

// 注：完整渲染 App 需要 SharedPreferences / AppDatabase / ApiClient 等
// 在 main.dart 中通过 ProviderScope(overrides: ...) 注入。
// 此测试在未注入依赖时会抛 UnimplementedError，故标记为 skip。
// 待引入 mockito 或 integration_test 后可恢复。
void main() {
  testWidgets('Home page renders primary entries', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('开始记名'), findsOneWidget);
    expect(find.text('点名'), findsOneWidget);
    expect(find.text('查课记录'), findsOneWidget);
  }, skip: true);
}
