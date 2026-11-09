import 'package:flutter/material.dart';
import 'editor.dart';
import 'model.dart';

/// Dedicated expense route. Budget and custody choices are always rendered,
/// independent of the generic quick-entry sheet.
class ExpensePage extends StatefulWidget {
  const ExpensePage({
    super.key,
    required this.book,
    required this.save,
    this.initialCategory,
  });
  final Book book;
  final String? initialCategory;
  final Future<bool> Function(Map<String, String>) save;
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final share = TextEditingController(text: '0');
  final note = TextEditingController();
  late String wallet, category;
  String date = today(), custody = '';
  bool inPlan = true, photo = false, saving = false;
  String? error;
  Book get b => widget.book;
  List<Custody> get eligible => b.custodies
      .where((c) => c.walletId == wallet && b.heldBalance(c.id) > 0)
      .toList();
  @override
  void initState() {
    super.initState();
    wallet = b.wallets.firstWhere((w) => !w.archived).id;
    category = widget.initialCategory ?? b.categories.first;
    amount.addListener(refresh);
    share.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    amount.dispose();
    share.dispose();
    note.dispose();
    super.dispose();
  }

  int value(TextEditingController c) {
    try {
      return cents(c.text);
    } catch (_) {
      return 0;
    }
  }

  String? validateAmount(String? s) {
    try {
      if (cents(s ?? '') <= 0) return '付款金额必须大于0';
    } catch (_) {
      return '请输入有效金额，最多两位小数';
    }
    return null;
  }

  Future<void> submit() async {
    if (saving || !form.currentState!.validate()) return;
    final total = value(amount), covered = custody.isEmpty ? 0 : value(share);
    if (covered > total ||
        (custody.isNotEmpty &&
            (covered <= 0 || covered > b.heldBalance(custody)))) {
      setState(() => error = '代管承担须大于0，且不能超过付款金额或剩余代管余额');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.save({
      'amount': amount.text,
      'category': category,
      'wallet': wallet,
      'date': date,
      'note': note.text,
      'photo': '$photo',
      'countsForPlan': inPlan ? 'yes' : 'no',
      'custody': custody,
      'custodyAmount': number(covered),
    });
    if (!mounted) return;
    if (ok)
      Navigator.pop(context);
    else
      setState(() {
        saving = false;
        error = '尚未保存，请检查账户实存、代管金额或图片权限后重试。';
      });
  }

  @override
  Widget build(BuildContext context) {
    final own = value(amount) - (custody.isEmpty ? 0 : value(share));
    final p = b.overviewPlan();
    final wallets = {
      for (final w in b.wallets.where((w) => !w.archived))
        w.id: '${w.name} · 实存 ${money(b.walletBalance(w.id))}',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('记支出 · 0.3.0')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '本笔支出如何承担',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('是否扣计划剩余额度'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('expense-plan-in'),
                  label: const Text('计入计划'),
                  selected: inPlan,
                  onSelected: saving
                      ? null
                      : (_) => setState(() => inPlan = true),
                ),
                ChoiceChip(
                  key: const ValueKey('expense-plan-out'),
                  label: const Text('计划外 · 不扣预算'),
                  selected: !inPlan,
                  onSelected: saving
                      ? null
                      : (_) => setState(() => inPlan = false),
                ),
              ],
            ),
            Text(
              p == null ? '当前无执行计划。计划外仍计个人月度支出。' : '当前：${p.name}。房租等额外开支可选计划外。',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('expense-total'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '实际付款金额 · 元'),
              validator: validateAmount,
            ),
            const SizedBox(height: 16),
            LedgerChoice(
              label: '付款账户',
              value: wallets[wallet]!,
              onTap: saving
                  ? null
                  : () async {
                      final v = await selectLedgerOption(
                        context,
                        '付款账户',
                        wallets,
                        selected: wallet,
                      );
                      if (v != null && mounted)
                        setState(() {
                          wallet = v;
                          custody = '';
                          share.text = '0';
                        });
                    },
            ),
            const SizedBox(height: 16),
            const Text(
              '是否抵扣代管余额',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('本笔由代管款承担一部分'),
              subtitle: Text(
                eligible.isEmpty
                    ? '此账户暂无可抵扣代管款；可更换付款账户。'
                    : '临时借用、以后要补回则关闭；正式代付才抵扣。',
              ),
              value: custody.isNotEmpty,
              onChanged: saving || eligible.isEmpty
                  ? null
                  : (v) => setState(() {
                      custody = v ? eligible.first.id : '';
                      share.text = '0';
                    }),
            ),
            if (custody.isNotEmpty) ...[
              LedgerChoice(
                label: '抵扣哪笔代管款',
                value:
                    '${eligible.firstWhere((c) => c.id == custody).owner} · 剩余 ${money(b.heldBalance(custody))}',
                onTap: saving
                    ? null
                    : () async {
                        final v = await selectLedgerOption(context, '抵扣哪笔代管款', {
                          for (final c in eligible)
                            c.id: '${c.owner} · ${money(b.heldBalance(c.id))}',
                        }, selected: custody);
                        if (v != null && mounted) setState(() => custody = v);
                      },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const ValueKey('expense-custody-amount'),
              controller: share,
              enabled: custody.isNotEmpty && !saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '代管承担金额 · 元',
                helperText: '关闭抵扣时为0，代管余额不减少',
              ),
              validator: (s) {
                if (custody.isEmpty) return null;
                try {
                  cents(s ?? '');
                } catch (_) {
                  return '请输入有效的代管承担金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              '个人承担 ${money(own)} · 计划扣款 ${money(inPlan ? own : 0)}',
              key: const ValueKey('expense-preview'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('计划外不扣预算；付款仍减少实际资金，资金不足会限制可花金额。'),
            const SizedBox(height: 20),
            LedgerChoice(
              label: '分类',
              value: category,
              onTap: saving
                  ? null
                  : () async {
                      final v = await selectLedgerOption(
                        context,
                        '分类',
                        {for (final c in b.categories) c: c},
                        selected: category,
                        categories: true,
                      );
                      if (v != null && mounted) setState(() => category = v);
                    },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日期'),
              subtitle: Text(date),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: saving
                  ? null
                  : () async {
                      final v = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(date),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (v != null && mounted) setState(() => date = day(v));
                    },
            ),
            TextFormField(
              controller: note,
              maxLength: 300,
              decoration: const InputDecoration(labelText: '备注（选填）'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('附加图片'),
              value: photo,
              onChanged: saving ? null : (v) => setState(() => photo = v),
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const ValueKey('expense-save'),
            onPressed: saving ? null : submit,
            child: Text(saving ? '正在保存…' : '保存支出'),
          ),
        ),
      ),
    );
  }
}
