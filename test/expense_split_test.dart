import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/model.dart';
import 'ui_review_test.dart' show sample;

void main() {
  test(
    'rent outside plan keeps budget, daily and category totals unchanged',
    () {
      final b = sample(), p = sample().plans.first;
      final before = b.budgetFree(p), spent = b.spent(p), free = b.spendable(p);
      b.consume(
        b.wallets.first.id,
        30000,
        '住房',
        today(),
        '房租',
        countsForPlan: false,
      );
      expect(b.budgetFree(p), before);
      expect(b.spent(p), spent);
      expect(b.spendable(p), free);
      expect(b.entries.last.expense, 30000);
      expect(Book.fromJson(b.toJson()).entries.last.countsForPlan, false);
    },
  );
  test(
    'custody share reduces held liability and only own share is consumption',
    () {
      final b = sample(), w = b.wallets.first.id, p = b.plans.first;
      b.depositCustody('朋友', w, 60000, today());
      final id = b.custodies.single.id;
      final cash = b.cash, assets = b.assets, budget = b.budgetFree(p);
      b.consume(
        w,
        9000,
        '餐饮',
        today(),
        '共同购买',
        custodyId: id,
        custodyAmount: 3000,
      );
      expect(b.held, 57000);
      expect(b.cash, cash - 6000);
      expect(b.assets, assets - 6000);
      expect(b.budgetFree(p), budget - 6000);
      expect(b.entries.last.expense, 6000);
      var restored = Book.fromJson(b.toJson());
      restored.voidEntry(restored.entries.last, '误记');
      expect(restored.held, 60000);
      expect(restored.cash, cash);
      restored.consume(
        w,
        2000,
        '购物',
        today(),
        '',
        custodyId: id,
        custodyAmount: 2000,
        countsForPlan: false,
      );
      restored = Book.fromJson(restored.toJson());
      expect(restored.entries.last.expense, 0);
      expect(restored.cash, cash);
    },
  );
  test('invalid shares and wrong wallet reject before adding entries', () {
    final b = sample(), w = b.wallets.first.id;
    b.depositCustody('朋友', w, 10000, today());
    final id = b.custodies.single.id, count = b.entries.length;
    for (final amount in [-1, 20001]) {
      expect(
        () => b.consume(
          w,
          20000,
          '购物',
          today(),
          '',
          custodyId: id,
          custodyAmount: amount,
        ),
        throwsStateError,
      );
    }
    expect(
      () => b.consume(
        w,
        20000,
        '购物',
        today(),
        '',
        custodyId: id,
        custodyAmount: 15000,
      ),
      throwsStateError,
    );
    expect(
      () => b.consume(
        b.wallets.last.id,
        1000,
        '购物',
        today(),
        '',
        custodyId: id,
        custodyAmount: 500,
      ),
      throwsStateError,
    );
    expect(b.entries.length, count);
  });
}
