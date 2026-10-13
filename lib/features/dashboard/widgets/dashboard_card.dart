import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';

class DashboardCard extends StatefulWidget {
  const DashboardCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(ForgeMotion.cardPadding),
    this.keyName,
    this.surfaceGradient,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? keyName;
  final Gradient? surfaceGradient;

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      key: widget.keyName == null ? null : ValueKey(widget.keyName),
      child: AnimatedScale(
        scale: _pressed && widget.onTap != null ? 0.98 : 1,
        duration: reduceMotion ? Duration.zero : ForgeMotion.short,
        curve: ForgeMotion.easeOutFast,
        child: Material(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(ForgeMotion.cardRadius),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null
                ? null
                : (value) {
                    if (_pressed != value) {
                      setState(() => _pressed = value);
                    }
                  },
            borderRadius: BorderRadius.circular(ForgeMotion.cardRadius),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(ForgeMotion.cardRadius - 1),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF8CFFE1).withValues(alpha: 0.13)
                      : tokens.border,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: tokens.textPrimary.withValues(alpha: 0.055),
                          blurRadius: ForgeSpacing.md,
                          offset: const Offset(0, ForgeSpacing.xxs),
                        ),
                      ],
              ),
              padding: const EdgeInsets.all(1),
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.surfaceGradient == null
                      ? tokens.surface
                      : null,
                  gradient: widget.surfaceGradient,
                  borderRadius: BorderRadius.circular(tokens.cardRadius - 1),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
