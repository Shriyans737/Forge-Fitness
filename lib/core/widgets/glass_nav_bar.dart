import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../../theme.dart';
import '../../widgets/ui/floating_bottom_nav.dart';

class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.reduceMotion = false,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool reduceMotion;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selection = AnimationController(
    vsync: this,
    duration: ForgeMotion.tabSelection,
    value: 1,
  );
  int _previousIndex = 0;
  Offset? _fingerPosition;

  @override
  void didUpdateWidget(covariant GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _selection
        ..stop()
        ..value = widget.reduceMotion ? 1 : 0;
      if (!widget.reduceMotion) _selection.forward();
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _updateFinger(PointerEvent event) {
    setState(() => _fingerPosition = event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final safeIndex = widget.selectedIndex.clamp(0, widget.items.length - 1);
    return RepaintBoundary(
      child: Listener(
        onPointerDown: _updateFinger,
        onPointerMove: _updateFinger,
        onPointerUp: (_) => setState(() => _fingerPosition = null),
        onPointerCancel: (_) => setState(() => _fingerPosition = null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ForgeMotion.navPillRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: ForgeMotion.navGlassBlur,
              sigmaY: ForgeMotion.navGlassBlur,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _selection,
                builder: (context, _) {
                  final t = ForgeMotion.tabBubbleCurve.transform(
                    _selection.value,
                  );
                  final stretch = (t / ForgeMotion.navStretchFraction).clamp(
                    0.0,
                    1.0,
                  );
                  final settle =
                      ((t - ForgeMotion.navStretchFraction) /
                              (1 - ForgeMotion.navStretchFraction))
                          .clamp(0.0, 1.0);
                  final start = math.min(_previousIndex, safeIndex);
                  final end = math.max(_previousIndex, safeIndex);
                  final contentWidth = constraints.maxWidth - 12;
                  final slotWidth = contentWidth / widget.items.length;
                  final startLeft = 6 + start * slotWidth;
                  final endLeft = 6 + end * slotWidth;
                  final targetLeft = 6 + safeIndex * slotWidth;
                  final stretchLeft = _previousIndex < safeIndex
                      ? startLeft
                      : startLeft + (endLeft - startLeft) * (1 - stretch);
                  final stretchWidth =
                      slotWidth * (1 + (end - start) * stretch);
                  final capsuleLeft =
                      _selection.value < ForgeMotion.navStretchFraction
                      ? stretchLeft
                      : stretchLeft + (targetLeft - stretchLeft) * settle;
                  final capsuleWidth =
                      _selection.value < ForgeMotion.navStretchFraction
                      ? stretchWidth
                      : stretchWidth + (slotWidth - stretchWidth) * settle;
                  final squash =
                      _selection.value < ForgeMotion.navStretchFraction
                      ? 1 - 0.14 * stretch
                      : 0.86 + 0.14 * settle;
                  final iconScale =
                      _selection.isAnimating &&
                          safeIndex >= 0 &&
                          safeIndex < widget.items.length
                      ? _iconBounce(_selection.value)
                      : 1.0;

                  return Container(
                    height: ForgeMotion.navBarHeight,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(22, 40, 38, 0.38),
                      borderRadius: BorderRadius.circular(
                        ForgeMotion.navPillRadius,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x70000000),
                          blurRadius: 44,
                          spreadRadius: -12,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_fingerPosition case final finger?)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      finger.dx / constraints.maxWidth * 2 - 1,
                                      -1.35,
                                    ),
                                    radius: 0.85,
                                    colors: const [
                                      Color.fromRGBO(255, 255, 255, 0.22),
                                      Color.fromRGBO(255, 255, 255, 0.035),
                                      Color.fromRGBO(255, 255, 255, 0),
                                    ],
                                    stops: const [0, 0.45, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: capsuleLeft,
                          top: 6,
                          width: capsuleWidth,
                          height: ForgeMotion.navBubbleHeight,
                          child: IgnorePointer(
                            child: Transform.scale(
                              scaleY: squash,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    ForgeMotion.navPillRadius,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      tokens.accentTeal.withValues(alpha: 0.26),
                                      tokens.accentLime.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.accentTeal.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: -4,
                                    ),
                                    const BoxShadow(
                                      color: Color(0x66FFFFFF),
                                      blurRadius: 3,
                                      offset: Offset(0, -1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color.fromRGBO(255, 255, 255, 0.095),
                                    Color.fromRGBO(255, 255, 255, 0.025),
                                    Color.fromRGBO(255, 255, 255, 0.04),
                                  ],
                                  stops: [0, 0.16, 1],
                                ),
                                borderRadius: BorderRadius.circular(
                                  ForgeMotion.navPillRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: List.generate(widget.items.length, (
                              index,
                            ) {
                              final item = widget.items[index];
                              final selected = safeIndex == index;
                              final color = selected
                                  ? const Color(0xFFE8F5F1)
                                  : Colors.white.withValues(alpha: 0.62);
                              final scale = selected ? iconScale : 1.0;
                              return Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: selected,
                                  label: item.badgeCount > 0
                                      ? '${item.label}, ${item.badgeCount} incoming requests'
                                      : item.label,
                                  child: InkWell(
                                    onTap: () => widget.onTap(index),
                                    borderRadius: BorderRadius.circular(
                                      ForgeMotion.navPillRadius,
                                    ),
                                    child: SizedBox(
                                      height: ForgeMotion.navBarHeight - 12,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.scale(
                                            scale: scale,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Icon(
                                                  selected
                                                      ? item.selectedIcon ??
                                                            item.icon
                                                      : item.icon,
                                                  size: ForgeMotion.navIconSize,
                                                  color: color,
                                                ),
                                                if (item.badgeCount > 0)
                                                  Positioned(
                                                    right: -8,
                                                    top: -6,
                                                    child: Container(
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 15,
                                                            minHeight: 15,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 3,
                                                          ),
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE64A53,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              99,
                                                            ),
                                                        border: Border.all(
                                                          color: tokens.surface,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        item.badgeCount > 99
                                                            ? '99+'
                                                            : '${item.badgeCount}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          height: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.label,
                                            maxLines: 1,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: color,
                                                  fontSize:
                                                      ForgeMotion.navLabelSize,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _iconBounce(double value) {
    if (value < 0.55) return 0.7 + 0.48 * (value / 0.55);
    return 1.18 - 0.18 * ((value - 0.55) / 0.45);
  }
}
