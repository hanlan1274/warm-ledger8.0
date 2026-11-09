import 'dart:math';
import 'category_catalog.dart';

// All money is stored as integer cents. No floating point ledger arithmetic.
int cents(String text) {
  final clean = text.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
    throw const FormatException('请输入非负金额，最多两位小数');
  }
  final parts = clean.split('.');
  final result =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (result > 999999999999) throw const FormatException('金额过大');
  return result;
}

String number(int amount) =>
    '${amount < 0 ? '-' : ''}${amount.abs() ~/ 100}.${(amount.abs() % 100).toString().padLeft(2, '0')}';
String money(int amount) => '¥${number(amount)}';
String day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String today() => day(DateTime.now());
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
Map<String, dynamic> object(dynamic v) => Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> objects(dynamic v) =>
    (v as List).map(object).toList();

class Wallet {
  Wallet(this.id, this.name, {this.archived = false});
  String id, name;
  bool archived;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'archived': archived,
  };
  factory Wallet.fromJson(Map<String, dynamic> j) =>
      Wallet(j['id'], j['name'], archived: j['archived']);
}

class Claim {
  Claim(
    this.id,
    this.title,
    this.person,
    this.kind,
    this.due, {
    this.isLoan = false,
  });
  String id, title, person, kind, due;
  bool isLoan;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'person': person,
    'kind': kind,
    'due': due,
    'isLoan': isLoan,
  };
  factory Claim.fromJson(Map<String, dynamic> j) => Claim(
    j['id'],
    j['title'],
    j['person'],
    j['kind'],
    j['due'],
    isLoan: j['isLoan'] == true,
  );
}

class Entry {
  Entry({
    required this.id,
    required this.date,
    required this.kind,
    required this.note,
    this.category = '',
    this.cash = const {},
    this.claims = const {},
    this.expense = 0,
    this.income = 0,
    this.image = '',
    this.voided = false,
    this.holdings = const {},
    this.fixedId = '',
    this.fixedMonth = '',
    this.incomePlanId = '',
    this.incomePlanName = '',
    this.walletAfter,
    this.cashAfter,
    this.planAfter,
    this.countsForPlan = true,
    this.custodyCovered = 0,
  });
  String id, date, kind, note, category, image;
  Map<String, int> cash, claims;
  Map<String, int> holdings;
  String fixedId, fixedMonth;
  String incomePlanId, incomePlanName;
  int? walletAfter, cashAfter, planAfter;
  bool countsForPlan;
  int custodyCovered;
  int expense, income;
  bool voided;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'kind': kind,
    'note': note,
    'category': category,
    'cash': cash,
    'claims': claims,
    'expense': expense,
    'income': income,
    'image': image,
    'voided': voided,
    'holdings': holdings,
    'fixedId': fixedId,
    'fixedMonth': fixedMonth,
    'incomePlanId': incomePlanId,
    'incomePlanName': incomePlanName,
    'walletAfter': walletAfter,
    'cashAfter': cashAfter,
    'planAfter': planAfter,
    'countsForPlan': countsForPlan,
    'custodyCovered': custodyCovered,
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'],
    date: j['date'],
    kind: j['kind'],
    note: j['note'],
    category: j['category'],
    cash: Map<String, int>.from(j['cash']),
    claims: Map<String, int>.from(j['claims']),
    expense: j['expense'],
    income: j['income'],
    image: j['image'],
    voided: j['voided'],
    holdings: Map<String, int>.from(j['holdings'] ?? {}),
    fixedId: j['fixedId'] ?? '',
    fixedMonth: j['fixedMonth'] ?? '',
    incomePlanId: j['incomePlanId'] ?? '',
    incomePlanName: j['incomePlanName'] ?? '',
    walletAfter: j['walletAfter'] as int?,
    cashAfter: j['cashAfter'] as int?,
    planAfter: j['planAfter'] as int?,
    countsForPlan: j['countsForPlan'] != false,
    custodyCovered: j['custodyCovered'] ?? 0,
  );
}

