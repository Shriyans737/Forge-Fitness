import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';

import '../data/muscle_name_mapping.dart';
import 'ui/shimmer_box.dart';

class MuscleMapWidget extends StatelessWidget {
  const MuscleMapWidget({
    required this.primaryMuscles,
    required this.secondaryMuscles,
    this.primaryColor,
    this.secondaryColor,
    this.untargetedColor,
    super.key,
  });

  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? untargetedColor;

  Set<Muscle> get _primary => resolveExerciseMuscles(primaryMuscles);

  Set<Muscle> get _secondary {
    final secondary = resolveExerciseMuscles(secondaryMuscles);
    secondary.removeAll(_primary);
    return secondary;
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final secondary = _secondary;

    if (primary.isEmpty && secondary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BodyView(
                  label: 'Front',
                  isFront: true,
                  primaryMuscles: primary,
                  secondaryMuscles: secondary,
                  primaryColor: primaryColor ?? _primaryColor,
                  secondaryColor: secondaryColor ?? _secondaryColor,
                  untargetedColor: untargetedColor ?? _untargetedColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BodyView(
                  label: 'Back',
                  isFront: false,
                  primaryMuscles: primary,
                  secondaryMuscles: secondary,
                  primaryColor: primaryColor ?? _primaryColor,
                  secondaryColor: secondaryColor ?? _secondaryColor,
                  untargetedColor: untargetedColor ?? _untargetedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MuscleMapLegend(
            primaryColor: primaryColor ?? _primaryColor,
            secondaryColor: secondaryColor ?? _secondaryColor,
            untargetedColor: untargetedColor ?? _untargetedColor,
          ),
        ],
      ),
    );
  }
}

class _BodyView extends StatelessWidget {
  const _BodyView({
    required this.label,
    required this.isFront,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.primaryColor,
    required this.secondaryColor,
    required this.untargetedColor,
  });

  final String label;
  final bool isFront;
  final Set<Muscle> primaryMuscles;
  final Set<Muscle> secondaryMuscles;
  final Color primaryColor;
  final Color secondaryColor;
  final Color untargetedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 230,
          child: _ColoredBodySvg(
            isFront: isFront,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            untargetedColor: untargetedColor,
          ),
        ),
      ],
    );
  }
}

class _ColoredBodySvg extends StatefulWidget {
  const _ColoredBodySvg({
    required this.isFront,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.primaryColor,
    required this.secondaryColor,
    required this.untargetedColor,
  });

  final bool isFront;
  final Set<Muscle> primaryMuscles;
  final Set<Muscle> secondaryMuscles;
  final Color primaryColor;
  final Color secondaryColor;
  final Color untargetedColor;

  @override
  State<_ColoredBodySvg> createState() => _ColoredBodySvgState();
}

class _ColoredBodySvgState extends State<_ColoredBodySvg> {
  late Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture = _loadSvg();
  }

  @override
  void didUpdateWidget(covariant _ColoredBodySvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFront != widget.isFront ||
        !_sameMuscles(oldWidget.primaryMuscles, widget.primaryMuscles) ||
        !_sameMuscles(oldWidget.secondaryMuscles, widget.secondaryMuscles) ||
        oldWidget.primaryColor != widget.primaryColor ||
        oldWidget.secondaryColor != widget.secondaryColor ||
        oldWidget.untargetedColor != widget.untargetedColor) {
      _svgFuture = _loadSvg();
    }
  }

  Future<String> _loadSvg() async {
    final view = widget.isFront ? 'front' : 'back';
    final source = await rootBundle.loadString(
      'packages/flutter_body_part_selector/assets/svg/body_$view.svg',
    );
    return _colorSvg(source);
  }

  String _colorSvg(String source) {
    final document = XmlDocument.parse(source);
    final regions = document.descendants.whereType<XmlElement>();

    for (final region in regions) {
      final id = region.getAttribute('id');
      if (id == null) {
        continue;
      }

      if (id == 'front_body' || id == 'back_body') {
        region
          ..setAttribute('fill', 'none')
          ..setAttribute('stroke', '#777777')
          ..setAttribute('stroke-width', '2');
        continue;
      }

      final muscle = _svgIdToMuscle[id];
      if (muscle == null) {
        continue;
      }

      final color = widget.primaryMuscles.contains(muscle)
          ? _colorToHex(widget.primaryColor)
          : widget.secondaryMuscles.contains(muscle)
          ? _colorToHex(widget.secondaryColor)
          : _colorToHex(widget.untargetedColor);

      region
        ..setAttribute('fill', color)
        ..setAttribute('stroke', color)
        ..setAttribute('stroke-width', '1.2');
    }

    return document.toXmlString(pretty: false);
  }

  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return const Icon(Icons.broken_image_outlined);
          }
          return const Center(child: ShimmerBox(width: 128, height: 210));
        }

        return SvgPicture.string(
          snapshot.data!,
          width: double.infinity,
          height: 230,
          fit: BoxFit.contain,
        );
      },
    );
  }

  bool _sameMuscles(Set<Muscle> first, Set<Muscle> second) =>
      first.length == second.length && first.containsAll(second);
}

class _MuscleMapLegend extends StatelessWidget {
  const _MuscleMapLegend({
    required this.primaryColor,
    required this.secondaryColor,
    required this.untargetedColor,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color untargetedColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendItem(color: primaryColor, label: 'Primary Muscles'),
        _LegendItem(color: secondaryColor, label: 'Secondary Muscles'),
        _LegendItem(color: untargetedColor, label: 'Untargeted Muscles'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

const _primaryColor = Color(0xFFD9473F);
const _secondaryColor = Color(0xFFF2C84B);
const _untargetedColor = Color(0xFF3A3A3A);
const _svgIdToMuscle = <String, Muscle>{
  'traps_left': Muscle.trapsLeft,
  'traps_right': Muscle.trapsRight,
  'delts_left': Muscle.deltsLeft,
  'delts_right': Muscle.deltsRight,
  'chest_left': Muscle.chestLeft,
  'chest_right': Muscle.chestRight,
  'abs': Muscle.abs,
  'triceps_left': Muscle.tricepsLeft,
  'triceps_right': Muscle.tricepsRight,
  'biceps_left': Muscle.bicepsLeft,
  'biceps_right': Muscle.bicepsRight,
  'forearms_left': Muscle.forearmsLeft,
  'forearms_right': Muscle.forearmsRight,
  'quads_left': Muscle.quadsLeft,
  'quads_right': Muscle.quadsRight,
  'calves_left': Muscle.calvesLeft,
  'calves_right': Muscle.calvesRight,
  'lats_left': Muscle.latsBackLeft,
  'lats_right': Muscle.latsBackRight,
  'lowerlats_back_left': Muscle.lowerLatsBackLeft,
  'lowerlats_back_right': Muscle.lowerLatsBackRight,
  'glutes_left': Muscle.glutesLeft,
  'glutes_right': Muscle.glutesRight,
  'hamstrings_left': Muscle.hamstringsLeft,
  'hamstrings_right': Muscle.hamstringsRight,
};
