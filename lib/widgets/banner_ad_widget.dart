import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({required this.adUnitId, super.key});

  final String adUnitId;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;
  bool _loadStarted = false;
  static const int _reservedHeight = 100;

  @override
  void didUpdateWidget(BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adUnitId != widget.adUnitId) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
      _hasFailed = false;
      _loadStarted = false;
    }
  }

  Future<void> _loadAd(int width) async {
    try {
      await AdsService.initialize();
      if (!mounted || !AdsService.canRequestAds) {
        _fail();
        return;
      }

        final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || size == null) {
        _fail();
        return;
      }

      final bannerAd = BannerAd(
        size: size,
        adUnitId: widget.adUnitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _hasFailed = true;
              });
            }
          },
        ),
      );
      _bannerAd = bannerAd;
      await bannerAd.load();
    } catch (_) {
      _bannerAd?.dispose();
      _fail();
    }
  }

  void _fail() {
    if (mounted) {
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
        _hasFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_loadStarted && constraints.maxWidth.isFinite) {
          _loadStarted = true;
          final width = constraints.maxWidth.floor();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && width > 0) {
              _loadAd(width);
            } else {
              _fail();
            }
          });
        }
        if (_hasFailed) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: _reservedHeight.toDouble(),
          child: !_isLoaded || bannerAd == null
              ? null
              : Center(
                  child: SizedBox(
                    width: bannerAd.size.width.toDouble(),
                    height: bannerAd.size.height.toDouble(),
                    child: AdWidget(ad: bannerAd),
                  ),
                ),
        );
      },
    );
  }
}