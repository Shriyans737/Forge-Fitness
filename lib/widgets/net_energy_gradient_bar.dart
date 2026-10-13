import 'package:flutter/material.dart';

import '../theme.dart';

class NetEnergyGradientBar extends StatelessWidget {
  const NetEnergyGradientBar({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.height = 16,
  });

  final double value;
  final double min;
  final double max;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final span = (max - min).abs() < 0.0001 ? 1.0 : (max - min);
    final normalized = ((value - min) / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFB923C),
                    Color(0xFFE5E7EB),
                    Color(0xFF60A5FA),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Positioned(
              left: 8 + normalized * 200,
              top: -4,
              child: Container(
                width: 2,
                height: height + 8,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.round()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
            Text(
              '${value.round()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${max.round()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
