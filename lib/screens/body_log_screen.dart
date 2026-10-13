import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/body_log_model.dart';

class BodyLogScreen extends StatefulWidget {
  const BodyLogScreen({super.key});

  @override
  State<BodyLogScreen> createState() => _BodyLogScreenState();
}

class _BodyLogScreenState extends State<BodyLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Box<BodyLog> _bodyLogBox;

  @override
  void initState() {
    super.initState();
    _bodyLogBox = Hive.box<BodyLog>('bodyLogs');
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Log'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Add Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryTab(bodyLogBox: _bodyLogBox),
          _AddEntryTab(bodyLogBox: _bodyLogBox),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.bodyLogBox});

  final Box<BodyLog> bodyLogBox;

  @override
  Widget build(BuildContext context) {
    final entries = bodyLogBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final chartEntries = entries.take(30).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (chartEntries.length >= 2)
          SizedBox(
            height: 200,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: LineChart(
                  _buildWeightChart(context, chartEntries),
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Log more entries to see your trend',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No body log entries yet.'),
            ),
          )
        else ...[
          Text(
            'Recent entries',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.map((entry) => _BodyLogEntryCard(entry: entry)),
        ],
      ],
    );
  }

  LineChartData _buildWeightChart(BuildContext context, List<BodyLog> history) {
    final spots = <FlSpot>[];
    final minX = 0.0;
    final maxX = (history.length - 1).toDouble();

    for (int i = 0; i < history.length; i++) {
      final entry = history[i];
      final weight = entry.weightKg;
      if (weight == null) {
        continue;
      }
      spots.add(FlSpot(i.toDouble(), weight));
    }

    final allWeights = history
        .map((entry) => entry.weightKg)
        .whereType<double>()
        .toList();
    final minY = allWeights.isNotEmpty ? allWeights.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxY = allWeights.isNotEmpty ? allWeights.reduce((a, b) => a > b ? a : b) : 1.0;
    final range = (maxY - minY).abs();
    final yMin = minY - (range == 0 ? 1 : range * 0.1);
    final yMax = maxY + (range == 0 ? 1 : range * 0.1);

    return LineChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: (history.length > 1 ? (history.length - 1) / 3 : 1).toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= history.length) {
                return const SizedBox.shrink();
              }
              final date = history[index].date;
              return Text(
                DateFormat('M/d').format(date),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      minX: minX,
      maxX: maxX,
      minY: yMin,
      maxY: yMax,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          color: Theme.of(context).colorScheme.primary,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class _BodyLogEntryCard extends StatelessWidget {
  const _BodyLogEntryCard({required this.entry});

  final BodyLog entry;

  @override
  Widget build(BuildContext context) {
    final measurementSummary = entry.measurements == null || entry.measurements!.isEmpty
        ? 'No measurements logged'
        : entry.measurements!.entries
            .where((item) => item.value > 0)
            .map((item) => '${item.key}: ${item.value.toStringAsFixed(0)}cm')
            .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMM d, yyyy').format(entry.date),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (entry.weightKg != null)
              Text(
                '${entry.weightKg!.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.labelLarge,
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            measurementSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showEditDialog(context, entry);
        },
        onLongPress: () {
          _deleteEntry(context, entry);
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, BodyLog entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _BodyLogEntryEditor(entry: entry),
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context, BodyLog entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This will remove the body log entry permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Hive.box<BodyLog>('bodyLogs').delete(entry.id);
    }
  }
}

class _BodyLogEntryEditor extends StatefulWidget {
  const _BodyLogEntryEditor({required this.entry});

  final BodyLog entry;

  @override
  State<_BodyLogEntryEditor> createState() => _BodyLogEntryEditorState();
}

class _BodyLogEntryEditorState extends State<_BodyLogEntryEditor> {
  late DateTime _selectedDate;
  late final TextEditingController _weightController;
  final Map<String, TextEditingController> _measurementControllers = {};
  late final TextEditingController _notesController;
  final List<String> _measurementKeys = const [
    'chest',
    'waist',
    'hips',
    'arms',
    'thighs',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry.date;
    _weightController = TextEditingController(
      text: widget.entry.weightKg == null ? '' : widget.entry.weightKg!.toStringAsFixed(1),
    );
    _notesController = TextEditingController(text: widget.entry.notes ?? '');

    for (final key in _measurementKeys) {
      final value = widget.entry.measurements?[key];
      _measurementControllers[key] = TextEditingController(
        text: value == null ? '' : value.toStringAsFixed(1),
      );
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    final measurements = <String, double>{};
    for (final key in _measurementKeys) {
      final valueText = _measurementControllers[key]!.text.trim();
      if (valueText.isEmpty) {
        continue;
      }
      final value = double.tryParse(valueText);
      if (value != null) {
        measurements[key] = value;
      }
    }

    if (weight == null && measurements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a weight or at least one measurement.')),
      );
      return;
    }

    final updated = BodyLog(
      id: widget.entry.id,
      date: _selectedDate,
      weightKg: weight,
      measurements: measurements.isEmpty ? null : measurements,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    Hive.box<BodyLog>('bodyLogs').put(updated.id, updated);
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entry'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                    ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Measurements (cm)'),
            const SizedBox(height: 8),
            ..._measurementKeys.map((key) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _measurementControllers[key],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: key[0].toUpperCase() + key.substring(1),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEntryTab extends StatefulWidget {
  const _AddEntryTab({required this.bodyLogBox});

  final Box<BodyLog> bodyLogBox;

  @override
  State<_AddEntryTab> createState() => _AddEntryTabState();
}

class _AddEntryTabState extends State<_AddEntryTab> {
  late DateTime _selectedDate;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, TextEditingController> _measurementControllers = {
    'chest': TextEditingController(),
    'waist': TextEditingController(),
    'hips': TextEditingController(),
    'arms': TextEditingController(),
    'thighs': TextEditingController(),
  };
  bool _showMeasurements = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    for (final controller in _measurementControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _save() {
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);

    final measurements = <String, double>{};
    for (final entry in _measurementControllers.entries) {
      final valueText = entry.value.text.trim();
      if (valueText.isEmpty) {
        continue;
      }
      final value = double.tryParse(valueText);
      if (value != null) {
        measurements[entry.key] = value;
      }
    }

    if (weight == null && measurements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a weight or at least one measurement before saving.')),
      );
      return;
    }

    final entry = BodyLog(
      date: _selectedDate,
      weightKg: weight,
      measurements: measurements.isEmpty ? null : measurements,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    widget.bodyLogBox.put(entry.id, entry);

    _weightController.clear();
    _notesController.clear();
    for (final controller in _measurementControllers.values) {
      controller.clear();
    }
    setState(() {
      _selectedDate = DateTime.now();
      _showMeasurements = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Body log saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                ),
                const Icon(Icons.calendar_today_outlined),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Add measurements'),
          initiallyExpanded: _showMeasurements,
          onExpansionChanged: (expanded) => setState(() => _showMeasurements = expanded),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: _measurementControllers.entries.map((entry) {
                  final label = entry.key[0].toUpperCase() + entry.key.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: entry.value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '$label (cm)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save body log'),
        ),
      ],
    );
  }
}
