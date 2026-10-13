import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme.dart';

enum VitalGaugeStatus { normal, high, low, noData }

class VitalPillGauge extends StatelessWidget {
  const VitalPillGauge({
    super.key,
    required this.value,
    required this.normalRangeMin,
    required this.normalRangeMax,
    required this.status,
    this.height = 78,
    this.width = 108,
    this.label,
    this.valueText,
    this.unitText,
    this.statusText,
    this.statusIcon,
    this.icon,
  });

  final double value;
  final double normalRangeMin;
  final double normalRangeMax;
  final VitalGaugeStatus status;
  final double height;
  final double width;
  final String? label;
  final String? valueText;
  final String? unitText;
  final String? statusText;
  final IconData? statusIcon;
  final IconData? icon;

  Color _statusColor() {
    switch (status) {
      case VitalGaugeStatus.normal:
        return const Color(0xFF4ADE80);
      case VitalGaugeStatus.high:
        return const Color(0xFF60A5FA);
      case VitalGaugeStatus.low:
        return const Color(0xFFF59E0B);
      case VitalGaugeStatus.noData:
        return const Color(0xFF6B7280);
    }
  }

  List<Color> _gradientColors() {
    switch (status) {
      case VitalGaugeStatus.normal:
        return const [Color(0xFF34D399), Color(0xFF2DD4BF), Color(0xFF60A5FA)];
      case VitalGaugeStatus.high:
        return const [Color(0xFF60A5FA), Color(0xFF5EEAD4), Color(0xFF93C5FD)];
      case VitalGaugeStatus.low:
        return const [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFCA5A5)];
      case VitalGaugeStatus.noData:
        return const [Color(0xFF4B5563), Color(0xFF6B7280)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isNoData = status == VitalGaugeStatus.noData;
    final statusColor = _statusColor();
    final trackColor = palette.secondaryText.withValues(alpha: 0.18);
    final pillWidth = 10.0;
    final docketWidth = 20.0;
    final pillHeight = height * 0.74;
    final rangeSpan = (normalRangeMax - normalRangeMin).abs();
    final normalized = rangeSpan <= 0 ? 0.0 : ((value - normalRangeMin) / rangeSpan).clamp(0.0, 1.0);
    final fillHeight = isNoData ? 0.0 : (0.18 + (normalized * 0.52)).clamp(0.18, 0.72) * pillHeight;
    final puckTop = isNoData ? null : ((pillHeight - fillHeight) - 8.0).clamp(0.0, pillHeight - 18.0);
    final valueDisplay = valueText ?? value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    final unitDisplay = unitText ?? '';
    final statusDisplay = statusText ??
        switch (status) {
          VitalGaugeStatus.normal => 'Normal',
          VitalGaugeStatus.high => 'Higher',
          VitalGaugeStatus.low => 'Lower',
          VitalGaugeStatus.noData => 'No data',
        };
    final badgeIcon = statusIcon ??
        switch (status) {
          VitalGaugeStatus.normal => Icons.check_rounded,
          VitalGaugeStatus.high => Icons.arrow_upward_rounded,
          VitalGaugeStatus.low => Icons.arrow_downward_rounded,
          VitalGaugeStatus.noData => Icons.remove_rounded,
        };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.secondaryText.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null || label != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 17, color: palette.secondaryText),
                        const SizedBox(width: 6),
                      ],
                      if (label != null)
                        Text(
                          label!,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: palette.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valueDisplay,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    if (unitDisplay.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unitDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isNoData ? palette.secondaryText.withValues(alpha: 0.35) : statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badgeIcon,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusDisplay,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isNoData ? palette.secondaryText : statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 22,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isNoData)
                  Container(
                    width: pillWidth,
                    height: pillHeight,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  )
                else ...[
                  Container(
                    width: pillWidth,
                    height: pillHeight,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: Container(
                      width: docketWidth,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: docketWidth,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: fillHeight),
                      duration: reduceMotion
                          ? Duration.zero
                          : ForgeMotion.vitalGauge,
                      curve: ForgeMotion.easeOut,
                      builder: (context, animatedHeight, _) => Container(
                        width: pillWidth,
                        height: animatedHeight,
                        margin: const EdgeInsets.only(bottom: 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _gradientColors(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (puckTop != null)
                    Positioned(
                      top: puckTop,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: statusColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
