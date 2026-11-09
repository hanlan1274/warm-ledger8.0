import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';

import 'model.dart';
import 'storage.dart';
import 'visuals.dart';
import 'themes.dart';
import 'editor.dart';
import 'theme_picker.dart';
import 'category_catalog.dart';
import 'expense_page.dart';
part 'workspace_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WarmLedger());
}

class WarmLedger extends StatefulWidget {
  WarmLedger({super.key});
  @override
  State<WarmLedger> createState() => _WarmLedgerState();
}

class _WarmLedgerState extends State<WarmLedger> {
  String themeId = 'warm';
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '暖账',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: LedgerTheme.resolve(themeId).data,
    home: LedgerApp(
      onThemeChanged: (id) {
        if (id != themeId) setState(() => themeId = id);
      },
    ),
  );
}

class LedgerApp extends StatefulWidget {
  LedgerApp({super.key, required this.onThemeChanged, this.storage});
  final ValueChanged<String> onThemeChanged;
  final Storage? storage;
  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  LedgerTheme get palette => LedgerTheme.of(context);
  Color get cream => palette.background;
  Color get paper => palette.surface;
  Color get ink => palette.text;
  Color get muted => palette.secondary;
  Color get sage => palette.accent;
  Color get peach => palette.orange;
  Color get lavender => palette.purple;
  Color get sand => palette.gold;
  late final storage = widget.storage ?? Storage();
  final alerts = Alerts();
  final updates = ValueNotifier<int>(0);
  Book? book;
  String? failure;
  bool busy = false;
  int page = 0;
  String query = '', filterDate = '';
  String ledgerType = '全部',
      accountTab = '账户',
      planStatus = '全部',
      planTerm = '全部';
  int ledgerPage = 0, accountPage = 0, planPage = 0;
  int accountYear = DateTime.now().year, accountMonth = DateTime.now().month;
  int ledgerYear = DateTime.now().year, ledgerMonth = DateTime.now().month;
  int planYear = DateTime.now().year, planMonth = DateTime.now().month;
  int chartYear = DateTime.now().year, chartMonth = DateTime.now().month;
  String chartScale = '月', chartKind = '柱状';
  Timer? dateTimer;
  String displayedDate = today();
  @override
  void initState() {
    super.initState();
    load();
    dateTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted && displayedDate != today())
        setState(() => displayedDate = today());
    });
  }

  @override
  void dispose() {
    dateTimer?.cancel();
    updates.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = await storage.open();
      if (!mounted) return;
      setState(() {
        book = value;
        failure = null;
      });
      widget.onThemeChanged(value.themeId);
      try {
        await alerts.initialize();
      } catch (_) {
        /* Ledger works without notifications. */
      }
    } catch (e) {
      if (mounted) setState(() => failure = '账本未能读取，原数据没有被覆盖。\n$e');
    }
  }

  void tell(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> change(void Function(Book) action) async {
    if (busy || book == null) return false;
    setState(() => busy = true);
    try {
      final next = Book.fromJson(book!.toJson());
      action(next);
      next.validateExtensions();
      final states = next.breaches();
      final newly = states.entries
          .where((e) => e.value && !(next.alertState[e.key] ?? false))
          .map((e) {
            final parts = e.key.split(':');
            final name = next.plans.firstWhere((p) => p.id == parts.first).name;
            return '$name · ${parts.skip(1).join(':')}';
          })
          .toList();
      next.alertState = states;
      await storage.save(next);
      if (!mounted) return true;
      setState(() => book = next);
      updates.value++;
      widget.onThemeChanged(next.themeId);
      if (newly.isNotEmpty) {
        tell('已突破：${newly.join('、')}');
        if (next.notifications) {
          try {
            await alerts.show(newly);
          } catch (_) {
            tell('记录已保存；系统通知未发出，请检查通知权限');
          }
        }
      }
      return true;
    } catch (e) {
      tell(
        e
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', ''),
      );
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确定'),
            ),
          ],
        ),
      ) ??
      false;

  Future<Map<String, String>?> edit(
    String title,
    List<Field> fields, {
    String hint = '',
    String submit = '保存',
  }) => showLedgerEditor(
    context,
    title,
    fields,
    hint: hint,
    submit: submit,
    quick: title.startsWith('记一笔'),
  );
  Map<String, String> get walletOptions => {
    for (final w in book!.wallets.where((w) => !w.archived))
      w.id: '${w.name} · ${money(book!.walletAvailable(w.id))}',
  };
  Map<String, String> get categoryOptions => {
    for (final c in book!.categories) c: c,
  };
  Widget heading(String title, [Widget? action]) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (action != null) action,
      ],
    ),
  );
  Widget line(String label, String value, {Color? color}) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color ?? muted, fontSize: 13),
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: palette.amountStyle(15, color: color ?? ink),
          ),
        ),
      ],
    ),
  );
  Widget metric(String label, String value, {Color? color}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: color ?? muted, fontSize: 12)),
      SizedBox(height: 8),
      FittedBox(
        child: Text(value, style: palette.amountStyle(22, color: color ?? ink)),
      ),
    ],
  );
  Widget note(String text) => Padding(
    padding: EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: muted, height: 1.5),
    ),
  );
  Widget details(String title, List<Widget> children) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.only(bottom: 12),
    shape: Border(),
    collapsedShape: Border(),
    title: Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    children: children,
  );
  Widget empty(
    String title,
    String message,
    String button,
    VoidCallback action,
  ) => SheetCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: sage),
        ),
        SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(message, style: TextStyle(color: muted, fontSize: 14)),
        SizedBox(height: 24),
        FilledButton.icon(
          onPressed: action,
          icon: Icon(Icons.add, size: 20),
          label: Text(button),
        ),
      ],
    ),
  );
  Widget balanceTile(
    String title,
    String subtitle,
    String amount,
    IconData icon,
    VoidCallback action, {
    Color? amountColor,
  }) => SheetCard(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final compact =
                  box.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              final text = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  if (compact)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        amount,
                        style: palette.amountStyle(20, color: amountColor),
                      ),
                    ),
                ],
              );
              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(icon, color: sage, size: 22),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(child: text),
                  if (!compact) ...[
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        amount,
                        textAlign: TextAlign.end,
                        style: palette.amountStyle(19, color: amountColor),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (book == null)
      return Scaffold(
        appBar: AppBar(title: Text('暖账')),
        body: Center(
          child: failure == null
              ? CircularProgressIndicator()
              : Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(failure!),
                      SizedBox(height: 16),
                      FilledButton(onPressed: load, child: Text('重试读取')),
                    ],
                  ),
                ),
        ),
      );
    final title = ['资金总览', '账户', '记一笔', '计划', '账本'][page];
    final date = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: max(
          84.0,
          MediaQuery.textScalerOf(context).scale(12) * 1.5 +
              MediaQuery.textScalerOf(context).scale(26) * 1.4 +
              20,
        ),
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: personalPage,
            tooltip: '个人统计',
            icon: Icon(Icons.person_outline),
          ),
          IconButton.filledTonal(
            onPressed: settings,
            tooltip: '设置与备份',
            style: IconButton.styleFrom(backgroundColor: palette.soft),
            icon: Icon(Icons.tune_outlined, size: 22),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 640),
                  child: ListView(
                    key: ValueKey(page),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (page == 0) ...home(),
                      if (page == 1) ...accounts(),
                      if (page == 2) ...entryPage(),
                      if (page == 3) ...plans(),
                      if (page == 4) ...ledger(),
                    ],
                  ),
                ),
              ),
            ),
            if (busy)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.divider)),
        ),
        child: NavigationBar(
          selectedIndex: page,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Duration(milliseconds: 180),
          onDestinationSelected: (v) {
            if (!busy) setState(() => page = v);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: '总览',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: '账户',
            ),
            NavigationDestination(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sage,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add, color: palette.onAccent),
              ),
              label: '记账',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: '计划',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: '账本',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> home() => compactHome();
  List<Widget> accounts() => compactAccounts();

  Future<void> walletEditor([Wallet? wallet]) async {
    final data = await edit(wallet == null ? '添加账户' : '修改账户名称', [
      Field('name', '账户名称', value: wallet?.name ?? ''),
      if (wallet == null) Field('balance', '当前余额', amount: true, value: '0'),
    ]);
    if (data == null) return;
    await change((b) {
      if (wallet == null)
        b.addWallet(data['name']!, cents(data['balance']!));
      else {
        final w = b.wallets.firstWhere((w) => w.id == wallet.id);
        b.audit.add('${today()} 账户更名：${w.name} → ${data['name']}');
        w.name = data['name']!;
      }
    });
  }

  Future<void> walletActions(Wallet wallet) async {
    final index = book!.wallets.indexWhere((w) => w.id == wallet.id);
    final action = await choose(wallet.name, {
      'rename': '修改名称',
      'check': '核对余额与流水',
      if (index > 0) 'up': '排序：上移一位',
      if (index < book!.wallets.length - 1) 'down': '排序：下移一位',
      'archive': wallet.archived ? '恢复使用' : '归档（保留历史和余额）',
    });
    if (action == 'rename') await walletEditor(wallet);
    if (action == 'archive')
      await change((b) {
        final w = b.wallets.firstWhere((w) => w.id == wallet.id);
        w.archived = !w.archived;
      });
    if (action == 'check') await reconcile(wallet);
    if (action == 'up' || action == 'down')
      await change((b) {
        final old = b.wallets.indexWhere((w) => w.id == wallet.id);
        final item = b.wallets.removeAt(old);
        b.wallets.insert(old + (action == 'up' ? -1 : 1), item);
      });
  }

  Future<void> reconcile(Wallet wallet) async {
    final b = book!;
    final last = b.entries
        .where(
          (e) => !e.voided && e.kind == '余额核对' && e.cash.containsKey(wallet.id),
        )
        .lastOrNull;
    final recent = b.active
        .where(
          (e) =>
              e.cash.containsKey(wallet.id) &&
              (last == null || e.date.compareTo(last.date) >= 0),
        )
        .toList()
        .reversed
        .take(12);
    final data = await edit(
      '核对余额',
      [
        Field(
          'balance',
          '手机里实际余额',
          value: number(b.walletBalance(wallet.id)),
          amount: true,
        ),
        Field('expense', '短少金额计入消费', toggle: true),
        Field('reason', '核对说明', value: '定期核对'),
      ],
      hint:
          '上次核对：${last?.date ?? '尚未核对'}。以下列出最近12笔；完整记录可在账本搜索账户名。\n${recent.map((e) => '${e.date} ${e.kind} ${money(e.cash[wallet.id]!)} ${e.note}').join('\n')}',
    );
    if (data == null) return;
    final difference = cents(data['balance']!) - b.walletBalance(wallet.id);
    if (!await confirm('余额差额 ${money(difference)}', '会保留核对前后金额和原因，不覆盖历史流水。'))
      return;
    await change(
      (b) => b.record(
        kind: '余额核对',
        date: today(),
        cash: {wallet.id: difference},
        expense: difference < 0 && data['expense'] == 'true' ? -difference : 0,
        category: '余额差额',
        note:
            '${wallet.name} ${money(b.walletBalance(wallet.id))} → ${data['balance']}；${data['reason']}',
      ),
    );
  }

  Future<String?> choose(String title, Map<String, String> options) =>
      selectLedgerOption(context, title, options);

  Widget entryAction(
    String label,
    String detail,
    IconData icon,
    Color color,
    VoidCallback action, {
    bool primary = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Material(
      color: primary ? sage : paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: busy ? null : action,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary
                      ? palette.onAccent.withValues(alpha: .12)
                      : color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: primary ? palette.onAccent : color,
                  size: 26,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primary ? palette.onAccent : ink,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 12,
                          color: primary ? palette.onAccent : muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: primary ? palette.onAccent : muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  List<Widget> entryPage() => [
    entryAction(
      '支出',
      '计划内 / 计划外 · 代管款分摊',
      Icons.north_east,
      sage,
      () => entry('支出'),
      primary: true,
    ),
    entryAction('收入', '', Icons.south_west, peach, () => entry('收入')),
    entryAction('转账', '账户之间', Icons.swap_horiz, lavender, () => entry('转账')),
    SizedBox(height: 16),
    heading('应收款'),
    entryAction(
      '新增应收',
      '借出 / 押金 / 待到账',
      Icons.handshake_outlined,
      sage,
      claimCreate,
    ),
    entryAction(
      '记录到账',
      '',
      Icons.move_to_inbox_outlined,
      peach,
      () => setState(() => page = 1),
    ),
  ];
  Future<void> entry(String kind, {String? category}) async {
    if (walletOptions.isEmpty) {
      tell('请先添加或恢复一个账户');
      return;
    }
    if (kind == '转账' && walletOptions.length < 2) {
      tell('转账需要至少两个使用中的账户');
      return;
    }
    if (categoryOptions.isEmpty && kind != '转账') {
      tell('请先在设置里添加分类');
      return;
    }
    if (kind == '支出') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpensePage(
            book: book!,
            initialCategory: category,
            save: (data) => saveEntry('支出', data),
          ),
        ),
      );
      return;
    }
    final incomePlan = kind == '收入' ? book!.overviewPlan() : null;
    final d = await edit(
      '记一笔$kind',
      [
        Field('amount', '金额 · 元', amount: true),
        if (kind != '转账')
          Field(
            'category',
            '分类',
            options: categoryOptions,
            value: category ?? '',
          ),
        Field('wallet', kind == '收入' ? '到账账户' : '付款账户', options: walletOptions),
        if (kind == '收入')
          Field(
            'incomePlan',
            '是否加入当前计划可花额度',
            value: '',
            options: {
              '': '不加入 · 只增加账户余额',
              if (incomePlan != null)
                incomePlan.id: '加入 ${incomePlan.name} 的可花额度',
            },
          ),
        if (kind == '转账')
          Field(
            'to',
            '转入账户',
            options: walletOptions,
            value: walletOptions.keys.elementAt(1),
          ),
        Field('date', '日期', value: today(), date: true),
        Field('note', '备注', optional: true),
        Field('photo', '附加图片', toggle: true),
      ],
      submit: '保存$kind',
      hint: kind == '收入'
          ? (incomePlan == null
                ? '当前没有执行中的计划，本笔收入只增加账户余额。'
                : '选择加入时，计划消费额度增加本笔收入；不加入时只增加资金余额。可花金额仍受预算、预留和可用资金共同限制。')
          : kind == '支出'
          ? '计划外支出不扣零花钱预算，个人消费仍统计；资金不足时还可花金额仍受实际资金限制。代管承担金额不计个人消费，须选付款账户中的代管款；暂借后要补回则不抵扣。'
          : '',
    );
    if (d == null) return;
    await saveEntry(kind, d);
  }

  Future<bool> saveEntry(String kind, Map<String, String> d) async {
    String image = '', imageData = '';
    if (d['photo'] == 'true') {
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1600,
          imageQuality: 65,
        );
        if (file != null) {
          final bytes = await file.readAsBytes();
          if (bytes.length > 2 * 1024 * 1024) {
            tell('图片超过2MB，请选择更小的图片');
            return false;
          }
          image = newId();
          imageData = base64Encode(bytes);
        }
      } catch (_) {
        tell('无法读取所选图片，这笔记录尚未保存');
        return false;
      }
    }
    final saved = await change((b) {
      final amount = cents(d['amount']!);
      if (amount <= 0) throw StateError('金额需要大于零');
      if (image.isNotEmpty) b.images[image] = imageData;
      if (kind == '支出')
        b.consume(
          d['wallet']!,
          amount,
          d['category']!,
          d['date']!,
          d['note']!,
          image: image,
          countsForPlan: d['countsForPlan'] != 'no',
          custodyId: d['custody'] ?? '',
          custodyAmount: cents(d['custodyAmount'] ?? '0'),
        );
      if (kind == '收入')
        b.receiveIncome(
          wallet: d['wallet']!,
          amount: amount,
          date: d['date']!,
          category: d['category']!,
          note: d['note']!,
          image: image,
          planId: d['incomePlan'] ?? '',
        );
      if (kind == '转账') {
        b.transfer(d['wallet']!, d['to']!, amount, d['date']!, d['note']!);
        b.entries.last.image = image;
      }
    });
    if (saved && mounted) {
      setState(() => page = 0);
      final p = book!.overviewPlan();
      tell(
        kind == '收入'
            ? '收入已保存 · 账户可用 ${money(book!.walletAvailable(d['wallet']!))} · 个人可用 ${money(book!.cash)}${p == null ? '' : ' · 当前计划还可花 ${money(book!.spendable(p))}'}'
            : '已保存',
      );
    }
    return saved;
  }

  Future<void> claimCreate() async {
    final d = await edit('新增应收', [
      Field('amount', '金额', amount: true),
      Field('title', '名称'),
      Field(
        'kind',
        '类型',
        options: {
          for (final kind in book!.claimKinds) kind: kind,
          '__new__': '＋ 自定义新类型',
        },
      ),
      Field('newKind', '新类型名称（选自定义时填写）', optional: true),
      Field('loan', '按人管理借还款（朋友借款默认启用）', toggle: true),
      Field('person', '对方姓名 / 机构（朋友借款必填）', optional: true),
      Field(
        'mode',
        '资金来源',
        options: {
          'existing': '已有应收 / 确定的未来到账',
          if (walletOptions.isNotEmpty) 'pay': '现在从账户借出 / 支付押金',
        },
      ),
      if (walletOptions.isNotEmpty)
        Field('wallet', '支付账户（仅现在支付时使用）', options: walletOptions),
      Field('due', '预计到账日（可不填）', optional: true, date: true),
      Field('note', '备注', optional: true),
    ], hint: '已有应收会增加登记的总资产；现在支付则把账户余额转为应收，总资产不变。');
    if (d == null) return;
    await change((b) {
      final amount = cents(d['amount']!);
      if (amount <= 0) throw StateError('金额需要大于零');
      final isLoan = d['loan'] == 'true' || d['kind'] == '朋友借款';
      if (isLoan && d['person']!.isEmpty) throw StateError('按人管理的借款请填写对方姓名');
      final kind = d['kind'] == '__new__' ? d['newKind']! : d['kind']!;
      if (kind.isEmpty) throw StateError('请填写新类型名称');
      if (!b.claimKinds.contains(kind)) b.claimKinds.add(kind);
      final c = Claim(
        newId(),
        d['title']!,
        d['person']!,
        kind,
        d['due']!,
        isLoan: isLoan,
      );
      b.claims.add(c);
      b.record(
        kind: d['mode'] == 'pay' ? '借出 / 支付押金' : '登记应收',
        date: today(),
        cash: d['mode'] == 'pay' ? {d['wallet']!: -amount} : {},
        claimChanges: {c.id: amount},
        note: '${c.title} · ${d['note']}',
      );
    });
  }

  Future<void> claimActions(Claim c) async {
    final action = await choose(c.title, {
      'receive': '记录到账',
      'edit': '调整应收',
      'history': '变更记录',
    });
    if (action == 'receive') await claimReceive(claim: c);
    if (action == 'edit') await claimEditor(c);
    if (action == 'history') {
      final history = book!.entries
          .where((e) => e.claims.containsKey(c.id))
          .toList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(c.title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...history.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${e.date} · ${e.kind}${e.voided ? '（已作废）' : ''}',
                      ),
                      subtitle: Text(e.note),
                      trailing: Text(money(e.claims[c.id]!)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> claimReceive({Claim? claim, String? person}) async {
    if (walletOptions.isEmpty) {
      tell('请先添加一个到账账户');
      return;
    }
    final d = await edit(
      claim == null ? '$person 归还借款' : '${claim.title} 到账',
      [
        Field('amount', '本次到账金额', amount: true),
        Field('wallet', '到账账户', options: walletOptions),
        Field('date', '实际到账日', value: today(), date: true),
        Field('note', '备注', optional: true),
      ],
      hint: claim == null
          ? '默认抵扣最早登记的借款。若要手动指定，请返回并点开对应借款。'
          : '本次只抵扣这一笔；未到账部分继续保留。',
    );
    if (d == null) return;
    await change((b) {
      if (claim != null)
        b.receiveClaim(
          claim.id,
          d['wallet']!,
          cents(d['amount']!),
          d['date']!,
          d['note']!,
        );
      else
        b.receivePerson(
          person!,
          d['wallet']!,
          cents(d['amount']!),
          d['date']!,
          d['note']!,
        );
    });
  }

  Future<void> claimEditor(Claim claim) async {
    final old = book!.claimBalance(claim.id);
    final d = await edit('调整 ${claim.title}', [
      Field('title', '名称', value: claim.title),
      Field(
        'kind',
        '资金类型',
        options: {
          for (final kind in {...book!.claimKinds, claim.kind}) kind: kind,
        },
        value: claim.kind,
      ),
      Field('person', '对方 / 机构', value: claim.person, optional: true),
      Field('due', '预计到账日', value: claim.due, date: true, optional: true),
      Field('amount', '调整后仍待到账金额（取消填0）', amount: true, value: number(old)),
      Field('expense', '减少的金额计入消费（如押金扣损）', toggle: true),
      Field('reason', '调整原因'),
    ], hint: '实际收到的钱请用“记录到账”。这里修改的是尚未到账金额，不会增加账户余额。');
    if (d == null) return;
    await change((b) {
      final c = b.claims.firstWhere((c) => c.id == claim.id);
      final delta = cents(d['amount']!) - b.claimBalance(c.id);
      final previous = '${c.title} / ${c.kind} / ${c.person} / ${c.due}';
      if (c.isLoan && d['person']!.isEmpty) throw StateError('朋友借款请保留对方姓名');
      c.title = d['title']!;
      c.kind = d['kind']!;
      c.person = d['person']!;
      c.due = d['due']!;
      b.record(
        kind: '应收调整',
        date: today(),
        claimChanges: {c.id: delta},
        expense: delta < 0 && d['expense'] == 'true' ? -delta : 0,
        category: '应收扣损',
        note:
            '$previous → ${c.title} / ${c.kind} / ${c.person} / ${c.due}；${money(old)} → ${d['amount']}；${d['reason']}',
      );
    });
  }

  List<Widget> legacyPlans() {
    final b = book!;
    final p = b.plans.where((p) => p.id == detailPlanId).firstOrNull;
    if (p == null) return [note('计划已删除，流水保留')];
    return [
      Wrap(
        spacing: 8,
        children: [
          ActionChip(
            label: Text(statusNames[p.status]!),
            onPressed: () => planStateEditor(p),
          ),
          TextButton(onPressed: () => planEditor(p), child: Text('编辑计划')),
          TextButton(onPressed: () => deletePlanEditor(p), child: Text('删除计划')),
        ],
      ),
      Text('${p.start} — ${p.end}', style: TextStyle(color: muted)),
      SizedBox(height: 16),
      Text('还可花 ${money(b.spendable(p))}', style: palette.amountStyle(28)),
      line(
        '已花 / 当前额度',
        '${money(b.budgetSpent(p))} / ${money(b.budgetLimit(p))}',
      ),
      line('计划预算 / 已补回额度', '${money(p.budget)} / +${money(b.incomeAdded(p))}'),
      details('每日规划', [dailyCard(p)]),
      details('资金与预算明细', [
        line('个人可用', money(b.cash)),
        line('他人分摊补回', money(b.incomeAdded(p))),
        line('必要开支待预留', money(b.reserved(p))),
        line('固定开支待预留', money(b.fixedReserved(p))),
        line('储蓄预留', money(p.savings)),
        line('资金可支出', money(b.cashFree(p))),
        line('日常预算剩余', money(b.budgetFree(p))),
      ]),
      details('初始目标与当前底线', [
        line(
          '起点总资产 / 可用',
          '${money(p.openingAssets)} / ${money(p.openingCash)}',
        ),
        line(
          '原定 → 当前预算',
          '${money(p.original['budget'] as int)} → ${money(p.budget)}',
        ),
        line('当前资产底线', money(p.assetFloor)),
        line('当前可用底线', money(p.cashFloor)),
        line('资产距底线', money(b.assets - p.assetFloor)),
      ]),
      details('分类额度', [
        TextButton(onPressed: () => categoryBudget(p), child: Text('设置分类额度')),
        for (final c in p.categoryLimits.entries)
          line('${c.key} · 已花 ${money(b.spent(p, c.key))}', money(c.value)),
        TextButton(
          onPressed: p.categoryLimits.length < 2 ? null : () => shiftBudget(p),
          child: Text('分类挪额度'),
        ),
      ]),
      details('必要开支预留', [
        TextButton(onPressed: () => reserveEditor(p), child: Text('添加预留')),
        for (var i = 0; i < p.reservations.length; i++) reservationCard(p, i),
      ]),
      details('调整记录', [
        for (final item in p.history.reversed)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(item),
          ),
      ]),
      TextButton(onPressed: fixedPage, child: Text('管理每月固定开支')),
    ];
  }

  Future<void> planEditor([Plan? plan]) async {
    String term = plan?.term ?? 'medium';
    if (plan == null) {
      final chosen = await choose('计划周期', termNames);
      if (chosen == null) return;
      term = chosen;
    }
    final now = DateTime.now();
    final endDefault = term == 'short'
        ? day(now.add(Duration(days: 6)))
        : term == 'long'
        ? day(
            DateTime(
              now.year,
              now.month + 3,
              now.day,
            ).subtract(Duration(days: 1)),
          )
        : day(now.add(Duration(days: 29)));
    final d = await edit(
      plan == null ? '新建计划' : '调整计划',
      [
        Field('name', '计划名称', value: plan?.name ?? ''),
        Field('term', '周期类型', options: termNames, value: term),
        Field(
          'status',
          '计划状态',
          options: statusNames,
          value: plan?.status ?? 'active',
        ),
        Field('start', '开始日期', date: true, value: plan?.start ?? today()),
        Field('end', '结束日期', date: true, value: plan?.end ?? endDefault),
        Field(
          'budget',
          '消费总预算',
          amount: true,
          value: number(plan?.budget ?? 0),
        ),
        Field(
          'assetFloor',
          '结束时总资产底线',
          amount: true,
          value: number(plan?.assetFloor ?? 0),
        ),
        Field(
          'cashFloor',
          '结束时可用余额底线',
          amount: true,
          value: number(plan?.cashFloor ?? 0),
        ),
        Field(
          'savings',
          '储蓄预留',
          amount: true,
          value: number(plan?.savings ?? 0),
        ),
        if (plan == null)
          Field(
            'openingAssets',
            '起点总资产',
            amount: true,
            value: number(book!.assets),
          ),
        if (plan == null)
          Field(
            'openingCash',
            '起点可用余额',
            amount: true,
            value: number(book!.cash),
          ),
        if (plan != null) Field('reason', '调整原因'),
      ],
      hint:
          '底线用于提醒，储蓄预留用于计算可花额。起点默认填当前值，请按真实周期起点确认。全局显示覆盖今天且跨度最大的执行中计划。短7天、中30天、长3个月，日期可自行修改。',
    );
    if (d == null) return;
    if (d['end']!.compareTo(d['start']!) < 0) {
      tell('结束日期不能早于开始日期');
      return;
    }
    final budget = cents(d['budget']!),
        assetFloor = cents(d['assetFloor']!),
        cashFloor = cents(d['cashFloor']!),
        savings = cents(d['savings']!);
    if (plan != null &&
        !await confirm(
          '预览调整影响',
          '总预算：${money(plan.budget)} → ${money(budget)}\n'
              '资产底线：${money(plan.assetFloor)} → ${money(assetFloor)}\n'
              '可用底线：${money(plan.cashFloor)} → ${money(cashFloor)}\n'
              '储蓄预留：${money(plan.savings)} → ${money(savings)}\n'
              '当前总资产 ${money(book!.assets)}、可用 ${money(book!.cash)}。本次不会改变账户余额和原定目标。',
        ))
      return;
    await change((b) {
      if (plan == null) {
        final openingCash = cents(d['openingCash']!),
            openingAssets = cents(d['openingAssets']!);
        if (openingCash > openingAssets) throw StateError('起点可用余额不能大于起点总资产');
        final p = Plan(
          id: newId(),
          name: d['name']!,
          start: d['start']!,
          end: d['end']!,
          budget: budget,
          assetFloor: assetFloor,
          cashFloor: cashFloor,
          savings: savings,
          openingAssets: openingAssets,
          openingCash: openingCash,
          original: {
            'budget': budget,
            'assetFloor': assetFloor,
            'cashFloor': cashFloor,
            'savings': savings,
            'start': d['start'],
            'end': d['end'],
          },
          categoryLimits: {},
          reservations: [],
          history: ['${DateTime.now().toIso8601String()} 建立计划；起点快照固定'],
        );
        p.term = d['term']!;
        b.plans.add(p);
        b.transitionPlan(p.id, d['status']!);
        b.selectedPlan = p.id;
      } else {
        final p = b.plans.firstWhere((p) => p.id == plan.id);
        if (p.categoryLimits.values.fold(0, (n, v) => n + v) > budget)
          throw StateError('分类额度合计超过新总预算，请先调整分类额度');
        p.history.add(
          '${DateTime.now().toIso8601String()} ${p.name} → ${d['name']}；周期 ${p.start}—${p.end} → ${d['start']}—${d['end']}；'
          '预算 ${money(p.budget)} → ${money(budget)}；资产底线 ${money(p.assetFloor)} → ${money(assetFloor)}；'
          '可用底线 ${money(p.cashFloor)} → ${money(cashFloor)}；储蓄 ${money(p.savings)} → ${money(savings)}；原因：${d['reason']}',
        );
        p.name = d['name']!;
        p.start = d['start']!;
        p.end = d['end']!;
        p.budget = budget;
        p.assetFloor = assetFloor;
        p.cashFloor = cashFloor;
        p.savings = savings;
        p.term = d['term']!;
        b.transitionPlan(p.id, d['status']!);
      }
    });
  }

  Future<void> categoryBudget(Plan plan) async {
    if (categoryOptions.isEmpty) {
      tell('请先添加分类');
      return;
    }
    final d = await edit('设置分类额度', [
      Field('category', '分类', options: categoryOptions),
      Field('amount', '分类额度（0表示移除额度）', amount: true),
      Field('reason', '调整原因'),
    ]);
    if (d == null) return;
    await change((b) {
      final p = b.plans.firstWhere((p) => p.id == plan.id);
      final cat = d['category']!, amount = cents(d['amount']!);
      final previous = p.categoryLimits[cat] ?? 0;
      if (p.categoryLimits.values.fold(0, (a, b) => a + b) - previous + amount >
          p.budget)
        throw StateError('分类额度合计不能超过总预算');
      if (amount == 0) {
        p.categoryLimits.remove(cat);
      } else {
        p.categoryLimits[cat] = amount;
      }
      p.history.add(
        '${DateTime.now().toIso8601String()} $cat 额度 ${money(previous)} → ${money(amount)}；${d['reason']}',
      );
    });
  }

  Future<void> shiftBudget(Plan plan) async {
    final options = {
      for (final c in plan.categoryLimits.entries)
        c.key: '${c.key} · ${money(c.value)}',
    };
    final d = await edit('分类之间挪额度', [
      Field('from', '从哪个分类转出', options: options),
      Field('to', '转入哪个分类', options: options, value: options.keys.elementAt(1)),
      Field('amount', '挪动金额', amount: true),
      Field('reason', '原因'),
    ], hint: '只改变分类额度，不增加总预算，也不改变储蓄目标。');
    if (d == null) return;
    await change((b) {
      final p = b.plans.firstWhere((p) => p.id == plan.id),
          from = d['from']!,
          to = d['to']!;
      final amount = cents(d['amount']!);
      if (from == to || amount <= 0 || amount > p.categoryLimits[from]!)
        throw StateError('请选择不同分类和有效金额');
      p.categoryLimits[from] = p.categoryLimits[from]! - amount;
      p.categoryLimits[to] = p.categoryLimits[to]! + amount;
      p.history.add(
        '${DateTime.now().toIso8601String()} $from → $to ${money(amount)}；${d['reason']}',
      );
    });
  }

  Widget dailyCard(Plan p) {
    final b = book!, days = b.daysLeft(p, today());
    return SheetCard(
      color: palette.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            '每日规划',
            p.dailyOriginal == null
                ? null
                : Text('$days 天', style: TextStyle(fontSize: 12, color: muted)),
          ),
          if (p.dailyOriginal == null) ...[
            line(
              '预算内预留',
              money(
                p.reservations
                    .where((r) => r.inBudget)
                    .fold(0, (n, r) => n + r.amount),
              ),
            ),
            line(
              '可分摊预算',
              money(
                p.budget -
                    p.reservations
                        .where((r) => r.inBudget)
                        .fold(0, (n, r) => n + r.amount),
              ),
            ),
            SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                await change(
                  (b) => b.enableDaily(b.plans.firstWhere((x) => x.id == p.id)),
                );
              },
              child: Text('启用每日规划'),
            ),
          ] else ...[
            Text(
              days == 0 ? '周期已结束' : '剩余日均',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            SizedBox(height: 8),
            FittedBox(
              child: Text(
                money(b.dailyAllowance(p, today())),
                style: palette.amountStyle(36),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: metric('初始日均', money(p.dailyOriginal!))),
                SizedBox(width: 12),
                Expanded(
                  child: metric('今日支出', money(b.dailySpent(p, today()))),
                ),
              ],
            ),
            details('计算明细', [
              line('日常预算剩余', money(b.budgetFree(p))),
              line('剩余天数（含今天）', '$days 天'),
              note('剩余日均 = 日常预算剩余 ÷ 剩余天数。今日支出包含预留项目。'),
            ]),
            if (b.cashFree(p) < max(0, b.budgetFree(p))) note('可用资金不足，参见计划可花额'),
            if (p.start.compareTo(today()) > 0) note('尚未开始'),
            if (b.budgetFree(p) < 0) note('日常预算超支 ${money(-b.budgetFree(p))}'),
          ],
        ],
      ),
    );
  }

  Widget reservationCard(Plan p, int index) {
    final r = p.reservations[index];
    final spent = book!.spent(p, r.category);
    final over = spent > r.amount;
    final error = Theme.of(context).colorScheme.error;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(categoryIcon(r.category), color: sage, size: 22),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                tooltip: '管理预留',
                icon: Icon(Icons.more_horiz),
                onPressed: () async {
                  final action = await choose(r.title, {
                    'edit': '调整预留',
                    'remove': '移除预留',
                  });
                  if (action == 'edit') await reserveEditor(p, index: index);
                  if (action == 'remove') {
                    if (!await confirm('移除预留？', '保留实际支出，并记录此次调整。')) return;
                    await change((b) {
                      final next = b.plans.firstWhere((x) => x.id == p.id);
                      next.history.add(
                        '${DateTime.now().toIso8601String()} 移除预留：${next.reservations[index].title}',
                      );
                      next.reservations.removeAt(index);
                    });
                  }
                },
              ),
            ],
          ),
          Text(
            '${r.category} · ${r.inBudget ? '预算内' : '预算外'}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          SizedBox(height: 16),
          Text(
            over ? '已超支' : '剩余',
            style: TextStyle(fontSize: 12, color: over ? error : muted),
          ),
          SizedBox(height: 4),
          Text(
            money((r.amount - spent).abs()),
            style: palette.amountStyle(24, color: over ? error : ink),
          ),
          SizedBox(height: 12),
          Semantics(
            label: '已花 ${money(spent)}，预留 ${money(r.amount)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: r.amount == 0
                    ? (spent > 0 ? 1 : 0)
                    : (spent / r.amount).clamp(0.0, 1.0).toDouble(),
                color: over ? error : sage,
                backgroundColor: palette.soft,
              ),
            ),
          ),
          line('已花 / 预留', '${money(spent)} / ${money(r.amount)}'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => entry('支出', category: r.category),
              icon: Icon(Icons.add, size: 20),
              label: Text('记支出'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> reserveEditor(Plan plan, {int? index}) async {
    final old = index == null ? null : plan.reservations[index];
    final d = await edit(old == null ? '添加开支预留' : '调整开支预留', [
      Field('name', '项目名称', value: old?.title ?? ''),
      Field('category', '关联分类', value: old?.category ?? ''),
      Field(
        'amount',
        '周期总额度（含已花）',
        amount: true,
        value: number(old?.amount ?? 0),
      ),
      Field(
        'included',
        '包含在总预算内',
        toggle: true,
        value: '${old?.inBudget ?? true}',
      ),
      Field('reason', '设置或调整原因'),
    ], hint: '每个项目关联一个分类，该分类在本周期的已有支出也会计入。');
    if (d == null) return;
    await change((b) {
      final p = b.plans.firstWhere((p) => p.id == plan.id);
      if (p.reservations.asMap().entries.any(
        (e) => e.key != index && e.value.category == d['category'],
      ))
        throw StateError('此分类已有预留，请使用另一个专用分类');
      final item = Reservation(
        d['name']!,
        d['category']!,
        cents(d['amount']!),
        d['included'] == 'true',
      );
      if (index == null) {
        p.reservations.add(item);
      } else {
        p.reservations[index] = item;
      }
      if (!b.categories.contains(item.category))
        b.categories.add(item.category);
      p.history.add(
        '${DateTime.now().toIso8601String()} ${old == null ? '新增' : '调整'}预留 ${d['name']} ${money(cents(d['amount']!))}；${d['included'] == 'true' ? '预算内' : '预算外'}；${d['reason']}',
      );
    });
  }

  List<Widget> ledger() {
    final b = book!;
    final entries =
        b.entries.where((e) {
          final accountNames = e.cash.keys
              .map((id) => b.wallets.firstWhere((w) => w.id == id).name)
              .join(' ');
          final claimNames = e.claims.keys
              .map((id) => b.claims.firstWhere((c) => c.id == id).title)
              .join(' ');
          return periodMatch(e.date, ledgerYear, ledgerMonth) &&
              (ledgerType == '全部' ||
                  ledgerType == '作废' && e.voided ||
                  !e.voided &&
                      (ledgerType == '支出' &&
                              (e.expense > 0 || e.kind == '支出') ||
                          ledgerType == '收入' && e.income > 0 ||
                          ledgerType == '转账' && e.kind == '转账' ||
                          ledgerType == '其他' &&
                              e.expense == 0 &&
                              e.kind != '支出' &&
                              e.income == 0 &&
                              e.kind != '转账')) &&
              (filterDate.isEmpty || e.date == filterDate) &&
              '$accountNames $claimNames ${e.note} ${e.kind} ${e.category}'
                  .toLowerCase()
                  .contains(query.toLowerCase());
        }).toList()..sort((a, b) {
          final cmp = b.date.compareTo(a.date);
          return cmp == 0 ? b.id.compareTo(a.id) : cmp;
        });
    return [
      periodBar(
        ledgerYear,
        ledgerMonth,
        (y, m) => setState(() {
          ledgerYear = y;
          ledgerMonth = m;
          ledgerPage = 0;
          filterDate = '';
        }),
      ),
      chips(
        ['全部', '支出', '收入', '转账', '作废', '其他'],
        ledgerType,
        (v) => setState(() {
          ledgerType = v;
          ledgerPage = 0;
        }),
      ),
      TextFormField(
        initialValue: query,
        decoration: InputDecoration(
          labelText: '搜索流水',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() {
          query = v;
          ledgerPage = 0;
        }),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(filterDate) ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null && mounted)
                setState(() => filterDate = day(date));
            },
            icon: Icon(Icons.calendar_month_outlined),
            label: Text(filterDate.isEmpty ? '按日查看' : filterDate),
          ),
          if (filterDate.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => filterDate = ''),
              child: Text('全部日期'),
            ),
        ],
      ),
      line('当前个人可用', money(b.cash)),
      if (b.overviewPlan() != null)
        line('当前计划还可花', money(b.spendable(b.overviewPlan()!))),
      if (entries.isEmpty) note('暂无流水'),
      ...pageItems(entries, ledgerPage).map((e) {
        final amount = e.kind == '支出'
            ? e.cash.values.fold(0, (a, v) => a + v)
            : e.expense > 0
            ? -e.expense
            : e.income > 0
            ? e.income
            : e.cash.values.where((v) => v > 0).fold(0, (a, b) => a + b);
        return balanceTile(
          '${e.category.isNotEmpty ? e.category : e.kind}${e.voided ? ' · 已作废' : ''}',
          '${e.date} · ${e.kind}${e.image.isEmpty ? '' : ' · 附图'}${e.note.isEmpty ? '' : '\n${e.note}'}',
          amount == 0 ? '查看明细' : money(amount),
          e.voided
              ? Icons.block_outlined
              : e.kind == '转账'
              ? Icons.swap_horiz
              : e.expense > 0 || e.kind == '支出'
              ? categoryIcon(e.category)
              : Icons.south_west,
          () => entryDetails(e),
          amountColor: e.voided
              ? muted
              : e.expense > 0 || e.kind == '支出'
              ? ink
              : sage,
        );
      }),
      pager(entries.length, ledgerPage, (v) => setState(() => ledgerPage = v)),
    ];
  }

  Future<void> entryDetails(Entry e) async {
    final b = book!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${e.date} · ${e.kind}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.voided) Text('已作废'),
                ...e.cash.entries.map(
                  (m) => line(
                    b.wallets.firstWhere((w) => w.id == m.key).name,
                    money(m.value),
                  ),
                ),
                ...e.claims.entries.map(
                  (m) => line(
                    b.claims.firstWhere((c) => c.id == m.key).title,
                    money(m.value),
                  ),
                ),
                ...e.holdings.entries.map(
                  (h) => line(
                    '代管 · ${b.custodies.firstWhere((c) => c.id == h.key).owner}',
                    money(h.value),
                  ),
                ),
                line('计入个人消费', money(e.expense)),
                if (e.kind == '支出') ...[
                  line('实际付款', money(-e.cash.values.fold(0, (n, v) => n + v))),
                  line('计划统计', e.countsForPlan ? '计入计划' : '计划外 · 不扣预算'),
                  if (e.custodyCovered > 0)
                    line('代管款承担', money(e.custodyCovered)),
                ],
                line('计入普通收入', money(e.income)),
                if (e.income > 0) ...[
                  line(
                    '补充计划额度',
                    e.incomePlanId.isEmpty
                        ? '未加入计划'
                        : '${e.incomePlanName} · ${money(e.income)}${e.voided ? '（已撤回）' : ''}',
                  ),
                  if (e.cashAfter != null)
                    line('本笔入账后个人可用', money(e.cashAfter!)),
                  if (e.walletAfter != null)
                    line('本笔入账后账户可用', money(e.walletAfter!)),
                  if (e.planAfter != null)
                    line('本笔入账后计划可花', money(e.planAfter!)),
                  if (e.voided && e.cashAfter != null)
                    note('以上入账后金额为原记录快照；本笔已作废，当前余额已重新计算。'),
                  line('当前个人可用', money(b.cash)),
                  for (final id in e.cash.keys)
                    line(
                      '${b.wallets.firstWhere((w) => w.id == id).name} · 当前可用',
                      money(b.walletAvailable(id)),
                    ),
                  if (b.overviewPlan() != null)
                    line('当前计划还可花', money(b.spendable(b.overviewPlan()!))),
                ],
                Text(e.note),
                if (e.image.isNotEmpty && b.images.containsKey(e.image))
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Image.memory(
                      base64Decode(b.images[e.image]!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text('图片无法显示'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (!e.voided)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final data = await edit('作废记录', [
                  Field('reason', '作废原因'),
                ], hint: '后续有依赖的资金记录须先处理。原定计划起点不会随作废而改写。');
                if (data != null)
                  await change(
                    (b) => b.voidEntry(
                      b.entries.firstWhere((x) => x.id == e.id),
                      data['reason']!,
                    ),
                  );
              },
              child: Text('作废'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> settings() async {
    final action = await choose('设置', {
      'stats': '个人统计',
      'fixed': '每月固定开支',
      'theme': '更换主题 · ${palette.name}',
      'categories': '管理收支分类',
      'backup': '导出完整备份（含图片）',
      'restore': '从本地备份恢复',
      'csv': '导出流水CSV',
      'alerts': book!.notifications ? '关闭预算与底线系统通知' : '开启预算与底线系统通知',
      'audit': '操作记录',
      'about': '数据与计算规则',
    });
    try {
      if (action == 'stats') await personalPage();
      if (action == 'fixed') await fixedPage();
      if (action == 'theme') await themePicker();
      if (action == 'categories') await manageCategories();
      if (action == 'backup')
        tell(await storage.backup(book!) ? '完整备份已保存到你选择的位置' : '已取消备份');
      if (action == 'csv') tell(await storage.csv(book!) ? 'CSV已导出' : '已取消导出');
      if (action == 'restore') {
        if (!await confirm('恢复会替换当前账本', '建议先导出当前账本的完整备份。继续选择备份文件？')) return;
        final restored = await storage.importBackup();
        if (restored == null) return;
        if (!await confirm(
          '确认恢复这份账本？',
          '${restored.wallets.length}个账户、${restored.entries.length}笔记录、${restored.plans.length}个计划。\n总资产 ${money(restored.assets)}。\n此操作替换当前数据。',
        ))
          return;
        if (busy) return;
        setState(() => busy = true);
        try {
          await storage.save(restored);
          if (mounted) {
            setState(() => book = restored);
            widget.onThemeChanged(restored.themeId);
          }
          tell('恢复完成');
        } finally {
          if (mounted) setState(() => busy = false);
        }
      }
      if (action == 'alerts') {
        if (book!.notifications) {
          await change((b) => b.notifications = false);
        } else {
          if (!alerts.ready) await alerts.initialize();
          final allowed = await alerts.ask();
          if (allowed) {
            await change((b) => b.notifications = true);
            tell('已开启；只在预算或底线从正常变为突破时提醒');
          } else {
            tell('未获得通知权限，账本内仍会显示超支和底线状态');
          }
        }
      }
      if (action == 'audit' && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('操作记录'),
            content: SingleChildScrollView(
              child: Text(
                book!.audit.isEmpty
                    ? '暂无操作记录'
                    : book!.audit.reversed.join('\n\n'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('关闭'),
              ),
            ],
          ),
        );
      }
      if (action == 'about' && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('暖账 · 0.3.0 · 支出分摊版'),
            content: SingleChildScrollView(
              child: Text(
                '完全离线，无账号、无广告、无远程同步。\n\n个人总资产＝账户余额－代管余额＋朋友待还＋押金＋预计到账款。代管款独立显示，不计个人收支。预计到账不保证能即时使用。\n\n转账、借出、收回不重复算作普通收支。预算、底线和储蓄预留各自独立，底线只提醒。\n\n通知仅在你操作账本后发现突破时触发，不在后台读取其他应用，也不提醒预计到账。\n\n备份为未加密本地文件，含账目和图片，请自行保管；CSV不包含附件，不能代替完整备份。卸载前请先导出完整备份。\n\n本版手动录入，不自动读取微信、支付宝或银行。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      tell('操作未完成：$e');
    }
  }

  Future<void> themePicker() async {
    final id = await selectLedgerTheme(context, book!.themeId);
    if (id == null || !mounted) return;
    await change((b) => b.themeId = id);
  }

  Future<void> manageCategories() async {
    final type = await choose('分类管理', {
      'defaults': '补充内置三级分类（保留现有分类）',
      'add': '新增分类',
      'rename': '分类改名',
      'disable': '停用分类',
    });
    if (type == null) return;
    if (type == 'defaults') {
      await change(
        (b) => b.categories = {...b.categories, ...defaultCategories}.toList(),
      );
      return;
    }
    if (type != 'add' && categoryOptions.isEmpty) {
      tell('暂无分类');
      return;
    }
    final d = await edit(
      type == 'add'
          ? '新增分类'
          : type == 'rename'
          ? '分类改名'
          : '停用分类',
      [
        if (type != 'add') Field('old', '选择分类', options: categoryOptions),
        if (type != 'disable') Field('name', '分类名称（最多三级，用 / 分隔）'),
      ],
    );
    if (d == null) return;
    await change((b) {
      if (type != 'disable' && b.categories.contains(d['name']))
        throw StateError('分类名称已存在');
      if (type == 'add') {
        final path = d['name']!.split('/').map((s) => s.trim()).join('/');
        if (path.split('/').length > 3 || path.split('/').any((s) => s.isEmpty))
          throw StateError('分类最多三级，用 / 分隔');
        b.categories.add(path);
      }
      if (type == 'disable') {
        b.categories.remove(d['old']);
        b.audit.add('${today()} 停用分类 ${d['old']}');
      }
      if (type == 'rename') {
        final old = d['old']!, name = d['name']!;
        if (name.split('/').length > 3 ||
            name.split('/').any((s) => s.trim().isEmpty))
          throw StateError('分类最多三级');
        b.categories[b.categories.indexOf(old)] = name;
        for (final e in b.entries) {
          if (e.category == old) e.category = name;
        }
        for (final f in b.fixedCosts) {
          if (f.category == old) f.category = name;
        }
        for (final p in b.plans) {
          if (p.categoryLimits.containsKey(old))
            p.categoryLimits[name] = p.categoryLimits.remove(old)!;
          for (final r in p.reservations) {
            if (r.category == old) r.category = name;
          }
          p.history.add(
            '${DateTime.now().toIso8601String()} 分类更名 $old → $name；金额不变',
          );
        }
        b.audit.add('${today()} 分类更名 $old → $name');
      }
    });
  }

  String workspacePlanId = '';

  static const pageSize = 6;
  bool periodMatch(String date, int year, int month) =>
      date.startsWith('$year-') &&
      (month == 0 ||
          date.startsWith('$year-${month.toString().padLeft(2, '0')}'));
  List<T> pageItems<T>(List<T> items, int index) {
    final count = max(1, (items.length / pageSize).ceil());
    return items
        .skip(index.clamp(0, count - 1) * pageSize)
        .take(pageSize)
        .toList();
  }

  Widget pager(int count, int current, ValueChanged<int> onChange) {
    final pages = max(1, (count / pageSize).ceil()),
        safe = current.clamp(0, pages - 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '上一页',
          onPressed: safe > 0 ? () => onChange(safe - 1) : null,
          icon: Icon(Icons.chevron_left),
        ),
        Flexible(
          child: Text(
            '第 ${safe + 1} / $pages 页 · $count 项',
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: '下一页',
          onPressed: safe + 1 < pages ? () => onChange(safe + 1) : null,
          icon: Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget chips(
    List<String> choices,
    String selected,
    ValueChanged<String> onChange,
  ) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final value in choices)
          ChoiceChip(
            label: Text(value),
            selected: selected == value,
            onSelected: (_) => onChange(value),
          ),
      ],
    ),
  );
  Widget periodBar(
    int year,
    int month,
    void Function(int, int) update, {
    bool allowYear = true,
  }) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        IconButton(
          tooltip: '上一周期',
          icon: Icon(Icons.chevron_left),
          onPressed: year <= 2000 && month <= 1
              ? null
              : () {
                  if (month == 0) {
                    update(year - 1, 0);
                  } else {
                    final d = DateTime(year, month - 1);
                    update(d.year, d.month);
                  }
                },
        ),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final d = await edit('选择统计周期', [
                Field('year', '年份', value: '$year'),
                Field(
                  'month',
                  '月份',
                  value: '$month',
                  options: {
                    if (allowYear) '0': '全年',
                    for (var i = 1; i <= 12; i++) '$i': '$i月',
                  },
                ),
              ]);
              if (d == null) return;
              final y = int.tryParse(d['year']!);
              if (y == null || y < 2000 || y > 2200) {
                tell('年份需在2000至2200之间');
                return;
              }
              update(y, int.parse(d['month']!));
            },
            child: Text(month == 0 ? '$year年 · 全年' : '$year年 $month月'),
          ),
        ),
        IconButton(
          tooltip: '下一周期',
          icon: Icon(Icons.chevron_right),
          onPressed: year >= 2200 && (month == 0 || month == 12)
              ? null
              : () {
                  if (month == 0) {
                    update(year + 1, 0);
                  } else {
                    final d = DateTime(year, month + 1);
                    update(d.year, d.month);
                  }
                },
        ),
      ],
    ),
  );
  List<Widget> compactHome() {
    final b = book!, p = b.overviewPlan();
    return [
      SheetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(
              '我的资金',
              TextButton(onPressed: personalPage, child: Text('个人统计')),
            ),
            line('个人总资产', money(b.assets)),
            line('个人可用', money(b.cash)),
            line('待收回 / 待到账', money(b.pending)),
            Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('替他人保管'),
              subtitle: Text('不计入个人资产与可用余额'),
              trailing: Text(money(b.held), style: palette.amountStyle(18)),
              onTap: () => setState(() {
                page = 1;
                accountTab = '代管';
                accountPage = 0;
              }),
            ),
          ],
        ),
      ),
      if (b.wallets.isEmpty)
        empty('开始记录', '先登记一个账户，后续收支从真实余额开始。', '添加账户', () => walletEditor()),
      if (p == null)
        SheetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('当前没有执行中的计划'),
              note('新建计划或调整状态后，这里显示还能花多少。'),
              TextButton(
                onPressed: () => setState(() => page = 3),
                child: Text('查看计划'),
              ),
            ],
          ),
        )
      else
        SheetCard(
          color: palette.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(
                p.name,
                TextButton(onPressed: () => planDetails(p), child: Text('详情')),
              ),
              Text('${p.start} — ${p.end}', style: TextStyle(color: muted)),
              SizedBox(height: 12),
              Text(
                '还可花 ${money(b.spendable(p))}',
                style: palette.amountStyle(28),
              ),
              SizedBox(height: 8),
              Text(
                '预算已花 ${money(b.budgetSpent(p))} · 剩余 ${b.daysLeft(p, today())} 天',
              ),
              if (p.dailyOriginal != null)
                note('剩余日均 ${money(b.dailyAllowance(p, today()))}'),
              if (b.fixedReserved(p) > 0)
                note('已为固定开支留出 ${money(b.fixedReserved(p))}'),
              if (b.incomeAdded(p) > 0)
                line('已加入收入额度', money(b.incomeAdded(p))),
              note('按跨度最大的执行中计划计算'),
            ],
          ),
        ),
      trendCard(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: fixedPage,
            icon: Icon(Icons.event_repeat),
            label: Text('固定开支'),
          ),
          OutlinedButton.icon(
            onPressed: personalPage,
            icon: Icon(Icons.insights_outlined),
            label: Text('个人统计'),
          ),
        ],
      ),
    ];
  }

  List<Widget> compactAccounts() {
    final b = book!;
    final ws = b.wallets.toList();
    final claims = b.claims.toList();
    final holds = b.custodies.toList();
    return [
      chips(
        ['账户', '应收', '代管'],
        accountTab,
        (v) => setState(() {
          accountTab = v;
          accountPage = 0;
        }),
      ),
      if (accountTab == '账户') ...[
        heading(
          '个人可用 ${money(b.cash)}${b.cash < 0 ? ' · 待补回' : ''}',
          TextButton(onPressed: () => walletEditor(), child: Text('添加')),
        ),
        for (final w in pageItems(ws, accountPage))
          balanceTile(
            w.name,
            '${w.archived ? '已归档 · ' : ''}实存 ${money(b.walletBalance(w.id))} · 代管 ${money(b.walletHeld(w.id))}${b.walletAvailable(w.id) < 0 ? ' · 个人垫用待补回' : ''}',
            money(b.walletAvailable(w.id)),
            Icons.account_balance_wallet_outlined,
            () => walletActions(w),
            amountColor: b.walletAvailable(w.id) < 0 ? Colors.redAccent : null,
          ),
        if (ws.isEmpty) note('暂无账户'),
        pager(ws.length, accountPage, (v) => setState(() => accountPage = v)),
      ],
      if (accountTab == '应收') ...[
        heading(
          '待到账 ${money(b.pending)}',
          TextButton(onPressed: claimCreate, child: Text('添加')),
        ),
        for (final c in pageItems(claims, accountPage))
          balanceTile(
            c.title,
            '${c.kind} · ${c.person}${c.due.isEmpty ? '' : ' · ${c.due}'}',
            money(b.claimBalance(c.id)),
            Icons.hourglass_bottom_outlined,
            () => claimActions(c),
          ),
        if (claims.isEmpty) note('暂无应收'),
        pager(
          claims.length,
          accountPage,
          (v) => setState(() => accountPage = v),
        ),
      ],
      if (accountTab == '代管') ...[
        heading(
          '代管 ${money(b.held)}',
          TextButton(onPressed: custodyEditor, child: Text('存入')),
        ),
        note('代管款独立记录归属。代付时可抵扣代管余额；临时垫用后需补回则不抵扣。'),
        for (final c in pageItems(holds, accountPage))
          balanceTile(
            c.owner,
            b.wallets.firstWhere((w) => w.id == c.walletId).name,
            money(b.heldBalance(c.id)),
            Icons.lock_outline,
            () => custodyReturn(c),
          ),
        if (holds.isEmpty) note('暂无代管款'),
        pager(
          holds.length,
          accountPage,
          (v) => setState(() => accountPage = v),
        ),
      ],
      details('账户流水回顾', [
        periodBar(
          accountYear,
          accountMonth,
          (y, m) => setState(() {
            accountYear = y;
            accountMonth = m;
          }),
        ),
        for (final w in pageItems(ws, accountPage))
          line(
            w.name,
            money(
              b.active
                  .where((e) => periodMatch(e.date, accountYear, accountMonth))
                  .fold(0, (n, e) => n + (e.cash[w.id] ?? 0)),
            ),
          ),
        TextButton(
          onPressed: () => setState(() {
            ledgerYear = accountYear;
            ledgerMonth = accountMonth;
            page = 4;
            ledgerPage = 0;
          }),
          child: Text('查看该周期全部流水'),
        ),
      ]),
    ];
  }

  Future<void> custodyEditor() async {
    if (walletOptions.isEmpty) {
      tell('请先添加账户');
      return;
    }
    final d = await edit('存入代管款', [
      Field('owner', '钱的所有人'),
      Field('wallet', '存放账户', options: walletOptions),
      Field('amount', '金额', amount: true),
      Field('date', '日期', date: true, value: today()),
    ]);
    if (d != null)
      await change(
        (b) => b.depositCustody(
          d['owner']!,
          d['wallet']!,
          cents(d['amount']!),
          d['date']!,
        ),
      );
  }

  Future<void> custodyReturn(Custody c) async {
    if (book!.heldBalance(c.id) == 0) {
      tell('这笔代管款已结清');
      return;
    }
    final d = await edit('归还给${c.owner}', [
      Field(
        'amount',
        '本次归还',
        amount: true,
        value: number(book!.heldBalance(c.id)),
      ),
      Field('date', '日期', date: true, value: today()),
    ]);
    if (d != null)
      await change(
        (b) => b.returnCustody(c.id, cents(d['amount']!), d['date']!),
      );
  }

  List<Widget> plans() {
    final b = book!;
    final start =
        '$planYear-${(planMonth == 0 ? 1 : planMonth).toString().padLeft(2, '0')}-01';
    final end = day(
      planMonth == 0
          ? DateTime(planYear, 12, 31)
          : DateTime(planYear, planMonth + 1, 0),
    );
    final list =
        b.plans
            .where(
              (p) =>
                  p.start.compareTo(end) <= 0 &&
                  p.end.compareTo(start) >= 0 &&
                  (planStatus == '全部' || statusNames[p.status] == planStatus) &&
                  (planTerm == '全部' || p.term == planTerm),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    return [
      heading(
        '周期计划',
        TextButton.icon(
          onPressed: () => planEditor(),
          icon: Icon(Icons.add),
          label: Text('新建'),
        ),
      ),
      periodBar(
        planYear,
        planMonth,
        (y, m) => setState(() {
          planYear = y;
          planMonth = m;
          planPage = 0;
        }),
      ),
      chips(
        ['全部', ...statusNames.values],
        planStatus,
        (v) => setState(() {
          planStatus = v;
          planPage = 0;
        }),
      ),
      Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LedgerChoice(
          label: '周期类型',
          value: planTerm == '全部' ? '全部周期' : termNames[planTerm]!,
          onTap: () async {
            final value = await choose('周期类型', {'全部': '全部周期', ...termNames});
            if (value != null)
              setState(() {
                planTerm = value;
                planPage = 0;
              });
          },
        ),
      ),
      for (final p in pageItems(list, planPage))
        balanceTile(
          p.name,
          '${statusNames[p.status]} · ${termNames[p.term]!.split(' · ').first}\n${p.start} — ${p.end}',
          money(b.spendable(p)),
          Icons.flag_outlined,
          () => planDetails(p),
        ),
      if (list.isEmpty) note('该周期和筛选下暂无计划'),
      pager(list.length, planPage, (v) => setState(() => planPage = v)),
      TextButton.icon(
        onPressed: fixedPage,
        icon: Icon(Icons.event_repeat),
        label: Text('管理每月固定开支'),
      ),
    ];
  }

  String get detailPlanId => workspacePlanId;
  Future<void> planDetails(Plan p) async {
    workspacePlanId = p.id;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailPage(host: this, id: p.id),
      ),
    );
  }

  Future<void> planStateEditor(Plan p) async {
    final status = await choose('计划状态', statusNames);
    if (status != null) await change((b) => b.transitionPlan(p.id, status));
  }

  Future<void> deletePlanEditor(Plan p) async {
    if (!await confirm(
      '删除“${p.name}”？',
      '删除计划和其预算设置；保留所有资金流水。关联固定开支解除计划归属，继续保留。',
    ))
      return;
    await change((b) => b.deletePlan(p.id));
  }

  Widget trendCard() {
    final b = book!;
    final yearly = chartScale == '年';
    final count = yearly ? 12 : DateTime(chartYear, chartMonth + 1, 0).day;
    final dates = List.generate(
      count,
      (i) => yearly
          ? '$chartYear-${(i + 1).toString().padLeft(2, '0')}'
          : day(DateTime(chartYear, chartMonth, i + 1)),
    );
    final values = dates
        .map(
          (d) => b.active
              .where((e) => e.date.startsWith(d))
              .fold(0, (n, e) => n + e.expense),
        )
        .toList();
    return SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            '消费趋势',
            TextButton(onPressed: personalPage, child: Text('报表')),
          ),
          chips(
            ['年', '月', '日'],
            chartScale,
            (v) => setState(() => chartScale = v),
          ),
          periodBar(
            chartYear,
            yearly ? 0 : chartMonth,
            (y, m) => setState(() {
              chartYear = y;
              if (m > 0) chartMonth = m;
            }),
            allowYear: yearly,
          ),
          chips(['柱状', '折线'], chartKind, (v) => setState(() => chartKind = v)),
          if (chartScale == '日') ...[
            Text('逐日消费 · 点日期查看流水', style: TextStyle(color: muted)),
            SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: .8,
              children: [
                for (var i = 0; i < dates.length; i++)
                  InkWell(
                    onTap: () => setState(() {
                      ledgerYear = chartYear;
                      ledgerMonth = chartMonth;
                      filterDate = dates[i];
                      ledgerPage = 0;
                      page = 4;
                    }),
                    child: Semantics(
                      label: '${dates[i]}支出${number(values[i])}元',
                      button: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${i + 1}'),
                          FittedBox(
                            child: Text(
                              number(values[i]),
                              style: palette.amountStyle(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else
            InteractiveTrend(
              values: values,
              labels: List.generate(
                count,
                (i) => '${i + 1}${yearly ? '月' : '日'}',
              ),
              lineMode: chartKind == '折线',
              onSelect: (i) => setState(() {
                ledgerYear = chartYear;
                ledgerMonth = yearly ? i + 1 : chartMonth;
                filterDate = yearly ? '' : dates[i];
                ledgerPage = 0;
                page = 4;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> personalPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PersonalStatsPage(host: this)),
    );
  }

  Future<void> fixedPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => FixedCostsPage(host: this)));
  }

  Future<void> fixedEditor([FixedCost? f]) async {
    final d = await edit(
      f == null ? '添加固定开支' : '修改固定开支',
      [
        Field('name', '名称', value: f?.name ?? ''),
        Field('amount', '每月金额', amount: true, value: number(f?.amount ?? 0)),
        Field(
          'category',
          '分类',
          options: categoryOptions,
          value: f?.category ?? '住房',
        ),
        Field('due', '每月付款日（1—31）', value: '${f?.dueDay ?? 1}'),
        Field(
          'start',
          '开始月份（YYYY-MM）',
          value: f?.startMonth ?? today().substring(0, 7),
        ),
        Field('end', '结束月份（留空表示持续）', optional: true, value: f?.endMonth ?? ''),
        Field(
          'plan',
          '计入计划',
          value: f?.planId ?? '',
          options: {'': '暂不归属计划', for (final p in book!.plans) p.id: p.name},
        ),
      ],
      hint: '不会自动扣款。关联计划会预留到期金额，确认支付后才记消费。每月31日遇短月按当月最后一天。',
    );
    if (d == null) return;
    await change((b) {
      final due = int.tryParse(d['due']!);
      if (due == null) throw StateError('付款日请填1至31');
      final item = f == null
          ? FixedCost(
              id: newId(),
              name: d['name']!,
              category: d['category']!,
              amount: cents(d['amount']!),
              dueDay: due,
              startMonth: d['start']!,
            )
          : b.fixedCosts.firstWhere((c) => c.id == f.id);
      item.name = d['name']!;
      item.amount = cents(d['amount']!);
      item.category = d['category']!;
      item.dueDay = due;
      item.startMonth = d['start']!;
      item.endMonth = d['end']!;
      item.planId = d['plan']!;
      if (f == null) b.fixedCosts.add(item);
    });
  }

  Future<void> payFixedEditor(FixedCost f, String month) async {
    if (walletOptions.isEmpty) {
      tell('请先添加账户');
      return;
    }
    final d = await edit(
      '支付${f.name}',
      [
        Field('wallet', '付款账户', options: walletOptions),
        Field('date', '实际支付日期', date: true, value: today()),
      ],
      hint: '本次支出 ${money(book!.fixedRemaining(f, month))}，统计归入实际付款日期。',
    );
    if (d != null)
      await change((b) => b.payFixed(f.id, month, d['wallet']!, d['date']!));
  }
}