class Reservation {
  Reservation(this.title, this.category, this.amount, this.inBudget);
  String title, category;
  int amount;
  bool inBudget;
  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category,
    'amount': amount,
    'inBudget': inBudget,
  };
  factory Reservation.fromJson(Map<String, dynamic> j) =>
      Reservation(j['title'], j['category'], j['amount'], j['inBudget']);
}

class Plan {
  Plan({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.budget,
    required this.assetFloor,
    required this.cashFloor,
    required this.savings,
    required this.openingAssets,
    required this.openingCash,
    required this.original,
    this.categoryLimits = const {},
    this.reservations = const [],
    this.history = const [],
    this.dailyOriginal,
    this.status = 'active',
    this.term = 'medium',
  });
  int?
  dailyOriginal; // Frozen daily allowance when daily planning is first enabled.
  String id, name, start, end;
  String status, term;
  int budget, assetFloor, cashFloor, savings, openingAssets, openingCash;
  Map<String, dynamic> original;
  Map<String, int> categoryLimits;
  List<Reservation> reservations;
  List<String> history;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': start,
    'end': end,
    'budget': budget,
    'assetFloor': assetFloor,
    'cashFloor': cashFloor,
    'savings': savings,
    'openingAssets': openingAssets,
    'openingCash': openingCash,
    'original': original,
    'categoryLimits': categoryLimits,
    'reservations': reservations.map((e) => e.toJson()).toList(),
    'history': history,
    'dailyOriginal': dailyOriginal,
    'status': status,
    'term': term,
  };
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    id: j['id'],
    name: j['name'],
    start: j['start'],
    end: j['end'],
    budget: j['budget'],
    assetFloor: j['assetFloor'],
    cashFloor: j['cashFloor'],
    savings: j['savings'],
    openingAssets: j['openingAssets'],
    openingCash: j['openingCash'],
    original: object(j['original']),
    categoryLimits: Map<String, int>.from(j['categoryLimits']),
    reservations: objects(j['reservations']).map(Reservation.fromJson).toList(),
    history: List<String>.from(j['history']),
    dailyOriginal: j['dailyOriginal'] as int?,
    status: j['status'] ?? 'active',
    term: j['term'] ?? 'medium',
  );
}

class Custody {
  Custody(this.id, this.owner, this.walletId);
  String id, owner, walletId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner': owner,
    'walletId': walletId,
  };
  factory Custody.fromJson(Map<String, dynamic> j) =>
      Custody(j['id'], j['owner'], j['walletId']);
}

class FixedCost {
  FixedCost({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.dueDay,
    required this.startMonth,
    this.endMonth = '',
    this.planId = '',
    this.enabled = true,
  });
  String id, name, category, startMonth, endMonth, planId;
  int amount, dueDay;
  bool enabled;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'amount': amount,
    'dueDay': dueDay,
    'startMonth': startMonth,
    'endMonth': endMonth,
    'planId': planId,
    'enabled': enabled,
  };
  factory FixedCost.fromJson(Map<String, dynamic> j) => FixedCost(
    id: j['id'],
    name: j['name'],
    category: j['category'],
    amount: j['amount'],
    dueDay: j['dueDay'],
    startMonth: j['startMonth'],
    endMonth: j['endMonth'] ?? '',
    planId: j['planId'] ?? '',
    enabled: j['enabled'] ?? true,
  );
  String dueDate(String month) {
    final d = DateTime.parse('$month-01');
    return day(
      DateTime(
        d.year,
        d.month,
        min(dueDay, DateTime(d.year, d.month + 1, 0).day),
      ),
    );
  }

  bool applies(String month) =>
      enabled &&
      month.compareTo(startMonth) >= 0 &&
      (endMonth.isEmpty || month.compareTo(endMonth) <= 0);
}

