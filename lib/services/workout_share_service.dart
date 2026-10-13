import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/shareable_workout_card.dart';

class WorkoutShareService {
  const WorkoutShareService._();

  static Future<void> share({
    required BuildContext context,
    required GlobalKey cardKey,
    required WorkoutShareData data,
  }) async {
    await WidgetsBinding.instance.endOfFrame;

    final renderObject = cardKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return;
    }

    final image = await renderObject.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      return;
    }

    final directory = await getTemporaryDirectory();
    final safeTitle = data.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    final file = File('${directory.path}/${safeTitle}_forge.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (!context.mounted) {
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: data.textSummary,
        subject: data.title,
      ),
    );
  }
}
