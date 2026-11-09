import 'package:flutter/material.dart';

import 'model.dart';
import 'themes.dart';

/// Keep the action above the keyboard, including in landscape. Only let it
/// scroll with the form when the available height cannot fit both regions.
class LedgerSheet extends StatelessWidget {
  const LedgerSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });
  final String title;
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final p = LedgerTheme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final height = (box.maxHeight - keyboard)
            .clamp(0.0, box.maxHeight)
            .toDouble();
        final scaledActionText =
            MediaQuery.textScalerOf(context).scale(15) * 1.5;
        final buttonHeight = scaledActionText + 28 > 52
            ? scaledActionText + 28
            : 52.0;
        // The footer has 28dp of padding. Leave at least 96dp for scrolling fields.
        final compact = height * .96 < buttonHeight + 28 + 96;
        final action = footer == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: SizedBox(width: double.infinity, child: footer),
              );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Container(
            constraints: BoxConstraints(maxHeight: height * .96, maxWidth: 600),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                            child: Column(
                              children: [
                                ExcludeSemantics(
                                  child: Container(
                                    width: 32,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: p.outline,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '关闭',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close, size: 22),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: child,
                          ),
                          if (compact && action != null) action,
                        ],
                      ),
                    ),
                  ),
                  if (!compact && action != null) action,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class Field {
  Field(
    this.key,
    this.label, {
    this.value = '',
    this.options,
    this.amount = false,
    this.date = false,
    this.optional = false,
    this.toggle = false,
  });
  final String key, label, value;
  final Map<String, String>? options;
  final bool amount, date, optional, toggle;
}

IconData categoryIcon(String name) {
  if (RegExp('餐|饭|吃|食品').hasMatch(name)) return Icons.restaurant_outlined;
  if (RegExp('交通|车|出行').hasMatch(name)) return Icons.directions_bus_outlined;
  if (RegExp('房|住房|租').hasMatch(name)) return Icons.home_outlined;
  if (RegExp('话费|通讯|手机').hasMatch(name)) return Icons.phone_android_outlined;
  if (RegExp('日用|洗|清洁').hasMatch(name))
    return Icons.local_laundry_service_outlined;
  if (RegExp('学习|书|教育').hasMatch(name)) return Icons.menu_book_outlined;
  if (RegExp('娱乐|游戏|电影').hasMatch(name)) return Icons.sports_esports_outlined;
  if (RegExp('购物|服饰|衣').hasMatch(name)) return Icons.shopping_bag_outlined;
  if (RegExp('医|药|健康').hasMatch(name)) return Icons.health_and_safety_outlined;
  return Icons.grid_view_outlined;
}

/// The route owns the controllers, including during its exit transition.
Future<Map<String, String>?> showLedgerEditor(
  BuildContext context,
  String title,
  List<Field> fields, {
  String hint = '',
  String submit = '保存',
  bool quick = false,
}) => showModalBottomSheet<Map<String, String>>(
  context: context,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => LedgerEditor(
    title: title,
    fields: fields,
    hint: hint,
    submit: submit,
    quick: quick,
  ),
);