class Book {
  Book();
  List<Wallet> wallets = [];
  List<Claim> claims = [];
  List<Entry> entries = [];
  List<Plan> plans = [];
  List<String> categories = List.of(defaultCategories);
  List<Custody> custodies = [];
  List<FixedCost> fixedCosts = [];
  List<String> claimKinds = ['朋友借款', '奖学金', '房租押金', '其他应收'];
  String selectedPlan = '';
  String themeId = 'warm';
  bool notifications = false;
  Map<String, bool> alertState = {};
  List<String> audit = [];
  Map<String, String> images = {}; // Self-contained base64 JPEG attachments.
  Iterable<Entry> get active => entries.where((e) => !e.voided);
  int walletBalance(String id) =>
      active.fold(0, (n, e) => n + (e.cash[id] ?? 0));
  int claimBalance(String id) =>
      active.fold(0, (n, e) => n + (e.claims[id] ?? 0));
  int get grossCash => wallets.fold(0, (n, w) => n + walletBalance(w.id));
  int get cash => grossCash - held;
  int get pending => claims.fold(0, (n, c) => n + claimBalance(c.id));
  int get assets => cash + pending;
  Plan? get plan => plans.where((p) => p.id == selectedPlan).firstOrNull;
  Iterable<Entry> periodEntries(Plan p) => active.where(
    (e) =>
        e.date.compareTo(p.start) >= 0 &&
        e.date.compareTo(p.end) <= 0 &&
        e.countsForPlan &&
        (e.fixedId.isEmpty ||
            fixedCosts.firstWhere((f) => f.id == e.fixedId).planId.isEmpty ||
            fixedCosts.firstWhere((f) => f.id == e.fixedId).planId == p.id),
  );
  int spent(Plan p, [String? category]) => periodEntries(p)
      .where((e) => category == null || categoryMatches(e.category, category))
      .fold(0, (n, e) => n + e.expense);
  int reservedSpending(Plan p, String category) => periodEntries(p)
      .where((e) => e.fixedId.isEmpty && categoryMatches(e.category, category))
      .fold(0, (n, e) => n + e.expense);
  int reserved(Plan p, {bool includedOnly = false}) => p.reservations
      .where((r) => !includedOnly || r.inBudget)
      .fold(
        0,
        (n, r) => n + max(0, r.amount - reservedSpending(p, r.category)),
      );
  int budgetSpent(Plan p) =>
      spent(p) -
      p.reservations
          .where((r) => !r.inBudget)
          .fold(
            0,
            (n, r) => n + min(r.amount, reservedSpending(p, r.category)),
          );
  int incomeAdded(Plan p) => active
      .where((e) => e.incomePlanId == p.id && e.income > 0)
      .fold(0, (n, e) => n + e.income);
  // A reimbursement from another person offsets the user's share of a
  // purchase. It restores spendable room after recorded expenses; it never
  // enlarges the plan's original budget ceiling.
  int budgetLimit(Plan p) => p.budget;
  int budgetFree(Plan p) =>
      budgetLimit(p) -
      budgetSpent(p) -
      reserved(p, includedOnly: true) -
      fixedReserved(p) +
      incomeAdded(p);
  int cashFree(Plan p) => cash - reserved(p) - fixedReserved(p) - p.savings;
  int spendable(Plan p) => max(0, min(budgetFree(p), cashFree(p)));
  int heldBalance(String id) =>
      active.fold(0, (n, e) => n + (e.holdings[id] ?? 0));
  int get held => custodies.fold(0, (n, c) => n + heldBalance(c.id));
  int walletHeld(String id) => custodies
      .where((c) => c.walletId == id)
      .fold(0, (n, c) => n + heldBalance(c.id));
  int walletAvailable(String id) => walletBalance(id) - walletHeld(id);
  Plan? overviewPlan([String? date]) {
    final d = date ?? today();
    final candidates =
        plans
            .where(
              (p) =>
                  p.status == 'active' &&
                  p.start.compareTo(d) <= 0 &&
                  p.end.compareTo(d) >= 0,
            )
            .toList()
          ..sort((a, b) {
            final cmp = calendarDays(
              b.start,
              b.end,
            ).compareTo(calendarDays(a.start, a.end));
            return cmp != 0
                ? cmp
                : a.start != b.start
                ? a.start.compareTo(b.start)
                : a.id.compareTo(b.id);
          });
    return candidates.firstOrNull;
  }

  void transitionPlan(String id, String status) {
    if (!['active', 'next', 'draft', 'done'].contains(status))
      throw StateError('计划状态无效');
    final p = plans.firstWhere((p) => p.id == id);
    if (status == 'next') {
      for (final other in plans.where(
        (p) => p.status == 'next' && p.id != id,
      )) {
        other.status = 'draft';
        other.history.add('${today()} 改为计划中，下一项已变更');
      }
    }
    p.history.add('${today()} 状态 ${p.status} → $status');
    p.status = status;
  }

