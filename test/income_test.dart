import 'package:flutter_test/flutter_test.dart';
import 'package:warm_ledger/model.dart';
import 'ui_review_test.dart' show sample;

void main() {
  test(
    'partial income preserves negative custody-gap snapshots across saves',
    () {
      final b = Book()..addWallet('微信1', 0);
      final w = b.wallets.single.id;
      b.depositCustody('朋友', w, 60000, today());
      b.consume(w, 8000, '餐饮', today(), '暂用代管款');
      b.receiveIncome(wallet: w, amount: 2000, date: today(), category: '收入');
      b.validateExtensions();
      final restored = Book.fromJson(b.toJson());
      expect(restored.walletBalance(w), 54000);
      expect(restored.held, 60000);
      expect(restored.entries.last.walletAfter, -6000);
      expect(restored.entries.last.cashAfter, -6000);
      restored.receiveIncome(
        wallet: w,
        amount: 1000,
        date: today(),
        category: '收入',
      );
      final savedAgain = Book.fromJson(restored.toJson());
      expect(savedAgain.walletAvailable(w), -5000);
      savedAgain.voidEntry(savedAgain.entries.last, '误记');
      expect(Book.fromJson(savedAgain.toJson()).walletAvailable(w), -6000);
    },
  );
  test(
    'income can replenish one plan, updates all calculations, and reverses on void',
    () {
      final b = sample(), p = sample().plans.first;
      final actual = b.plans.first;
      final w = b.wallets.first.id;
      final cash = b.cash,
          available = b.walletAvailable(w),
          free = b.spendable(actual),
          limit = b.budgetLimit(actual);
      b.receiveIncome(
        wallet: w,
        amount: 10000,
        date: today(),
        category: '收入',
        planId: actual.id,
      );
      expect(b.cash, cash + 10000);
      expect(b.walletAvailable(w), available + 10000);
      expect(b.budgetLimit(actual), limit);
      expect(b.spendable(actual), free + 10000);
      expect(b.entries.last.cashAfter, b.cash);
      expect(b.entries.last.walletAfter, b.walletAvailable(w));
      expect(b.entries.last.planAfter, b.spendable(actual));
      final restored = Book.fromJson(b.toJson());
      expect(restored.incomeAdded(restored.plans.first), 10000);
      b.voidEntry(b.entries.last, '错账');
      expect(b.incomeAdded(actual), 0);
      expect(b.spendable(actual), free);
      expect(b.cash, cash);
      expect(p.id, actual.id);
    },
  );
  test('included income restores plan room after a shared purchase', () {
    final b = sample();
    final p = b.plans.first;
    final w = b.wallets.first.id;
    b.consume(w, 9000, '餐饮', today(), '先替朋友买单');
    final afterPurchase = b.spendable(p);
    b.receiveIncome(
      wallet: w,
      amount: 3000,
      date: today(),
      category: '收入',
      planId: p.id,
      note: '朋友分摊',
    );
    expect(b.budgetLimit(p), p.budget);
    expect(b.spendable(p), afterPurchase + 3000);
    expect(b.entries.last.incomePlanId, p.id);
  });
  test(
    'excluded income raises cash without changing plan limit or duplicating monthly income',
    () {
      final b = sample(), p = bPlan();
      final actual = b.plans.first;
      final limit = b.budgetLimit(actual),
          free = b.spendable(actual),
          cash = b.cash;
      b.receiveIncome(
        wallet: b.wallets.first.id,
        amount: 12000,
        date: today(),
        category: '收入',
      );
      expect(b.cash, cash + 12000);
      expect(b.budgetLimit(actual), limit);
      expect(b.spendable(actual), free);
      expect(
        b.entries.where((e) => e.income > 0).fold(0, (n, e) => n + e.income),
        12000,
      );
      expect(b.entries.last.incomePlanId, isEmpty);
      expect(p, isNotNull);
    },
  );
  test(
    'income belongs only to selected plan and survives plan deletion and old data',
    () {
      final b = sample(), first = bPlan();
      first.id = 'second';
      b.plans.add(first);
      b.receiveIncome(
        wallet: b.wallets.first.id,
        amount: 5000,
        date: today(),
        category: '收入',
        planId: b.plans.first.id,
      );
      expect(b.incomeAdded(first), 0);
      b.deletePlan(b.plans.first.id);
      expect(Book.fromJson(b.toJson()).cash, b.cash);
      final old = sample().toJson()..['schema'] = 2;
      for (final e in old['entries'] as List) {
        (e as Map).remove('incomePlanId');
        e.remove('incomePlanName');
        e.remove('cashAfter');
        e.remove('walletAfter');
        e.remove('planAfter');
      }
      expect(Book.fromJson(old).incomeAdded(Book.fromJson(old).plans.first), 0);
    },
  );
  test('invalid plan choice is rejected before ledger changes', () {
    final b = sample(), w = sample().wallets.first.id;
    final count = b.entries.length;
    expect(
      () => b.receiveIncome(
        wallet: w,
        amount: 5000,
        date: today(),
        category: '收入',
        planId: 'missing',
      ),
      throwsStateError,
    );
    expect(b.entries.length, count);
  });
}

Plan bPlan() => sample().plans.first;
