import 'dart:math';
import 'package:flutter/material.dart';

import 'themes.dart';

class SheetCard extends StatelessWidget {
  const SheetCard({super.key, required this.child, this.color, this.gradient});
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: color ?? LedgerTheme.of(context).surface,
      gradient: gradient,
      borderRadius: BorderRadius.circular(
        LedgerTheme.of(context).retro ? 10 : 16,
      ),
      border: Border.all(color: LedgerTheme.of(context).divider),
    ),
    child: child,
  );
}

class Donut extends StatelessWidget {
  const Donut({
    super.key,
    required this.values,
    required this.colors,
    required this.label,
  });
  final List<int> values;
  final List<Color> colors;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      width: 112,
      height: 112,
      child: CustomPaint(
        painter: _Donut(values, colors, LedgerTheme.of(context).soft),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: LedgerTheme.of(context).text),
          ),
        ),
      ),
    ),
  );
}

class _Donut extends CustomPainter {
  _Donut(this.values, this.colors, this.track);
  final Color track;
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    final sum = values.fold(0, (a, b) => a + max(0, b));
    var start = -pi / 2;
    if (sum == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
    }
    for (var i = 0; i < values.length && sum > 0; i++) {
      final sweep = max(0, values[i]) / sum * 2 * pi;
      final gap = min(.055, sweep / 3);
      if (sweep > 0 && colors.isNotEmpty)
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap = StrokeCap.round,
        );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => true;
}

class Trend extends StatelessWidget {
  const Trend({super.key, required this.values, required this.labels});
  final List<int> values;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final palette = LedgerTheme.of(context);
    final ceiling = max(1, values.fold(0, max));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '支出 / 元',
            style: TextStyle(color: palette.secondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(12) > 20 ? 170 : 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              values.length,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        FittedBox(
                          child: Text(
                            (values[i] / 100).toStringAsFixed(0),
                            style: palette.amountStyle(12),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Tooltip(
                        message:
                            '${labels[i]} · ¥${(values[i] / 100).toStringAsFixed(2)}',
                        child: Container(
                          height: max(3.0, values[i] / ceiling * 72),
                          decoration: BoxDecoration(
                            color: i == values.length - 1
                                ? palette.accent
                                : palette.accent.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      FittedBox(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class InteractiveTrend extends StatelessWidget {
  const InteractiveTrend({
    super.key,
    required this.values,
    required this.labels,
    required this.lineMode,
    required this.onSelect,
  });
  final List<int> values;
  final List<String> labels;
  final bool lineMode;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final p = LedgerTheme.of(context);
    if (values.isEmpty) return const Text('暂无数据');
    return LayoutBuilder(
      builder: (context, box) {
        final width = max(box.maxWidth, values.length * 44.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '支出 / 元 · 点击查看流水',
              style: TextStyle(color: p.secondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    if (lineMode)
                      SizedBox(
                        height: 100,
                        width: width,
                        child: CustomPaint(
                          painter: _LineTrend(values, p.accent, p.divider),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        values.length,
                        (i) => Expanded(
                          child: Semantics(
                            label: '${labels[i]}支出${values[i] / 100}元',
                            button: true,
                            child: InkWell(
                              onTap: () => onSelect(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      child: Text(
                                        (values[i] / 100).toStringAsFixed(0),
                                        style: p.amountStyle(12),
                                      ),
                                    ),
                                    if (!lineMode) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        height: max(
                                          2.0,
                                          values[i] /
                                              max(1, values.fold(0, max)) *
                                              84,
                                        ),
                                        decoration: BoxDecoration(
                                          color: p.accent,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      labels[i],
                                      style: TextStyle(
                                        color: p.secondary,
                                        fontSize: 12,
                                      ),
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineTrend extends CustomPainter {
  _LineTrend(this.values, this.color, this.grid);
  final List<int> values;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i <= 2; i++) {
      final y = 8 + i * (size.height - 16) / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = grid,
      );
    }
    final ceiling = max(1, values.fold(0, max));
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i + .5) * size.width / values.length;
      final y = size.height - 8 - values[i] / ceiling * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LineTrend oldDelegate) => true;
}