  void deletePlan(String id) {
    final p = plans.firstWhere((p) => p.id == id);
    plans.removeWhere((p) => p.id == id);
    for (final f in fixedCosts.where((f) => f.planId == id)) {
      f.planId = '';
    }
    alertState.removeWhere((key, _) => key.startsWith('$id:'));
    if (selectedPlan == id) selectedPlan = '';
    audit.add('${today()} 删除计划 ${p.name}；流水和固定开支保留');
  }

  void depositCustody(String owner, String wallet, int amount, String date) {
    if (owner.trim().isEmpty || amount <= 0) throw StateError('请填写委托人和正数金额');
    if (!wallets.any((w) => w.id == wallet && !w.archived))
      throw StateError('请选择使用中的账户');
    final c = Custody(newId(), owner.trim(), wallet);
    custodies.add(c);
    try {
      record(
        kind: '代管存入',
        date: date,
        cash: {wallet: amount},
        holdingChanges: {c.id: amount},
        note: '${c.owner} · 代管',
      );
    } catch (_) {
      custodies.remove(c);
      rethrow;
    }
  }

  void returnCustody(String id, int amount, String date) {
    final c = custodies.firstWhere((c) => c.id == id);
    if (amount <= 0 || amount > heldBalance(id)) throw StateError('归还金额超过代管余额');
    record(
      kind: '代管归还',
      date: date,
      cash: {c.walletId: -amount},
      holdingChanges: {id: -amount},
      note: '${c.owner} · 归还',
    );
  }

  List<String> monthsBetween(String start, String end) {
    final first = DateTime.parse(start), last = DateTime.parse(end);
    final count = (last.year - first.year) * 12 + last.month - first.month + 1;
    return List.generate(
      max(0, count),
      (i) => day(DateTime(first.year, first.month + i)).substring(0, 7),
    );
  }

  int fixedPaid(FixedCost f, String month) => active
      .where((e) => e.fixedId == f.id && e.fixedMonth == month)
      .fold(0, (n, e) => n + e.expense);
  int fixedRemaining(FixedCost f, String month) =>
      max(0, f.amount - fixedPaid(f, month));
  int fixedReserved(Plan p) => fixedCosts
      .where((f) => f.planId == p.id)
      .fold(
        0,
        (n, f) =>
            n +
            monthsBetween(p.start, p.end)
                .where(
                  (m) =>
                      f.applies(m) &&
                      f.dueDate(m).compareTo(p.start) >= 0 &&
                      f.dueDate(m).compareTo(p.end) <= 0,
                )
                .fold(0, (v, m) => v + fixedRemaining(f, m)),
      );
  void payFixed(String id, String month, String wallet, String date) {
    final f = fixedCosts.firstWhere((f) => f.id == id);
    if (!f.applies(month)) throw StateError('该月不在固定开支有效期内');
    final amount = fixedRemaining(f, month);
    if (amount <= 0) throw StateError('本月已支付，不可重复记账');
    record(
      kind: '支出',
      date: date,
      category: f.category,
      cash: {wallet: -amount},
      expense: amount,
      note: '${f.name} · $month 固定开支',
      fixedId: id,
      fixedMonth: month,
    );
    entries.last.countsForPlan = f.planId.isNotEmpty;
  }

