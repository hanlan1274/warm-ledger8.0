import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/themes.dart';
import 'package:warm_ledger/visuals.dart';

void main() {
  testWidgets('all themes render cards and charts at narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final theme in LedgerTheme.all) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.data,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SheetCard(child: Text('总资产 ¥3,000.00 · ${theme.name}')),
                  SheetCard(
                    gradient: LinearGradient(colors: theme.budgetGradient),
                    child: Text(
                      '计划内可花 ¥600.00',
                      style: TextStyle(color: theme.budgetText),
                    ),
                  ),
                  Donut(
                    values: const [200000, 100000],
                    colors: [theme.accent, theme.orange],
                    label: '资产分布',
                  ),
                  const Trend(
                    values: [100, 200, 0, 300, 400, 150, 100],
                    labels: ['一', '二', '三', '四', '五', '六', '日'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: theme.id);
      final context = tester.element(find.byType(SheetCard).first);
      expect(LedgerTheme.of(context).id, theme.id);
    }
    expect(LedgerTheme.resolve('unknown').id, 'warm');
  });
}
