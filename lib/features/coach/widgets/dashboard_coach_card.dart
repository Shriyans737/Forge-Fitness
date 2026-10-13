import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../coach_copy.dart';
import '../services/coach_engine.dart';

class DashboardCoachCard extends StatefulWidget {
  const DashboardCoachCard({
    required this.insights,
    required this.onOpen,
    required this.onInsightShown,
    super.key,
  });

  final List<CoachInsight> insights;
  final VoidCallback onOpen;
  final ValueChanged<CoachInsight> onInsightShown;

  @override
  State<DashboardCoachCard> createState() => _DashboardCoachCardState();
}

class _DashboardCoachCardState extends State<DashboardCoachCard> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _recordShown();
  }

  @override
  void didUpdateWidget(covariant DashboardCoachCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights.map((item) => item.id).join('|') !=
        widget.insights.map((item) => item.id).join('|')) {
      _index = 0;
      _recordShown();
    }
  }

  void _recordShown() {
    if (widget.insights.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.insights.isNotEmpty) {
        widget.onInsightShown(widget.insights[_index]);
      }
    });
  }

  void _change(int delta) {
    if (widget.insights.length < 2) return;
    setState(() {
      _index = (_index + delta) % widget.insights.length;
    });
    widget.onInsightShown(widget.insights[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final insight = widget.insights.isEmpty
        ? null
        : widget.insights[_index.clamp(0, widget.insights.length - 1)];
    final accent = insight?.tone == CoachTone.caution
        ? tokens.warning
        : insight?.tone == CoachTone.positive
        ? tokens.accentTeal
        : tokens.accentLime;
    return Semantics(
      button: true,
      label: insight == null
          ? CoachCopy.openCoach
          : '${CoachCopy.coachScreenTitle}: ${insight.title}',
      child: GestureDetector(
        onTap: widget.onOpen,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 100) return;
          _change(velocity < 0 ? 1 : -1);
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tokens.surfaceVariant.withValues(alpha: 0.98),
                  accent.withValues(alpha: 0.13),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(color: accent.withValues(alpha: 0.34)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
                    const SizedBox(width: 7),
                    Text(
                      CoachCopy.coachLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    if (widget.insights.length > 1)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _change(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            tooltip: CoachCopy.previousInsight,
                          ),
                          Text(
                            CoachCopy.replace(CoachCopy.insightCount, {
                              'current': '${_index + 1}',
                              'total': '${widget.insights.length}',
                            }),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _change(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            tooltip: CoachCopy.nextInsight,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: insight == null
                      ? Column(
                          key: const ValueKey('coach-empty'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CoachCopy.dashboardEmptyTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(CoachCopy.learningEmpty),
                          ],
                        )
                      : Column(
                          key: ValueKey(insight.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              insight.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(insight?.action ?? CoachCopy.meetCoach),
                    onPressed: widget.onOpen,
                    side: BorderSide(color: accent.withValues(alpha: 0.48)),
                    backgroundColor: accent.withValues(alpha: 0.13),
                    labelStyle: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