  List<Entry> between(String start, String end) => active
      .where((e) => e.date.compareTo(start) >= 0 && e.date.compareTo(end) <= 0)
      .toList();
  void validateExtensions() {
    for (final e in entries) {
      if (e.custodyCovered < 0 ||
          (e.custodyCovered > 0 &&
              (e.kind != '支出' ||
                  e.income != 0 ||
                  e.claims.isNotEmpty ||
                  e.holdings.length != 1 ||
                  e.holdings.values.single != -e.custodyCovered ||
                  e.cash.length != 1 ||
                  e.cash.values.single != -(e.expense + e.custodyCovered) ||
                  !custodies.any(
                    (c) =>
                        c.id == e.holdings.keys.single &&
                        c.walletId == e.cash.keys.single,
                  ))))
        throw const FormatException('代管支出分摊无效');
      if (e.incomePlanId.isNotEmpty &&
          (e.income <= 0 ||
              e.kind != '收入' ||
              e.holdings.isNotEmpty ||
              e.expense != 0 ||
              e.claims.isNotEmpty ||
              e.cash.values.fold(0, (n, v) => n + v) != e.income)) {
        throw const FormatException('收入计划关联无效');
      }
      // Personal and wallet availability can be negative while held money
      // is temporarily used. Income may only partially replenish that gap.
      if (e.planAfter != null && e.planAfter! < 0) {
        throw const FormatException('收入余额快照无效');
      }
    }

    for (final p in plans) {
      for (var i = 0; i < p.reservations.length; i++) {
        for (var j = i + 1; j < p.reservations.length; j++) {
          final a = p.reservations[i].category, b = p.reservations[j].category;
          if (categoryMatches(a, b) || categoryMatches(b, a))
            throw const FormatException('预留分类不能同时使用父级与子级');
        }
      }
    }
    if (plans.any(
          (p) =>
              !['active', 'next', 'draft', 'done'].contains(p.status) ||
              !['short', 'medium', 'long'].contains(p.term) ||
              calendarDays(p.start, p.end) > 36600,
        ) ||
        plans.where((p) => p.status == 'next').length > 1)
      throw const FormatException('计划状态或周期无效');
    if (custodies.any(
      (c) =>
          c.owner.trim().isEmpty ||
          !wallets.any((w) => w.id == c.walletId) ||
          heldBalance(c.id) < 0,
    ))
      throw const FormatException('代管信息无效');
    if (fixedCosts.any(
      (f) =>
          f.name.trim().isEmpty ||
          f.category.trim().isEmpty ||
          f.amount <= 0 ||
          f.dueDay < 1 ||
          f.dueDay > 31 ||
          !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(f.startMonth) ||
          (f.endMonth.isNotEmpty &&
              (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(f.endMonth) ||
                  f.endMonth.compareTo(f.startMonth) < 0)) ||
          (f.planId.isNotEmpty && !plans.any((p) => p.id == f.planId)),
    ))
      throw const FormatException('固定开支无效');
    for (final e in entries.where((e) => e.holdings.isNotEmpty)) {
      if (e.custodyCovered > 0) continue;
      if (e.expense != 0 ||
          e.income != 0 ||
          e.claims.isNotEmpty ||
          e.cash.values.fold(0, (n, v) => n + v) !=
              e.holdings.values.fold(0, (n, v) => n + v))
        throw const FormatException('代管流水不平衡');
      for (final wallet in wallets) {
        final change = e.holdings.entries
            .where(
              (h) => custodies.any(
                (c) => c.id == h.key && c.walletId == wallet.id,
              ),
            )
            .fold(0, (n, h) => n + h.value);
        if ((e.cash[wallet.id] ?? 0) != change)
          throw const FormatException('代管账户不匹配');
      }
    }
  }

  // UTC calendar dates avoid daylight-saving changes in whole-day arithmetic.
  int calendarDays(String start, String end) {
    DateTime utc(String value) {
      final d = DateTime.parse(value);
      return DateTime.utc(d.year, d.month, d.day);
    }

    return utc(end).difference(utc(start)).inDays + 1;
  }

  int daysLeft(Plan p, String date) => date.compareTo(p.end) > 0
      ? 0
      : calendarDays(date.compareTo(p.start) < 0 ? p.start : date, p.end);
  int dailyAllowance(Plan p, String date) {
    final days = daysLeft(p, date);
    return days == 0 ? 0 : max(0, budgetFree(p)) ~/ days;
  }

