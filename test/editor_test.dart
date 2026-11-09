import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/editor.dart';
import 'package:warm_ledger/themes.dart';

List<Field> fields() => [
  Field('amount', '金额 · 元', amount: true),
  Field('category', '分类', options: {'meal': '餐饮', 'custom': '我的自定义分类'}),
  Field('wallet', '付款账户', options: {'a': '微信零钱', 'b': '生活费银行卡'}),
  Field('date', '日期', date: true, value: '2026-01-01'),
  Field('note', '备注', optional: true),
  Field('photo', '附加图片', toggle: true),
];

void main() {
  testWidgets(
    'invalid amount stays inline; dynamic category and account are saved',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, String>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.all.first.data,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showLedgerEditor(
                    context,
                    '记一笔支出',
                    fields(),
                    quick: true,
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '1.234');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效金额，最多两位小数'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byType(TextFormField).first, '18.50');
      await tester.ensureVisible(find.text('我的自定义分类'));
      await tester.tap(find.text('我的自定义分类'));
      final account = find.byType(LedgerChoice);
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.tap(find.text('生活费银行卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(result?['amount'], '18.50');
      expect(result?['category'], 'custom');
      expect(result?['wallet'], 'b');
      expect(result?['note'], '');
      expect(result?['photo'], 'false');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 720),
    const Size(812, 375),
    const Size(812, 300),
  ]) {
    testWidgets('editor remains scrollable above keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inset = ValueNotifier<double>(0);
      addTearDown(inset.dispose);
      Map<String, String>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.resolve('night').data,
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: inset,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width < 400 ? 2 : 1),
                disableAnimations: true,
                viewInsets: EdgeInsets.only(bottom: value),
              ),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showLedgerEditor(
                    context,
                    '记一笔支出',
                    fields(),
                    quick: true,
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      inset.value = size.height > 500 ? 280 : 150;
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '88.00');
      // EditableText may schedule caret scrolling for the next frame. Complete
      // that before scrolling to another control, as a user would do.
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '保存');
      if (size.height >= 375) {
        // Normal phone/landscape height must keep the entire action visible,
        // without requiring the user to scroll away from a focused input.
        expect(tester.getTopLeft(save).dy, greaterThanOrEqualTo(0));
        expect(
          tester.getBottomRight(save).dy,
          lessThanOrEqualTo(size.height - inset.value),
        );
      }
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(save).dy, greaterThanOrEqualTo(0));
      expect(
        tester.getBottomRight(save).dy,
        lessThanOrEqualTo(size.height - inset.value),
      );
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(LedgerEditor), findsNothing);
      expect(result?['amount'], '88.00');
      expect(tester.takeException(), isNull);
      inset.value = 0;
      await tester.pumpAndSettle();
    });
  }
}
