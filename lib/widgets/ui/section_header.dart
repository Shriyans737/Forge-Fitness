import 'package:flutter/material.dart';

import '../../theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.textPrimary,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: ForgeSpacing.xs),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(ForgeSpacing.xxl, ForgeSpacing.xxl),
              foregroundColor: tokens.accentTeal,
              padding: const EdgeInsets.symmetric(horizontal: ForgeSpacing.xs),
            ),
            child: Text(
              actionLabel!,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ],
    );
  }
}