Future<String?> selectLedgerOption(
  BuildContext context,
  String title,
  Map<String, String> options, {
  String? selected,
  bool categories = false,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _OptionSheet(
    title: title,
    options: options,
    selected: selected,
    categories: categories,
  ),
);

class LedgerChoice extends StatelessWidget {
  const LedgerChoice({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.account_balance_wallet_outlined,
  });
  final String label, value;
  final VoidCallback? onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = LedgerTheme.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: p.accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: p.secondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Icon(Icons.unfold_more, color: p.secondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LedgerEditor extends StatefulWidget {
  const LedgerEditor({
    super.key,
    required this.title,
    required this.fields,
    this.hint = '',
    this.submit = '保存',
    this.quick = false,
  });
  final String title, hint, submit;
  final List<Field> fields;
  final bool quick;
  @override
  State<LedgerEditor> createState() => _LedgerEditorState();
}

class _LedgerEditorState extends State<LedgerEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, String> choices;
  late final Map<String, FocusNode> nodes;
  late bool expanded;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in widget.fields.where(
        (f) => !f.toggle && f.options == null,
      ))
        f.key: TextEditingController(text: f.value),
    };
    nodes = {for (final key in controllers.keys) key: FocusNode()};
    choices = {
      for (final f in widget.fields.where((f) => f.toggle || f.options != null))
        f.key: f.toggle
            ? (f.value.isEmpty ? 'false' : f.value)
            : f.options!.containsKey(f.value)
            ? f.value
            : f.options!.keys.firstOrNull ?? '',
    };
    expanded = widget.fields.any((f) => f.optional && f.value.isNotEmpty);
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final n in nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void save() {
    FocusManager.instance.primaryFocus?.unfocus();
    final errors = form.currentState!.validateGranularly();
    if (errors.isNotEmpty) {
      Scrollable.ensureVisible(
        errors.first.context,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        alignment: .2,
      );
      return;
    }
    Navigator.pop(context, <String, String>{
      ...choices,
      for (final c in controllers.entries) c.key: c.value.text.trim(),
    });
  }

  Widget label(Field f) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      f.label,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    ),
  );

  Widget field(Field f) {
    final p = LedgerTheme.of(context);
    if (f.toggle) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(f.label, style: const TextStyle(fontSize: 14)),
        value: choices[f.key] == 'true',
        onChanged: (v) => setState(() => choices[f.key] = '$v'),
      );
    }
    if (f.options != null &&
        widget.quick &&
        f.key == 'category' &&
        f.options!.length <= 12) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(f),
          LayoutBuilder(
            builder: (context, box) {
              final columns = MediaQuery.textScalerOf(context).scale(14) > 22
                  ? 3
                  : 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in f.options!.entries)
                    SizedBox(
                      width: (box.maxWidth - (columns - 1) * 8) / columns,
                      child: Semantics(
                        button: true,
                        selected: choices[f.key] == e.key,
                        label: e.value,
                        onTap: () => setState(() => choices[f.key] = e.key),
                        child: ExcludeSemantics(
                          child: Material(
                            color: choices[f.key] == e.key ? p.accent : p.field,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  setState(() => choices[f.key] = e.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      categoryIcon(e.value),
                                      size: 24,
                                      color: choices[f.key] == e.key
                                          ? p.onAccent
                                          : p.secondary,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      e.value,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: choices[f.key] == e.key
                                            ? p.onAccent
                                            : p.text,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 12,
                                      child: choices[f.key] == e.key
                                          ? Icon(
                                              Icons.check,
                                              size: 12,
                                              color: p.onAccent,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
    }
    if (f.options != null) {
      return LedgerChoice(
        label: f.label,
        value: f.options![choices[f.key]] ?? '',
        icon: f.key.contains('category')
            ? Icons.grid_view_outlined
            : f.key == 'wallet' || f.key == 'to'
            ? Icons.account_balance_wallet_outlined
            : Icons.tune_outlined,
        onTap: () async {
          FocusManager.instance.primaryFocus?.unfocus();
          final value = await selectLedgerOption(
            context,
            f.label,
            f.options!,
            selected: choices[f.key],
            categories: f.key == 'category',
          );
          if (value != null && mounted) setState(() => choices[f.key] = value);
        },
      );
    }
    final hero = widget.quick && f.key == 'amount';
    final input = TextFormField(
      controller: controllers[f.key],
      focusNode: nodes[f.key],
      readOnly: f.date,
      maxLength: f.amount || f.date ? null : 300,
      textInputAction: TextInputAction.next,
      keyboardType: f.amount
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: hero
          ? p.amountStyle(42)
          : f.amount
          ? p.amountStyle(20)
          : null,
      decoration: InputDecoration(
        hintText: f.amount ? '0.00' : null,
        prefixText: f.amount ? '¥  ' : null,
        counterText: '',
        prefixStyle: TextStyle(fontSize: hero ? 26 : 18, color: p.secondary),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: hero ? 20 : 16,
        ),
        suffixIcon: f.date
            ? const Icon(Icons.calendar_month_outlined, size: 20)
            : null,
      ),
      onTap: !f.date
          ? null
          : () async {
              final chosen = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.tryParse(controllers[f.key]!.text) ??
                    DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (chosen != null && mounted)
                controllers[f.key]!.text = day(chosen);
            },
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return f.optional ? null : '请填写${f.label}';
        if (f.amount) {
          try {
            final amount = cents(text);
            if (hero && amount == 0) return '金额需大于 0';
          } catch (_) {
            return '请输入有效金额，最多两位小数';
          }
        }
        if (f.date && DateTime.tryParse(text) == null) return '请选择有效日期';
        return null;
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: label(f)),
        Semantics(label: f.label, child: input),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = LedgerTheme.of(context);
    final secondary = widget.quick
        ? widget.fields.where((f) => f.optional || f.key == 'photo').toList()
        : <Field>[];
    final primary = widget.fields.where((f) => !secondary.contains(f));
    return LedgerSheet(
      title: widget.title,
      footer: FilledButton(onPressed: save, child: Text(widget.submit)),
      child: Form(
        key: form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in primary)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: field(f),
              ),
            if (secondary.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: expanded,
                title: const Text('备注与图片', style: TextStyle(fontSize: 14)),
                children: [
                  for (final f in secondary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: field(f),
                    ),
                ],
              ),
            if (widget.hint.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  widget.title.contains('核对') ? '近期流水' : '填写说明',
                  style: TextStyle(fontSize: 13, color: p.secondary),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.hint,
                        style: TextStyle(
                          fontSize: 13,
                          color: p.secondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    this.selected,
    this.categories = false,
  });
  final String title;
  final Map<String, String> options;
  final String? selected;
  final bool categories;
  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  String query = '';
  String categoryPath = '';
  @override
  Widget build(BuildContext context) {
    final p = LedgerTheme.of(context);
    final all = widget.options.entries
        .where((e) => e.value.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final branchNames = <String>{};
    if (widget.categories && query.isEmpty) {
      for (final e in all) {
        if (categoryPath.isEmpty || e.key.startsWith('$categoryPath/')) {
          final rest = categoryPath.isEmpty
              ? e.key
              : e.key.substring(categoryPath.length + 1);
          branchNames.add(
            categoryPath.isEmpty
                ? rest.split('/').first
                : '$categoryPath/${rest.split('/').first}',
          );
        }
      }
    }
    final entries = widget.categories && query.isEmpty
        ? [for (final key in branchNames) MapEntry(key, key.split('/').last)]
        : all;
    return LedgerSheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.categories && categoryPath.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => setState(
                () => categoryPath = categoryPath.contains('/')
                    ? categoryPath.substring(0, categoryPath.lastIndexOf('/'))
                    : '',
              ),
              icon: const Icon(Icons.arrow_back),
              label: Text(categoryPath),
            ),
            if (widget.options.containsKey(categoryPath))
              TextButton(
                onPressed: () => Navigator.pop(context, categoryPath),
                child: const Text('使用当前分类'),
              ),
          ],
          if (widget.options.length > 6)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '搜索',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('无匹配结果')),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: e.key == widget.selected ? p.soft : p.surface,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: widget.categories
                      ? Icon(categoryIcon(e.value), color: p.accent)
                      : null,
                  title: Text(e.value, style: const TextStyle(fontSize: 14)),
                  selected: e.key == widget.selected,
                  selectedColor: p.text,
                  trailing: e.key == widget.selected
                      ? Icon(Icons.check_circle, color: p.accent)
                      : const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    if (widget.categories &&
                        query.isEmpty &&
                        widget.options.keys.any(
                          (k) => k.startsWith('${e.key}/'),
                        )) {
                      setState(() => categoryPath = e.key);
                    } else {
                      Navigator.pop(context, e.key);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
