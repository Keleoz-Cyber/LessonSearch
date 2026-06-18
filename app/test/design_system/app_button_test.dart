import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lesson_search/shared/design_system/widgets/app_button.dart';

void main() {
  Widget wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

  testWidgets('primary 渲染 label 和 onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(AppButton.primary(
      label: '确认',
      onPressed: () => tapped = true,
    )));
    expect(find.text('确认'), findsOneWidget);
    await tester.tap(find.text('确认'));
    expect(tapped, isTrue);
  });

  testWidgets('disabled 时不可点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(const AppButton.primary(
      label: '确认',
      onPressed: null,
    )));
    await tester.tap(find.text('确认'));
    expect(tapped, isFalse);
  });

  testWidgets('loading 时显示 progress', (tester) async {
    await tester.pumpWidget(wrap(AppButton.primary(
      label: '确认',
      onPressed: () {},
      loading: true,
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('loading 时不可点击', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(AppButton.primary(
      label: '确认',
      onPressed: () => tapped = true,
      loading: true,
    )));
    await tester.tap(find.text('确认'));
    expect(tapped, isFalse);
  });

  testWidgets('gradient 变体应用渐变', (tester) async {
    await tester.pumpWidget(wrap(AppButton.gradient(
      label: '开始',
      onPressed: () {},
    )));
    final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
  });
}
