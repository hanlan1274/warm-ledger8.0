import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/main.dart';
import 'package:warm_ledger/model.dart';
import 'package:warm_ledger/storage.dart';
import 'package:warm_ledger/themes.dart';

class MemoryStorage extends Storage {
  MemoryStorage(this.book);
  Book book;
  @override
  Future<Book> open() async => Book.fromJson(book.toJson());
  @override
  Future<void> save(Book value) async {
    book = Book.fromJson(value.toJson());
  }
}

// Sample data belongs only to tests, never to a newly installed ledger.
Book sample() {
  final b = Book()
    ..addWallet('微信零钱', 200000)
    ..addWallet('日常生活费银行卡', 100000);
  final c = Claim('friend', '朋友借款', '小林', '朋友借款', '', isLoan: true);
  b.claims.add(c);
  b.record(
    kind: '借出',
    date: today(),
    cash: {b.wallets.first.id: -50000},
    claimChanges: {c.id: 50000},
  );
  final end = day(DateTime.now().add(const Duration(days: 19)));
  final p = Plan(
    id: 'plan',
    name: '日常生活',
    start: today(),
    end: end,
    budget: 100000,
    assetFloor: 180000,
    cashFloor: 150000,
    savings: 10000,
    openingAssets: b.assets,
    openingCash: b.cash,
    original: {
      'budget': 100000,
      'assetFloor': 180000,
      'cashFloor': 150000,
      'savings': 10000,
      'start': today(),
      'end': end,
    },
    categoryLimits: {'餐饮': 80000},
    reservations: [Reservation('日用品', '日用品', 20000, true)],
    history: [],
  );
  b.plans.add(p);
  b.selectedPlan = p.id;
  b.enableDaily(p);
  b.consume(b.wallets.first.id, 1800, '餐饮', today(), '午餐');
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('LedgerSans')
          ..addFont(rootBundle.load('assets/fonts/LedgerSans-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/LedgerSans-600.ttf')))
        .load();
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-600.ttf'))).load();
  });

  for (final theme in LedgerTheme.all) {
    for (final size in [
      const Size(375, 812),
      const Size(320, 720),
      const Size(812, 375),
    ]) {
      testWidgets('${theme.id} pages at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final imageKey = GlobalKey();
        final store = MemoryStorage(sample()..themeId = theme.id);
        await tester.pumpWidget(
          RepaintBoundary(
            key: imageKey,
            child: MaterialApp(
              theme: theme.data,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 2 : 1),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: LedgerApp(storage: store, onThemeChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var page = 0; page < 5; page++) {
          await tester.tap(find.byType(NavigationDestination).at(page));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${theme.id} / $size / $page',
          );
          // CI exports actual Flutter captures for visual review, not goldens.
          if (size.width == 375 &&
              (theme.id == 'warm' || theme.id == 'night')) {
            final boundary =
                imageKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('build/ui-review/${theme.id}-$page.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final scroll = find.byType(ListView).first;
          // Reach below the fold: reservation cards, charts and long ledger rows.
          for (var i = 0; i < 8; i++) {
            await tester.drag(scroll, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${theme.id} / $size / $page / scroll $i',
            );
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
