import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  AdsService._();

  static const bool isDebug = kDebugMode;
  static const _testBannerId = 'ca-app-pub-3940256099942544/6300978111';

  static const _releaseSettingsBanner1 = _testBannerId;
  static const _releaseSettingsBanner2 = _testBannerId;
  static const _releaseExerciseBanner = _testBannerId;
  static const _releaseSummaryBanner = _testBannerId;

  static const settingsBanner1 =
      isDebug ? _testBannerId : _releaseSettingsBanner1;
  static const settingsBanner2 =
      isDebug ? _testBannerId : _releaseSettingsBanner2;
  static const exerciseBanner =
      isDebug ? _testBannerId : _releaseExerciseBanner;
  static const summaryBanner =
      isDebug ? _testBannerId : _releaseSummaryBanner;

  static Future<void>? _initialization;
  static bool _canRequestAds = false;

  static bool get canRequestAds => _canRequestAds;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await _requestConsent();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }

      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (_canRequestAds) {
        await MobileAds.instance.initialize();
      }
    } catch (_) {
      _canRequestAds = false;
    }
  }

  static Future<void> _requestConsent() async {
    final completion = Completer<void>();
    void complete() {
      if (!completion.isCompleted) {
        completion.complete();
      }
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) => complete());
      },
      (_) => complete(),
    );
    await completion.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );
  }
}