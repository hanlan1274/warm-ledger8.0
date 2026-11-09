import '../lib/model.dart';

void check(bool ok, String label) {
  if (!ok) throw StateError(label);
  print('PASS $label');
}

void rejects(void Function() fn, String label) {
  var rejected = false;
  try {
    fn();
  } catch (_) {
    rejected = true;
  }
  check(rejected, label);
}

Plan makePlan(String id, String start, String end, {int budget = 100000}) =>
    Plan(
      id: id,
      name: id,
      start: start,
      end: end,
      budget: budget,
      assetFloor: 0,
      cashFloor: 0,
      savings: 0,
      openingAssets: 300000,
      openingCash: 300000,
      original: {
        'budget': budget,
        'assetFloor': 0,
        'cashFloor': 0,
        'savings': 0,
        'start': start,
        'end': end,
      },
      reservations: [],
      categoryLimits: {},
      history: [],
    );
void main() {
  final b = Book()..addWallet('现金', 100000);
  final w = b.wallets.single.id;
  b.depositCustody('小林', w, 30000, today());
  check(
    b.assets == 100000 &&
        b.held == 30000 &&
        b.grossCash == 130000 &&
        b.cash == 100000,
    '代管不增加个人资产',
  );
  b.consume(w, 100001, '餐饮', today(), '暂时垫用代管款');
  check(b.walletAvailable(w) == -1, '消费可暂时动用代管款');
  b.addWallet('银行卡', 0);
  rejects(
    () => b.transfer(w, b.wallets.last.id, 100001, today(), ''),
    '转账不能动用代管款',
  );
  b.returnCustody(b.custodies.single.id, 10000, today());
  check(
    b.assets == -1 && b.held == 20000 && b.grossCash == 19999,
    '部分归还保留垫款缺口',
  );
  rejects(
    () => b.voidEntry(b.entries.firstWhere((e) => e.kind == '代管存入'), '错账'),
    '已归还代管不能先作废存入',
  );
  b.voidEntry(b.entries.last, '归还错账');
  check(b.held == 30000 && b.assets == -1, '作废归还恢复代管');
  check(Book.fromJson(b.toJson()).held == 30000, '代管备份恢复');
  final old = Book()..addWallet('旧账户', 12345);
  final json = old.toJson()
    ..['schema'] = 1
    ..remove('custodies')
    ..remove('fixedCosts');
  check(Book.fromJson(json).assets == 12345, '旧schema1数据兼容');
  final large = makePlan('large', '2026-01-01', '2026-12-31');
  final small = makePlan('small', '2026-05-01', '2026-05-07');
  b.plans.addAll([small, large]);
  check(b.overviewPlan('2026-05-02')!.id == 'large', '全局采用最大周期');
  b.transitionPlan('large', 'draft');
  check(b.overviewPlan('2026-05-02')!.id == 'small', '计划中不参与全局预算');
  b.transitionPlan('large', 'next');
  b.transitionPlan('small', 'next');
  check(large.status == 'draft' && small.status == 'next', '下一个执行唯一');
  b.transitionPlan('large', 'active');
  b.receiveIncome(
    wallet: w,
    amount: 100001,
    date: today(),
    category: '收入',
    note: '补回临时垫款',
  );
  final fixed = FixedCost(
    id: 'rent',
    name: '房租',
    category: '住房/居住/房租',
    amount: 5000,
    dueDay: 31,
    startMonth: '2026-01',
    endMonth: '2026-02',
    planId: 'large',
  );
  b.fixedCosts.add(fixed);
  check(fixed.dueDate('2026-02') == '2026-02-28', '固定开支短月到期');
  check(b.fixedReserved(large) == 10000, '固定开支按到期月份预留');
  final before = b.spendable(large);
  b.payFixed(fixed.id, '2026-01', w, '2026-01-31');
  check(
    b.fixedReserved(large) == 5000 && b.spent(large) == 105001,
    '支付固定开支释放预留并记一次支出',
  );
  check(b.spendable(large) == before, '支付不重复扣减可花预算');
  rejects(() => b.payFixed(fixed.id, '2026-01', w, '2026-01-31'), '固定开支阻止重复付款');
  check(
    b.between('2026-01-01', '2026-01-31').fold(0, (n, e) => n + e.expense) ==
        5000,
    '自然月支出独立于计划',
  );
  b.voidEntry(b.entries.last, '错账');
  check(b.fixedReserved(large) == 10000, '作废固定开支恢复预留');
  b.selectedPlan = 'large';
  b.deletePlan('large');
  check(
    b.selectedPlan.isEmpty && fixed.planId.isEmpty && b.entries.isNotEmpty,
    '删除计划保留流水并解除固定开支关联',
  );
  final c = Book()..addWallet('现金', 100000);
  c.consume(c.wallets.single.id, 1000, '餐饮/日常吃饭/午餐', today(), '');
  final date = DateTime.now();
  final p = makePlan(
    'month',
    day(DateTime(date.year, date.month)),
    day(DateTime(date.year, date.month + 1, 0)),
  );
  check(c.spent(p, '餐饮') == 1000 && c.spent(p, '餐饮/日常吃饭') == 1000, '三级分类汇总到父级');
  c.validateExtensions();
  Book.fromJson(c.toJson());
  print('ALL REGRESSIONS PASSED');
}
