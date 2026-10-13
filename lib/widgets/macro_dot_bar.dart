import 'package:flutter/material.dart';

class MacroDotBar extends StatelessWidget {
  const MacroDotBar({
    super.key,
    required this.color,
    required this.progress,
    required this.label,
    this.columns = 8,
    this.rows = 10,
  });

  final Color color;
  final double progress;
  final String label;
  final int columns;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final totalDots = columns * rows;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final filledDots = (clampedProgress * totalDots).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: totalDots,
          itemBuilder: (context, index) {
            final bottomUpIndex = totalDots - index - 1;
            final isFilled = bottomUpIndex < filledDots;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: isFilled ? color : Colors.transparent,
                border: Border.all(
                  color: isFilled ? color : Colors.white.withValues(alpha: 0.18),
                  width: isFilled ? 0 : 1.2,
                ),
                shape: BoxShape.circle,
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.38),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
