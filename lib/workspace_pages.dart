part of 'main.dart';

const statusNames = {
  'active': '正在执行',
  'next': '下一个执行',
  'draft': '计划中',
  'done': '已完成',
};
const termNames = {
  'short': '短期 · 默认7天',
  'medium': '中期 · 默认30天',
  'long': '长期 · 默认3个月',
};

class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({super.key, required this.host, required this.id});
  final _LedgerAppState host;
  final String id;
  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  @override
  Widget build(BuildContext context) {
    final h = widget.host;
    if (!h.book!.plans.any((p) => p.id == widget.id))
      return Scaffold(
        appBar: AppBar(title: Text('计划已删除')),
        body: Center(child: Text('资金流水已保留')),
      );
    h.workspacePlanId = widget.id;
    return ValueListenableBuilder<int>(
      valueListenable: h.updates,
      builder: (context, _, child) {
        if (!h.book!.plans.any((p) => p.id == widget.id))
          return Scaffold(
            appBar: AppBar(title: Text('计划已删除')),
            body: Center(child: Text('资金流水已保留')),
          );
        return Scaffold(
          appBar: AppBar(
            title: Text(
              h.book!.plans.firstWhere((p) => p.id == widget.id).name,
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: h.legacyPlans(),
            ),
          ),
        );
      },
    );
  }
}

class PersonalStatsPage extends StatefulWidget {
  const PersonalStatsPage({super.key, required this.host});
  final _LedgerAppState host;
  @override
  State<PersonalStatsPage> createState() => _PersonalStatsPageState();
}