  int dailySpent(Plan p, String date) => periodEntries(
    p,
  ).where((e) => e.date == date).fold(0, (n, e) => n + e.expense);
  void enableDaily(Plan p) {
    if (p.dailyOriginal != null) return;
    final reservedTotal = p.reservations
        .where((r) => r.inBudget)
        .fold(0, (n, r) => n + r.amount);
    if (reservedTotal + fixedReserved(p) > budgetLimit(p) + incomeAdded(p))
      throw StateError('预算内预留合计超过总预算，请先调整');
    p.dailyOriginal =
        max(
          0,
          budgetLimit(p) + incomeAdded(p) - reservedTotal - fixedReserved(p),
        ) ~/
        calendarDays(p.start, p.end);
    p.history.add(
      '${DateTime.now().toIso8601String()} 启用每日规划：总预算 ${money(p.budget)}，预算内预留 ${money(reservedTotal)}，初始日均 ${money(p.dailyOriginal!)}；周期 ${p.start}—${p.end}',
    );
  }

  bool containsToday(Plan p) =>
      p.start.compareTo(today()) <= 0 && p.end.compareTo(today()) >= 0;
  Map<String, bool> breaches() {
    final result = <String, bool>{};
    for (final p in plans.where(
      (p) => containsToday(p) && p.status == 'active',
    )) {
      result['${p.id}:总预算'] = budgetSpent(p) > budgetLimit(p) + incomeAdded(p);
      result['${p.id}:资产底线'] = assets < p.assetFloor;
      result['${p.id}:可用余额底线'] = cash < p.cashFloor;
      for (final c in p.categoryLimits.entries) {
        result['${p.id}:分类 ${c.key}'] = spent(p, c.key) > c.value;
      }
    }
    return result;
  }

  void record({
    required String kind,
    required String date,
    String note = '',
    String category = '',
    Map<String, int> cash = const {},
    Map<String, int> claimChanges = const {},
    int expense = 0,
    int income = 0,
    String image = '',
    Map<String, int> holdingChanges = const {},
    String fixedId = '',
    String fixedMonth = '',
  }) {
    if (date.compareTo(today()) > 0) throw StateError('未来资金请记为待到账款');
    for (final item in cash.entries) {
      if (!wallets.any((w) => w.id == item.key)) throw StateError('账户不存在');
      // The account can temporarily consume held money, so personal
      // available may go negative. The physical account balance itself still
      // cannot go below zero.
      if (walletBalance(item.key) + item.value < 0)
        throw StateError('账户实存余额不足');
    }
    for (final item in claimChanges.entries) {
      if (!claims.any((c) => c.id == item.key)) throw StateError('应收款不存在');
      if (claimBalance(item.key) + item.value < 0)
        throw StateError('超过该笔未到账金额');
    }
    for (final h in holdingChanges.entries) {
      if (!custodies.any((c) => c.id == h.key) ||
          heldBalance(h.key) + h.value < 0)
        throw StateError('超过代管余额');
    }
    entries.add(
      Entry(
        id: newId(),
        date: date,
        kind: kind,
        note: note,
        category: category,
        cash: Map.of(cash),
        claims: Map.of(claimChanges),
        expense: expense,
        income: income,
        image: image,
        holdings: Map.of(holdingChanges),
        fixedId: fixedId,
        fixedMonth: fixedMonth,
      ),
    );
  }

  void addWallet(String name, int balance) {
    if (name.trim().isEmpty) throw StateError('请输入账户名称');
    final w = Wallet(newId(), name.trim());
    wallets.add(w);
    record(kind: '期初余额', date: today(), cash: {w.id: balance}, note: w.name);
  }

  void receiveIncome({
    required String wallet,
    required int amount,
    required String date,
    required String category,
    String note = '',
    String image = '',
    String planId = '',
  }) {
    if (amount <= 0) throw StateError('收入金额需要大于零');
    final target = planId.isEmpty
        ? null
        : plans.where((p) => p.id == planId).firstOrNull;
    if (planId.isNotEmpty &&
        (target == null ||
            target.status != 'active' ||
            date.compareTo(target.start) < 0 ||
            date.compareTo(target.end) > 0)) {
      throw StateError('收入日期不在当前执行计划内，请选择不加入计划或调整日期');
    }
    record(
      kind: '收入',
      date: date,
      category: category,
      note: note,
      cash: {wallet: amount},
      income: amount,
      image: image,
    );
    final entry = entries.last;
    entry.incomePlanId = target?.id ?? '';
    entry.incomePlanName = target?.name ?? '';
    entry.walletAfter = walletAvailable(wallet);
    entry.cashAfter = cash;
    entry.planAfter = target == null ? null : spendable(target);
  }

