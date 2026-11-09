import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/main.dart';
import 'package:warm_ledger/model.dart';
import 'package:warm_ledger/themes.dart';
import 'package:warm_ledger/editor.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'ui_review_test.dart' show MemoryStorage, sample;

Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final weight in [400, 600]) {
      await (FontLoader('LedgerSans')
            ..addFont(rootBundle.load('assets/fonts/LedgerSans-$weight.ttf')))
          .load();
    }
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-600.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(375, 812),
    const Size(320, 720),
    const Size(812, 375),
  ]) {
    testWidgets('new secondary routes and hierarchy at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final b = sample();
      final p = b.plans.first;
      final now = DateTime.now();
      b.depositCustody('小林', b.wallets.first.id, 30000, today());
      b.fixedCosts.add(
        FixedCost(
          id: 'fixed',
          name: '每月话费',
          category: '通讯/手机/话费',
          amount: 5000,
          dueDay: 1,
          startMonth: today().substring(0, 7),
          planId: p.id,
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: LedgerTheme.all.first.data,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 320 ? 2 : 1),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: LedgerApp(storage: MemoryStorage(b), onThemeChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('个人统计'));
      await tester.pumpAndSettle();
      expect(find.text('总支出 · 实际消费'), findsOneWidget);
      if (size.width == 375) await shot(tester, key, 'upgrade-statistics');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(p.name),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(p.name));
      await tester.pumpAndSettle();
      expect(find.text('资金与预算明细'), findsOneWidget);
      if (size.width == 375) await shot(tester, key, 'upgrade-plan-detail');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('管理每月固定开支'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('管理每月固定开支'));
      await tester.pumpAndSettle();
      expect(find.text('每月话费'), findsOneWidget);
      if (size.width == 375) await shot(tester, key, 'upgrade-fixed-costs');
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '代管'));
      await tester.pumpAndSettle();
      expect(find.text('小林'), findsOneWidget);
      if (size.width == 375) await shot(tester, key, 'upgrade-custody');
      expect(tester.takeException(), isNull);
      // Natural-month filtering must not hide the currently selected month.
      expect(now.month, DateTime.now().month);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('three-level category picker traverses and returns full key', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.all.first.data,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('选择'),
              onPressed: () async {
                result = await selectLedgerOption(context, '分类', {
                  '餐饮': '餐饮',
                  '餐饮/日常吃饭': '日常吃饭',
                  '餐饮/日常吃饭/午餐': '午餐',
                }, categories: true);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日常吃饭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('午餐'));
    await tester.pumpAndSettle();
    expect(result, '餐饮/日常吃饭/午餐');
  });
  testWidgets('expense editor saves outside-plan custody share', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = sample();
    b.depositCustody('小林', b.wallets.first.id, 60000, today());
    final store = MemoryStorage(b), key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: LedgerTheme.all.first.data,
          home: LedgerApp(storage: store, onThemeChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('支出').last);
    await tester.pumpAndSettle();
    expect(find.text('记支出 · 0.3.0'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('expense-total')), '90');
    await tester.tap(find.byKey(const ValueKey('expense-plan-out')));
    final toggle = find.byType(SwitchListTile).first;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final share = find.byKey(const ValueKey('expense-custody-amount'));
    await tester.ensureVisible(share);
    await tester.enterText(share, '30');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('个人承担 ¥60.00 · 计划扣款 ¥0.00'), findsOneWidget);
    await shot(tester, key, 'expense-independent-page');
    await tester.tap(find.byKey(const ValueKey('expense-save')));
    await tester.pumpAndSettle();
    expect(store.book.entries.last.countsForPlan, false);
    expect(store.book.entries.last.custodyCovered, 3000);
    expect(store.book.entries.last.expense, 6000);
    expect(store.book.held, 57000);
    expect(tester.takeException(), isNull);
  });
}
