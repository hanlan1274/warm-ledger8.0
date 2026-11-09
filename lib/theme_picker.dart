import 'package:flutter/material.dart';

import 'editor.dart';
import 'themes.dart';

Future<String?> selectLedgerTheme(BuildContext context, String selected) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LedgerSheet(
        title: '更换主题',
        child: Column(
          children: [
            for (final theme in LedgerTheme.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  selected: theme.id == selected,
                  child: Material(
                    color: LedgerTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context, theme.id),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ExcludeSemantics(
                              child: Container(
                                width: 88,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.background,
                                  border: Border.all(color: theme.divider),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: theme.assetGradient,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          theme.retro ? 4 : 8,
                                        ),
                                      ),
                                      child: Text(
                                        '123.45',
                                        style: theme.amountStyle(13),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        for (final color in [
                                          theme.accent,
                                          theme.orange,
                                          theme.purple,
                                        ])
                                          Expanded(
                                            child: Container(
                                              height: 6,
                                              margin: const EdgeInsets.only(
                                                right: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                theme.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (theme.id == selected)
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.check_circle,
                                  color: LedgerTheme.of(context).accent,
                                  size: 22,
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
        ),
      ),
    );