  void consume(
    String wallet,
    int amount,
    String category,
    String date,
    String note, {
    String image = '',
    bool countsForPlan = true,
    String custodyId = '',
    int custodyAmount = 0,
  }) {
    if (amount <= 0) throw StateError('金额需要大于零');
    if (custodyAmount < 0 || custodyAmount > amount)
      throw StateError('代管承担金额须在0与本笔付款金额之间');
    if (custodyAmount > 0) {
      final c = custodies.where((c) => c.id == custodyId).firstOrNull;
      if (c == null || c.walletId != wallet) throw StateError('请选择付款账户中的代管款');
      if (custodyAmount > heldBalance(custodyId))
        throw StateError('代管承担金额超过剩余代管余额');
    } else if (custodyId.isNotEmpty) {
      throw StateError('已选择代管款，请填写大于零的承担金额');
    }
    record(
      kind: '支出',
      date: date,
      cash: {wallet: -amount},
      expense: amount - custodyAmount,
      category: category,
      note: note,
      image: image,
      holdingChanges: custodyAmount > 0 ? {custodyId: -custodyAmount} : {},
    );
    entries.last.countsForPlan = countsForPlan;
    entries.last.custodyCovered = custodyAmount;
  }

  void transfer(String from, String to, int amount, String date, String note) {
    if (from == to) throw StateError('请选择两个不同账户');
    if (amount <= 0) throw StateError('金额需要大于零');
    if (walletAvailable(from) < amount) throw StateError('个人可用余额不足，不能转出');
    record(
      kind: '转账',
      date: date,
      cash: {from: -amount, to: amount},
      note: note,
    );
  }

  void receiveClaim(
    String claim,
    String wallet,
    int amount,
    String date,
    String note,
  ) {
    if (amount <= 0) throw StateError('金额需要大于零');
    record(
      kind: '到账 / 收回',
      date: date,
      cash: {wallet: amount},
      claimChanges: {claim: -amount},
      note: note,
    );
  }

  void receivePerson(
    String person,
    String wallet,
    int amount,
    String date,
    String note,
  ) {
    if (amount <= 0) throw StateError('金额需要大于零');
    final list = claims
        .where((c) => c.isLoan && c.person == person && claimBalance(c.id) > 0)
        .toList();
    final changes = <String, int>{};
    var left = amount;
    for (final c in list) {
      final taken = min(left, claimBalance(c.id));
      if (taken > 0) changes[c.id] = -taken;
      left -= taken;
    }
    if (left > 0) throw StateError('超过此人的待还总额');
    record(
      kind: '朋友还款',
      date: date,
      cash: {wallet: amount},
      claimChanges: changes,
      note: '$person · $note',
    );
  }

  void voidEntry(Entry e, String reason) {
    if (reason.trim().isEmpty) throw StateError('请填写作废原因');
    e.voided = true;
    if (wallets.any((w) => walletBalance(w.id) < 0) ||
        claims.any((c) => claimBalance(c.id) < 0) ||
        custodies.any((c) => heldBalance(c.id) < 0)) {
      e.voided = false;
      throw StateError('后续记录依赖这笔资金，请先处理后续记录');
    }
    audit.add('${DateTime.now().toIso8601String()} 作废 ${e.id}：$reason');
  }

