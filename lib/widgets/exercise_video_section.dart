import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../services/youtube_id_service.dart';
import '../theme.dart';

class ExerciseVideoSection extends StatefulWidget {
  const ExerciseVideoSection({
    required this.exerciseId,
    required this.exerciseName,
    this.service,
    super.key,
  });

  final String exerciseId;
  final String exerciseName;
  final YoutubeIdService? service;

  @override
  State<ExerciseVideoSection> createState() => _ExerciseVideoSectionState();
}

class _ExerciseVideoSectionState extends State<ExerciseVideoSection> {
  YoutubeIdService get _service => widget.service ?? YoutubeIdService.instance;

  String? _videoId;
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _playerSubscription;
  bool _loading = true;
  bool _playerUnavailable = false;

  @override
  void initState() {
    super.initState();
    _loadVideoId();
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId ||
        oldWidget.service != widget.service) {
      _releasePlayer();
      _videoId = null;
      _playerUnavailable = false;
      _loading = true;
      _loadVideoId();
    }
  }

  Future<void> _loadVideoId() async {
    await _service.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _videoId = _service.idFor(widget.exerciseId);
      _loading = false;
    });
  }

  void _startPlayer() {
    final videoId = _videoId;
    if (videoId == null || _controller != null || _playerUnavailable) {
      return;
    }

    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
      ),
      onWebResourceError: (error) {
        debugPrint('YouTube player network error: ${error.description}');
        _markPlayerUnavailable();
      },
    );
    _controller = controller;
    _playerSubscription = controller.stream.listen((value) {
      if (value.hasError) {
        debugPrint('YouTube player reported error: ${value.error}');
        _markPlayerUnavailable();
      }
    });

    setState(() {});
    unawaited(_cueVideo(controller, videoId));
  }

  Future<void> _cueVideo(
    YoutubePlayerController controller,
    String videoId,
  ) async {
    try {
      await controller.cueVideoById(videoId: videoId);
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not load YouTube video: $error\n$stackTrace');
      _markPlayerUnavailable();
    }
  }

  void _markPlayerUnavailable() {
    if (!mounted || _playerUnavailable) {
      return;
    }
    setState(() => _playerUnavailable = true);
    _releasePlayer();
  }

  void _releasePlayer() {
    final subscription = _playerSubscription;
    _playerSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.close());
    }
  }

  Future<void> _openTutorialSearch() async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': '${widget.exerciseName} proper form',
    });
    await _launchExternal(uri);
  }

  Future<void> _openVideo() async {
    final videoId = _videoId;
    if (videoId == null) {
      return;
    }
    await _launchExternal(
      Uri.https('www.youtube.com', '/watch', {'v': videoId}),
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showLaunchFailure();
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not open external YouTube link: $error\n$stackTrace');
      _showLaunchFailure();
    }
  }

  void _showLaunchFailure() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open YouTube right now.')),
    );
  }

  @override
  void dispose() {
    _releasePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final videoId = _videoId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tutorial', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: ForgeSpacing.sm),
          if (_loading)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: _VideoPlaceholder(message: 'Loading tutorial…'),
            )
          else if (videoId == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openTutorialSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Watch tutorial'),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                child: _playerUnavailable
                    ? _UnavailablePlayer(onOpenVideo: _openVideo)
                    : _controller == null
                    ? _VideoPreview(videoId: videoId, onTap: _startPlayer)
                    : YoutubePlayer(
                        controller: _controller!,
                        aspectRatio: 16 / 9,
                      ),
              ),
            ),
          if (!_loading && videoId != null) ...[
            const SizedBox(height: ForgeSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openVideo,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in YouTube'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.videoId, required this.onTap});

  final String videoId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

    return Material(
      color: tokens.surfaceVariant,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }
                return const _VideoPlaceholder(message: 'Loading preview…');
              },
              errorBuilder: (context, error, stackTrace) =>
                  const _VideoPlaceholder(
                    message: 'Preview unavailable offline',
                  ),
            ),
            Center(
              child: CircleAvatar(
                backgroundColor: tokens.surface,
                foregroundColor: tokens.accentTeal,
                radius: ForgeSpacing.lg,
                child: const Icon(Icons.play_arrow_rounded, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ColoredBox(
      color: tokens.surfaceVariant,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(ForgeSpacing.sm),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _UnavailablePlayer extends StatelessWidget {
  const _UnavailablePlayer({required this.onOpenVideo});

  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return ColoredBox(
      color: tokens.surfaceVariant,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(ForgeSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Video unavailable here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.textPrimary),
              ),
              TextButton(
                onPressed: onOpenVideo,
                child: const Text('Open in YouTube'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
