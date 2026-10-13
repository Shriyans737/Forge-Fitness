import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/progress_repository.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({
    required this.exerciseId,
    required this.exerciseName,
    super.key,
  });

  final String exerciseId;
  final String exerciseName;

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  late final Future<ExerciseProgressHistory> _historyFuture;
  String _range = 'All';
  ProgressMetric _metric = ProgressMetric.estimatedOneRepMax;
  ExerciseProgressSession? _selectedSession;

  @override
  void initState() {
    super.initState();
    _historyFuture = ProgressRepository.historyFor(
      exerciseId: widget.exerciseId,
      exerciseName: widget.exerciseName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.exerciseName} Progress')),
      body: FutureBuilder<ExerciseProgressHistory>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Progress history is unavailable.'));
          }
          return _buildHistory(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildHistory(BuildContext context, ExerciseProgressHistory history) {
    final filteredSessions = _filterSessions(history.sessions);
    final metric = history.isBodyweight
        ? ProgressMetric.bestReps
        : _metric;
    final points = filteredSessions
        .where((session) => session.valueFor(metric) != null)
        .toList(growable: false);
    final selectedSession = points.contains(_selectedSession)
        ? _selectedSession!
        : (points.isEmpty ? null : points.last);
    final palette = Theme.of(context).extension<AppThemePalette>() ??
        AppThemePalette.light;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCards(context, history),
          const SizedBox(height: 12),
          if (history.sessions.length >= 2) ...[
            _changeIndicator(context, points, metric),
            const SizedBox(height: 20),
            _rangePicker(),
            if (!history.isBodyweight) ...[
              const SizedBox(height: 12),
              _metricPicker(),
            ],
            const SizedBox(height: 12),
            _progressChart(context, points, metric, palette),
            if (selectedSession != null) ...[
              const SizedBox(height: 12),
              _sessionDetails(context, selectedSession),
            ],
          ] else
            _emptyState(context),
          const SizedBox(height: 24),
          _personalRecords(context, history),
        ],
      ),
    );
  }

  List<ExerciseProgressSession> _filterSessions(
    List<ExerciseProgressSession> sessions,
  ) {
    final months = switch (_range) {
      '1M' => 1,
      '3M' => 3,
      '6M' => 6,
      _ => null,
    };
    if (months == null) {
      return sessions;
    }
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return sessions.where((session) => !session.date.isBefore(cutoff)).toList();
  }

  Widget _summaryCards(
    BuildContext context,
    ExerciseProgressHistory history,
  ) {
    final values = history.sessions;
    final bestOneRepMax = history.personalRecords
        .where((record) => record.type == ProgressPrType.estimatedOneRepMax)
        .fold<double?>(null, (best, record) =>
            best == null || record.value > best ? record.value : best);
    final bestReps = values.fold<int?>(null, (best, session) =>
        best == null || (session.bestReps ?? 0) > best
            ? session.bestReps
            : best);
    final heaviest = values.fold<double?>(null, (best, session) {
      final weight = session.topSetWeight;
      return weight == null || (best != null && best >= weight) ? best : weight;
    });
    final width = (MediaQuery.sizeOf(context).width - 44) / 2;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: width,
          child: _StatCard(
            label: history.isBodyweight ? 'Best reps' : 'Current best 1RM',
            value: history.isBodyweight
                ? '${bestReps ?? 0} reps'
                : '${_formatNumber(bestOneRepMax ?? 0)} kg',
          ),
        ),
        SizedBox(
          width: width,
          child: _StatCard(
            label: 'Heaviest weight',
            value: history.isBodyweight
                ? 'Bodyweight'
                : '${_formatNumber(heaviest ?? 0)} kg',
          ),
        ),
        SizedBox(
          width: width,
          child: _StatCard(
            label: 'Total sessions',
            value: '${history.sessions.length}',
          ),
        ),
      ],
    );
  }

  Widget _changeIndicator(
    BuildContext context,
    List<ExerciseProgressSession> points,
    ProgressMetric metric,
  ) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    final first = points.first;
    final last = points.last;
    final start = first.valueFor(metric)!;
    final end = last.valueFor(metric)!;
    final change = end - start;
    final durationDays = last.date.difference(first.date).inDays;
    final duration = durationDays >= 60
        ? '${(durationDays / 30).round()} months'
        : durationDays >= 14
            ? '${(durationDays / 7).round()} weeks'
            : '$durationDays days';
    final unit = _metricUnit(metric);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.trending_up, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_formatNumber(start)} -> ${_formatNumber(end)} $unit '
                '(${change >= 0 ? '+' : ''}${_formatNumber(change)} $unit) '
                'in $duration',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangePicker() => Wrap(
    spacing: 8,
    children: ['1M', '3M', '6M', 'All'].map((range) {
      return ChoiceChip(
        label: Text(range),
        selected: _range == range,
        onSelected: (_) => setState(() {
          _range = range;
          _selectedSession = null;
        }),
      );
    }).toList(growable: false),
  );

  Widget _metricPicker() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      (ProgressMetric.estimatedOneRepMax, 'Estimated 1RM'),
      (ProgressMetric.topSet, 'Top set'),
      (ProgressMetric.volume, 'Volume'),
    ].map((option) {
      return ChoiceChip(
        label: Text(option.$2),
        selected: _metric == option.$1,
        onSelected: (_) => setState(() {
          _metric = option.$1;
          _selectedSession = null;
        }),
      );
    }).toList(growable: false),
  );

  Widget _progressChart(
    BuildContext context,
    List<ExerciseProgressSession> points,
    ProgressMetric metric,
    AppThemePalette palette,
  ) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    final values = points.map((point) => point.valueFor(metric)!).toList();
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final padding = math.max((maximum - minimum) * 0.15, 1.0);
    final lineColors = palette.heroGradient.colors;
    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), values[index]),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: SizedBox(
          height: 228,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(1, points.length - 1).toDouble(),
              minY: minimum - padding,
              maxY: maximum + padding,
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (points.length - 1) / 3).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('M/d').format(points[index].date),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback: (event, response) {
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) {
                    return;
                  }
                  final index = spots.first.x.round();
                  if (index >= 0 && index < points.length) {
                    setState(() => _selectedSession = points[index]);
                  }
                },
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  gradient: palette.heroGradient,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        lineColors.first.withValues(alpha: 0.22),
                        lineColors.last.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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

  Widget _sessionDetails(
    BuildContext context,
    ExerciseProgressSession session,
  ) {
    final visibleSets = session.sets.where((set) => set.reps > 0).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM d, yyyy').format(session.date),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (visibleSets.isEmpty)
              const Text('No sets logged.')
            else
              ...visibleSets.asMap().entries.map((entry) {
                final set = entry.value;
                final label = set.weight == null || set.weight == 0
                    ? 'Bodyweight'
                    : '${_formatNumber(set.weight!)} kg';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${set.isWarmUp ? 'Warm-up' : 'Set ${entry.key + 1}'}: '
                    '$label x ${set.reps} reps',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.show_chart,
            size: 34,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Log this exercise a couple more times to see your progress',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );

  Widget _personalRecords(
    BuildContext context,
    ExerciseProgressHistory history,
  ) {
    final records = history.personalRecords.where((record) {
      if (history.isBodyweight) {
        return record.type == ProgressPrType.repsAtWeight;
      }
      return true;
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal records',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (records.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No personal records yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...records.map((record) => _prTile(context, record, history)),
      ],
    );
  }

  Widget _prTile(
    BuildContext context,
    ProgressPr record,
    ExerciseProgressHistory history,
  ) {
    final label = switch (record.type) {
      ProgressPrType.heaviestWeight => 'Heaviest weight',
      ProgressPrType.estimatedOneRepMax => 'Estimated 1RM',
      ProgressPrType.repsAtWeight => history.isBodyweight
          ? 'Most reps at bodyweight'
          : 'Most reps at ${_formatNumber(record.weight ?? 0)} kg',
    };
    final value = record.type == ProgressPrType.repsAtWeight
        ? '${record.value.toInt()} reps'
        : '${_formatNumber(record.value)} kg';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text(DateFormat('MMM d, yyyy').format(record.date)),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _metricUnit(ProgressMetric metric) => switch (metric) {
    ProgressMetric.bestReps => 'reps',
    ProgressMetric.volume => 'kg',
    ProgressMetric.estimatedOneRepMax || ProgressMetric.topSet => 'kg',
  };

  String _formatNumber(num value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}