class _PersonalStatsPageState extends State<PersonalStatsPage> {
  int year = DateTime.now().year, month = DateTime.now().month, monthlyPage = 0;
  @override
  Widget build(BuildContext context) {
    final h = widget.host, b = h.book!;
    final entries = b.active
        .where((e) => h.periodMatch(e.date, year, month))
        .toList();
    final expense = entries.fold(0, (n, e) => n + e.expense),
        income = entries.fold(0, (n, e) => n + e.income);
    final spending = entries.where((e) => e.expense > 0).toList();
    final groups = <String, int>{};
    for (final e in spending) {
      final c = e.category.split('/').first;
      groups[c] = (groups[c] ?? 0) + e.expense;
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final previous = month == 0
        ? DateTime(year - 1)
        : DateTime(year, month - 1);
    final previousSpent = b.active
        .where(
          (e) => h.periodMatch(
            e.date,
            previous.year,
            month == 0 ? 0 : previous.month,
          ),
        )
        .fold(0, (n, e) => n + e.expense);
    final lastDay = month == 0
        ? DateTime(year + 1).difference(DateTime(year)).inDays
        : DateTime(year, month + 1, 0).day;
    final elapsed =
        year == DateTime.now().year &&
            (month == 0 || month == DateTime.now().month)
        ? (month == 0
              ? DateTime.now().difference(DateTime(year)).inDays + 1
              : DateTime.now().day)
        : lastDay;
    return Scaffold(
      appBar: AppBar(title: Text('个人统计')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            h.periodBar(
              year,
              month,
              (y, m) => setState(() {
                year = y;
                month = m;
                monthlyPage = 0;
              }),
            ),
            SheetCard(
              child: Column(
                children: [
                  h.heading('收支一览'),
                  h.line('总支出 · 实际消费', money(expense)),
                  h.line('收入', money(income)),
                  h.line('净支出 · 支出减收入', money(expense - income)),
                  h.details('更多统计', [
                    h.line('结余 · 收入减支出', money(income - expense)),
                    h.line('日均消费', money(expense ~/ max(1, elapsed))),
                    h.line('消费笔数', '${spending.length} 笔'),
                    h.line(
                      '最大单笔',
                      money(spending.fold(0, (n, e) => max(n, e.expense))),
                    ),
                    h.line(
                      month == 0 ? '较上年支出变化' : '较上月支出变化',
                      previousSpent == 0
                          ? '上期无消费'
                          : '${((expense - previousSpent) / previousSpent * 100).toStringAsFixed(1)}%',
                    ),
                  ]),
                  h.details('统计口径', [
                    h.note('按自然日统计，与计划个数无关；转账、借还、代管和作废不计入消费或普通收入。净支出允许为负。'),
                  ]),
                ],
              ),
            ),
            SheetCard(
              child: Column(
                children: [
                  h.heading('消费去向'),
                  if (sorted.isEmpty) h.note('该周期暂无消费'),
                  for (final item in sorted.take(5))
                    h.line(
                      item.key.isEmpty ? '其他' : item.key,
                      '${money(item.value)} · ${(item.value / max(1, expense) * 100).toStringAsFixed(0)}%',
                    ),
                  if (sorted.length > 5)
                    h.details('其他分类', [
                      for (final item in sorted.skip(5))
                        h.line(item.key, money(item.value)),
                    ]),
                ],
              ),
            ),
            h.heading('$year年逐月报表'),
            for (final m in List.generate(
              12,
              (i) => i + 1,
            ).skip(monthlyPage * 3).take(3))
              Builder(
                builder: (_) {
                  final rows = b.active.where(
                    (e) => h.periodMatch(e.date, year, m),
                  );
                  final out = rows.fold(0, (n, e) => n + e.expense),
                      inc = rows.fold(0, (n, e) => n + e.income);
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    title: Text('$m月 · 支出 ${money(out)}'),
                    subtitle: Text(
                      '收入 ${money(inc)}  /  净支出 ${money(out - inc)}',
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => setState(() => month = m),
                  );
                },
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一组月份',
                  onPressed: monthlyPage > 0
                      ? () => setState(() => monthlyPage--)
                      : null,
                  icon: Icon(Icons.chevron_left),
                ),
                Text('第 ${monthlyPage + 1} / 4 页'),
                IconButton(
                  tooltip: '下一组月份',
                  onPressed: monthlyPage < 3
                      ? () => setState(() => monthlyPage++)
                      : null,
                  icon: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FixedCostsPage extends StatefulWidget {
  const FixedCostsPage({super.key, required this.host});
  final _LedgerAppState host;
  @override
  State<FixedCostsPage> createState() => _FixedCostsPageState();
}

class _FixedCostsPageState extends State<FixedCostsPage> {
  int year = DateTime.now().year, month = DateTime.now().month, index = 0;
  @override
  Widget build(BuildContext context) {
    final h = widget.host,
        b = h.book!,
        key = '$year-${month.toString().padLeft(2, '0')}';
    final items = b.fixedCosts.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('每月固定开支'),
        actions: [
          IconButton(
            tooltip: '添加固定开支',
            onPressed: () async {
              await h.fixedEditor();
              if (mounted) setState(() {});
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            h.periodBar(
              year,
              month,
              (y, m) => setState(() {
                year = y;
                month = m;
              }),
              allowYear: false,
            ),
            h.line(
              '本月待支付',
              money(
                items
                    .where((f) => f.applies(key))
                    .fold(0, (n, f) => n + b.fixedRemaining(f, key)),
              ),
            ),
            h.note('仅展示预算义务；确认支付后才进入流水，不会后台自动扣款。'),
            for (final f in h.pageItems(items, index))
              SheetCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    h.heading(
                      f.name,
                      IconButton(
                        tooltip: '修改固定开支',
                        onPressed: () async {
                          await h.fixedEditor(f);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    h.line('每月', money(f.amount)),
                    h.note('${f.dueDay}日 · ${f.category}'),
                    h.note(
                      f.planId.isEmpty
                          ? '未归属计划'
                          : '归属 ${b.plans.firstWhere((p) => p.id == f.planId).name}',
                    ),
                    h.line('本月已支付', money(b.fixedPaid(f, key))),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed:
                              f.applies(key) && b.fixedRemaining(f, key) > 0
                              ? () async {
                                  await h.payFixedEditor(f, key);
                                  if (mounted) setState(() {});
                                }
                              : null,
                          child: Text(
                            !f.applies(key)
                                ? '本月不适用'
                                : b.fixedRemaining(f, key) == 0
                                ? '已支付'
                                : '确认支付',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await h.change((b) {
                              final item = b.fixedCosts.firstWhere(
                                (c) => c.id == f.id,
                              );
                              item.enabled = !item.enabled;
                            });
                            if (mounted) setState(() {});
                          },
                          child: Text(f.enabled ? '停用' : '启用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (items.isEmpty) h.note('添加房租、话费或每月订阅；可随时选择归属计划。'),
            h.pager(items.length, index, (v) => setState(() => index = v)),
          ],
        ),
      ),
    );
  }
}
