import 'package:flutter/material.dart';

import '../../theme.dart';

enum PillTagVariant { success, warning, neutral, accent }

class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    this.variant = PillTagVariant.neutral,
    this.icon,
  });

  final String label;
  final PillTagVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final (foreground, background) = switch (variant) {
      PillTagVariant.success => (tokens.success, tokens.surfaceVariant),
      PillTagVariant.warning => (tokens.warning, tokens.surfaceVariant),
      PillTagVariant.neutral => (tokens.textSecondary, tokens.surfaceVariant),
      PillTagVariant.accent => (tokens.accentTeal, tokens.surfaceVariant),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: ForgeSpacing.xl),
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.sm,
        vertical: ForgeSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.pillRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ForgeSpacing.sm, color: foreground),
            const SizedBox(width: ForgeSpacing.xxs),
          ],
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