  Map<String, dynamic> toJson() => {
    'schema': 4,
    'custodies': custodies.map((c) => c.toJson()).toList(),
    'fixedCosts': fixedCosts.map((f) => f.toJson()).toList(),
    'wallets': wallets.map((e) => e.toJson()).toList(),
    'claims': claims.map((e) => e.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
    'plans': plans.map((e) => e.toJson()).toList(),
    'categories': categories,
    'claimKinds': claimKinds,
    'selectedPlan': selectedPlan,
    'themeId': themeId,
    'notifications': notifications,
    'alertState': alertState,
    'audit': audit,
    'images': images,
  };
  factory Book.fromJson(Map<String, dynamic> j) {
    if (![1, 2, 3, 4].contains(j['schema']))
      throw const FormatException('备份版本不兼容');
    final b = Book()
      ..custodies = objects(j['custodies'] ?? []).map(Custody.fromJson).toList()
      ..fixedCosts = objects(
        j['fixedCosts'] ?? [],
      ).map(FixedCost.fromJson).toList()
      ..wallets = objects(j['wallets']).map(Wallet.fromJson).toList()
      ..claims = objects(j['claims']).map(Claim.fromJson).toList()
      ..entries = objects(j['entries']).map(Entry.fromJson).toList()
      ..plans = objects(j['plans']).map(Plan.fromJson).toList()
      ..categories = List<String>.from(j['categories'])
      ..claimKinds = List<String>.from(j['claimKinds'])
      ..selectedPlan = j['selectedPlan']
      ..themeId = j['themeId'] is String ? j['themeId'] as String : 'warm'
      ..notifications = j['notifications']
      ..alertState = Map<String, bool>.from(j['alertState'])
      ..audit = List<String>.from(j['audit'])
      ..images = Map<String, String>.from(j['images']);
    final ids = [
      ...b.wallets.map((w) => w.id),
      ...b.claims.map((c) => c.id),
      ...b.entries.map((e) => e.id),
      ...b.plans.map((p) => p.id),
      ...b.custodies.map((c) => c.id),
      ...b.fixedCosts.map((f) => f.id),
    ];
    if (ids.toSet().length != ids.length)
      throw const FormatException('备份存在重复标识');
    if (b.categories.toSet().length != b.categories.length ||
        b.claimKinds.toSet().length != b.claimKinds.length ||
        b.categories.any((c) => c.trim().isEmpty) ||
        b.claimKinds.any((c) => c.trim().isEmpty)) {
      throw const FormatException('备份分类无效');
    }
    if (b.selectedPlan.isNotEmpty &&
        !b.plans.any((p) => p.id == b.selectedPlan)) {
      throw const FormatException('所选计划不存在');
    }
    for (final p in b.plans) {
      if (DateTime.tryParse(p.start) == null ||
          DateTime.tryParse(p.end) == null ||
          p.end.compareTo(p.start) < 0 ||
          p.budget < 0 ||
          (p.dailyOriginal != null && p.dailyOriginal! < 0) ||
          p.assetFloor < 0 ||
          p.cashFloor < 0 ||
          p.savings < 0 ||
          p.reservations.any((r) => r.amount < 0) ||
          p.categoryLimits.values.any((v) => v < 0) ||
          p.reservations.map((r) => r.category).toSet().length !=
              p.reservations.length ||
          [
            'budget',
            'assetFloor',
            'cashFloor',
            'savings',
          ].any((key) => p.original[key] is! int)) {
        throw const FormatException('备份计划无效');
      }
    }
    for (final e in b.entries) {
      if (e.holdings.keys.any((id) => !b.custodies.any((c) => c.id == id)) ||
          (e.fixedId.isNotEmpty &&
              (!b.fixedCosts.any((f) => f.id == e.fixedId) ||
                  !RegExp(r'^\d{4}-\d{2}$').hasMatch(e.fixedMonth))) ||
          DateTime.tryParse(e.date) == null ||
          e.expense < 0 ||
          e.income < 0 ||
          e.cash.keys.any((id) => !b.wallets.any((w) => w.id == id)) ||
          e.claims.keys.any((id) => !b.claims.any((c) => c.id == id)) ||
          (e.image.isNotEmpty && !b.images.containsKey(e.image))) {
        throw const FormatException('备份流水无效');
      }
    }
    // A wallet may be temporarily negative when its remaining balance is
    // held money used as an advance. This debt is replenished later.
    if (b.wallets.any((w) => b.walletBalance(w.id) < 0) ||
        b.claims.any((c) => b.claimBalance(c.id) < 0))
      throw const FormatException('备份应收余额无效');
    if (b.categories.any(
      (c) =>
          c.split('/').length > 3 ||
          c.split('/').any((part) => part.trim().isEmpty),
    ))
      throw const FormatException('分类路径无效');
    b.validateExtensions();
    return b;
  }
}
