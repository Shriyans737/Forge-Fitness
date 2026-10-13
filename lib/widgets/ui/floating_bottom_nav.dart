import 'package:flutter/material.dart';

import '../../theme.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int badgeCount;
}

class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  }) : assert(items.length > 0);

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final textTheme = Theme.of(context).textTheme;
    final safeIndex = selectedIndex.clamp(0, items.length - 1);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        ForgeSpacing.md,
        ForgeSpacing.xs,
        ForgeSpacing.md,
        ForgeSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(ForgeSpacing.xs),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.pillRadius),
          border: Border.all(color: tokens.border),
          boxShadow: [
            BoxShadow(
              color: tokens.textPrimary.withValues(alpha: 0.08),
              blurRadius: ForgeSpacing.lg,
              offset: const Offset(0, ForgeSpacing.xs),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == safeIndex;
            final foreground =
                selected ? tokens.accentTeal : tokens.textSecondary;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: Material(
                  color: tokens.surface.withValues(alpha: 0),
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(tokens.pillRadius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(
                        minHeight: ForgeSpacing.xxxl,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: ForgeSpacing.xxs,
                        vertical: ForgeSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? tokens.surfaceVariant
                            : tokens.surface.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(tokens.pillRadius),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                selected
                                    ? (item.selectedIcon ?? item.icon)
                                    : item.icon,
                                size: ForgeSpacing.lg,
                                color: foreground,
                              ),
                              if (item.badgeCount > 0)
                                Positioned(
                                  right: -8,
                                  top: -5,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 15,
                                      minHeight: 15,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE64A53),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: tokens.surface,
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item.badgeCount > 99
                                          ? '99+'
                                          : '${item.badgeCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: ForgeSpacing.xxs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              style: textTheme.labelSmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
