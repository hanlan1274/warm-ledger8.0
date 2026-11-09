import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/model.dart';

Plan plan({int budget = 100000, List<Reservation> reserves = const []}) => Plan(
  id: newId(),
  name: '20天计划',
  start: today(),
  end: day(DateTime.now().add(const Duration(days: 19))),
  budget: budget,
  assetFloor: 200000,
  cashFloor: 100000,
  savings: 50000,
  openingAssets: 300000,
  openingCash: 300000,
  original: {
    'budget': budget,
    'assetFloor': 200000,
    'cashFloor': 100000,
    'savings': 50000,
    'start': today(),
    'end': today(),
  },
  reservations: List.of(reserves),
  categoryLimits: {},
  history: [],
);

void main() {
  test(
    'theme preference round trips and old backups use the original theme',
    () {
      final b = Book()..addWallet('现金', 300000);
      b.themeId = 'night';
      final restored = Book.fromJson(b.toJson());
      expect(restored.themeId, 'night');
      expect(restored.cash, 300000);
      final old = b.toJson()..remove('themeId');
      expect(Book.fromJson(old).themeId, 'warm');
      expect(Book.fromJson(old).cash, 300000);
    },
  );
  test('money parsing preserves cents without floating point rounding', () {
    expect(cents('0.01'), 1);
    expect(cents('18.1'), 1810);
    expect(cents('3000'), 300000);
    expect(number(-105), '-1.05');
    for (final bad in ['-1', '1.001', 'NaN', '1e3', '']) {
      expect(() => cents(bad), throwsFormatException);
    }
  });
  test('lend 1000 from 3000: assets remain 3000, cash becomes 2000', () {
    final b = Book()..addWallet('微信', 300000);
    final w = b.wallets.single.id;
    final c = Claim(newId(), '借给小林', '小林', '朋友借款', '', isLoan: true);
    b.claims.add(c);
    b.record(
      kind: '借出',
      date: today(),
      cash: {w: -100000},
      claimChanges: {c.id: 100000},
    );
    expect(b.assets, 300000);
    expect(b.cash, 200000);
    expect(b.pending, 100000);
    expect(b.spent(plan()), 0);
    b.receiveClaim(c.id, w, 40000, today(), '部分归还');
    expect(b.assets, 300000);
    expect(b.cash, 240000);
    expect(b.claimBalance(c.id), 60000);
    expect(b.active.fold(0, (n, e) => n + e.income), 0);
    expect(() => b.receiveClaim(c.id, w, 60001, today(), ''), throwsStateError);
  });
  test(
    'repayment by person allocates oldest loan first and preserves assets',
    () {
      final b = Book()..addWallet('支付宝', 100000);
      final w = b.wallets.single.id;
      final first = Claim(newId(), '第一笔', '小林', '借款', '', isLoan: true);
      final second = Claim(newId(), '第二笔', '小林', '借款', '', isLoan: true);
      b.claims.addAll([first, second]);
      b.record(
        kind: '借出',
        date: today(),
        cash: {w: -30000},
        claimChanges: {first.id: 30000},
      );
      b.record(
        kind: '借出',
        date: today(),
        cash: {w: -20000},
        claimChanges: {second.id: 20000},
      );
      b.receivePerson('小林', w, 40000, today(), '归还');
      expect(b.claimBalance(first.id), 0);
      expect(b.claimBalance(second.id), 10000);
      expect(b.assets, 100000);
    },
  );
  test(
    'expected scholarship receipt only changes availability, not assets',
    () {
      final b = Book()..addWallet('银行卡', 0);
      final c = Claim(newId(), '奖学金', '学校', '奖学金', '');
      b.claims.add(c);
      b.record(kind: '登记应收', date: today(), claimChanges: {c.id: 200000});
      expect(b.assets, 200000);
      expect(b.cash, 0);
      b.receiveClaim(c.id, b.wallets.single.id, 180000, today(), '先发一部分');
      expect(b.assets, 200000);
      expect(b.cash, 180000);
      expect(b.pending, 20000);
      b.record(kind: '应收调整', date: today(), claimChanges: {c.id: -20000});
      expect(b.assets, 180000);
    },
  );
  test('transfer does not create income, expense, or assets', () {
    final b = Book()
      ..addWallet('微信', 100000)
      ..addWallet('银行卡', 0);
    b.transfer(b.wallets[0].id, b.wallets[1].id, 60000, today(), '转自己的钱');
    expect(b.cash, 100000);
    expect(b.spent(plan()), 0);
    expect(b.entries.last.income, 0);
    expect(
      () => b.transfer(b.wallets[0].id, b.wallets[0].id, 1, today(), ''),
      throwsStateError,
    );
  });
  test('can record a purchase temporarily paid from held money', () {
    final b = Book()..addWallet('微信', 0);
    final w = b.wallets.single.id;
    final custody = Custody(newId(), '朋友', w);
    b.custodies.add(custody);
    b.record(
      kind: '代管存入',
      date: today(),
      cash: {w: 60000},
      holdingChanges: {custody.id: 60000},
    );
    b.consume(w, 60000, '餐饮', today(), '暂时垫用代管款');
    expect(b.walletBalance(w), 0);
    expect(b.walletHeld(w), 60000);
    expect(b.walletAvailable(w), -60000);
    expect(b.cash, -60000);
    final restored = Book.fromJson(b.toJson());
    expect(restored.walletAvailable(w), -60000);
    b.receiveIncome(
      wallet: w,
      amount: 60000,
      date: today(),
      category: '收入',
      note: '补回代管垫款',
    );
    expect(b.walletAvailable(w), 0);
  });
  test(
    'paying a reserved expense inside the budget does not double deduct',
    () {
      final b = Book()..addWallet('生活费', 300000);
      final p = plan(reserves: [Reservation('房租', '住房', 60000, true)]);
      expect(b.spendable(p), 40000);
      b.consume(b.wallets.single.id, 60000, '住房', today(), '付房租');
      expect(b.reserved(p), 0);
      expect(b.spendable(p), 40000);
    },
  );
  test(
    'reserved expense outside budget leaves discretionary budget unchanged',
    () {
      final b = Book()..addWallet('生活费', 300000);
      final p = plan(reserves: [Reservation('房租', '住房', 60000, false)]);
      final before = b.spendable(p);
      b.consume(b.wallets.single.id, 60000, '住房', today(), '付房租');
      expect(b.budgetSpent(p), 0);
      expect(b.spendable(p), before);
      b.consume(b.wallets.single.id, 10000, '住房', today(), '超出预留的住房支出');
      expect(b.budgetSpent(p), 10000);
    },
  );
  test('overlapping periods both count expenses but cash decreases once', () {
    final b = Book()..addWallet('现金', 300000);
    final first = plan(), second = plan();
    b.plans.addAll([first, second]);
    b.consume(b.wallets.single.id, 1800, '餐饮', today(), '午餐');
    expect(b.spent(first), 1800);
    expect(b.spent(second), 1800);
    expect(b.cash, 298200);
  });
  test('revised budget and floors do not overwrite original snapshot', () {
    final b = Book()..addWallet('现金', 300000);
    final p = plan();
    b.plans.add(p);
    p.budget = 120000;
    p.assetFloor = 150000;
    final restored = Book.fromJson(b.toJson());
    expect(restored.plans.single.original['budget'], 100000);
    expect(restored.plans.single.original['assetFloor'], 200000);
    expect(restored.plans.single.openingAssets, 300000);
  });
  test(
    'archived balances remain assets; dependent entries cannot be voided',
    () {
      final b = Book()..addWallet('现金', 300000);
      final opening = b.entries.first;
      b.consume(b.wallets.single.id, 100, '餐饮', today(), '');
      b.wallets.single.archived = true;
      expect(b.cash, 299900);
      expect(() => b.voidEntry(opening, '误操作'), throwsStateError);
      expect(opening.voided, false);
      b.voidEntry(b.entries.last, '重复记录');
      expect(b.cash, 300000);
    },
  );
  test(
    'invalid backups fail validation instead of replacing with empty book',
    () {
      final b = Book()..addWallet('现金', 10000);
      final json = b.toJson();
      (json['entries'] as List).first['cash'] = {'missing-wallet': 10000};
      expect(() => Book.fromJson(json), throwsFormatException);
      expect(() => Book.fromJson({'schema': 999}), throwsFormatException);
    },
  );
}
