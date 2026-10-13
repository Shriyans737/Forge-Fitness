import 'package:flutter/material.dart';

import '../../theme.dart';
import 'shimmer_box.dart';

class PrimaryGradientButton extends StatefulWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<PrimaryGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final contentColor = Theme.of(context).colorScheme.onPrimary;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final buttonGradient = enabled
        ? tokens.primaryGradient
        : LinearGradient(
            colors: tokens.primaryGradient.colors
                .map((color) => color.withValues(alpha: 0.55))
                .toList(),
            begin: tokens.primaryGradient.begin,
            end: tokens.primaryGradient.end,
          );

    return SizedBox(
      width: widget.expand ? double.infinity : null,
      height: ForgeSpacing.xxxl - ForgeSpacing.xs,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            onHighlightChanged: (highlighted) {
              if (enabled && _pressed != highlighted) {
                setState(() => _pressed = highlighted);
              }
            },
            borderRadius: BorderRadius.circular(tokens.controlRadius),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: buttonGradient,
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                child: Center(
                  child: widget.isLoading
                      ? ShimmerBox(
                          width: ForgeSpacing.xxxl,
                          height: ForgeSpacing.sm,
                          borderRadius: tokens.pillRadius,
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ForgeSpacing.lg,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, color: contentColor),
                                const SizedBox(width: ForgeSpacing.xs),
                              ],
                              Flexible(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: contentColor),
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
      ),
    );
  }
}
