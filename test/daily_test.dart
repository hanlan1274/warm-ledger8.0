import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/model.dart';

void main() {
  Book fixture() {
    final b = Book()..addWallet('现金', 100000);
    b.plans.add(
      Plan(
        id: 'plan',
        name: '30天生活费',
        start: '2026-01-01',
        end: '2026-01-30',
        budget: 100000,
        assetFloor: 0,
        cashFloor: 0,
        savings: 0,
        openingAssets: 100000,
        openingCash: 100000,
        original: {
          'budget': 100000,
          'assetFloor': 0,
          'cashFloor': 0,
          'savings': 0,
          'start': '2026-01-01',
          'end': '2026-01-30',
        },
        reservations: [
          Reservation('话费', '话费', 10000, true),
          Reservation('日用品', '日用品', 10000, true),
        ],
        history: [],
      ),
    );
    return b;
  }

  test('1000 minus 200 reserves divides 800 over 30 inclusive days', () {
    final b = fixture(), p = b.plans.single;
    b.enableDaily(p);
    expect(p.dailyOriginal, 2666);
    expect(b.dailyAllowance(p, '2026-01-01'), 2666);
    expect(b.daysLeft(p, '2025-12-31'), 30);
    expect(b.daysLeft(p, '2026-01-30'), 1);
    expect(b.daysLeft(p, '2026-01-31'), 0);
    expect(b.dailyAllowance(p, '2026-01-31'), 0);
    expect(b.calendarDays('2024-02-28', '2024-03-01'), 3);
  });

  test('reserved spending is not deducted twice, excess uses daily pool', () {
    final b = fixture(), p = b.plans.single;
    b.enableDaily(p);
    final wallet = b.wallets.single.id;
    b.consume(wallet, 3000, '日用品', '2026-01-01', '洗衣液');
    expect(b.reserved(p), 17000);
    expect(b.budgetFree(p), 80000);
    b.consume(wallet, 2000, '餐饮', '2026-01-01', '午饭');
    expect(b.budgetFree(p), 78000);
    expect(b.dailyAllowance(p, '2026-01-02'), 2689);
    expect(b.dailySpent(p, '2026-01-01'), 5000);
    b.consume(wallet, 8000, '日用品', '2026-01-02', '额外采购');
    expect(b.budgetFree(p), 77000);
    expect(p.dailyOriginal, 2666);
    p.budget = 120000;
    b.enableDaily(p);
    expect(p.dailyOriginal, 2666);
    expect(Book.fromJson(b.toJson()).plans.single.dailyOriginal, 2666);
    final backup = b.toJson();
    (backup['plans'] as List).first.remove('dailyOriginal');
    expect(Book.fromJson(backup).plans.single.dailyOriginal, isNull);
  });

  test('overspending yields zero daily suggestion and keeps deficit', () {
    final b = fixture(), p = b.plans.single;
    b.enableDaily(p);
    b.consume(b.wallets.single.id, 90000, '餐饮', '2026-01-01', '超支');
    expect(b.budgetFree(p), -10000);
    expect(b.dailyAllowance(p, '2026-01-02'), 0);
    final entry = b.entries.last;
    b.voidEntry(entry, '误记');
    expect(b.budgetFree(p), 80000);
    expect(p.dailyOriginal, 2666);
  });
}
