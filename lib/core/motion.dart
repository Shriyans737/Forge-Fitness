import 'package:flutter/animation.dart';

abstract final class ForgeMotion {
  static const Duration short = Duration(milliseconds: 180);
  static const Duration cardEntry = Duration(milliseconds: 520);
  static const Duration cardStagger = Duration(milliseconds: 70);
  static const Duration ring = Duration(milliseconds: 1150);
  static const Duration ringCount = Duration(milliseconds: 1100);
  static const Duration scoreRing = Duration(milliseconds: 900);
  static const Duration scoreRingStagger = Duration(milliseconds: 100);
  static const Duration ringEntryDelay = Duration(milliseconds: 180);
  static const Duration ringStagger = Duration(milliseconds: 90);
  static const Duration dashboardSplashTimeline = Duration(milliseconds: 4600);
  static const Duration dashboardRingIntroDelay = Duration(milliseconds: 3050);
  static const Duration dashboardEntryIntroDelay = Duration(milliseconds: 3350);
  static const Duration tabOutgoing = Duration(milliseconds: 380);
  static const Duration tabIncoming = Duration(milliseconds: 560);
  static const Duration tabIncomingDelay = Duration(milliseconds: 120);
  static const Duration tabSelection = Duration(milliseconds: 620);
  static const Duration tabIconBounce = Duration(milliseconds: 560);
  static const Duration tabCardEntryDelay = Duration(milliseconds: 200);
  static const Duration tabCardStagger = Duration(milliseconds: 70);
  static const Duration tabCardEntry = Duration(milliseconds: 520);
  static const Duration liquidWaveFront = Duration(seconds: 7);
  static const Duration liquidWaveBack = Duration(seconds: 11);
  static const Duration liquidDroplets = Duration(milliseconds: 3600);
  static const Duration liquidRise = Duration(milliseconds: 900);
  static const Duration liquidQuickRise = Duration(milliseconds: 420);
  static const Duration liquidQuickTapThreshold = Duration(milliseconds: 220);
  static const Duration liquidQuickReadyHold = Duration(milliseconds: 600);
  static const Duration liquidReadyHold = Duration(milliseconds: 1500);
  static const Duration liquidDrain = Duration(milliseconds: 1100);
  static const Duration liquidWave = Duration(seconds: 5);
  static const Duration chartPulse = Duration(milliseconds: 2400);
  static const Duration chartPulseDelay = Duration(milliseconds: 1200);
  static const Duration settingsSyncSpin = Duration(milliseconds: 900);
  static const Duration macroDots = Duration(milliseconds: 500);
  static const Duration vitalGauge = Duration(seconds: 1);
  static const Duration vitalGaugeDelay = Duration(milliseconds: 150);
  static const Duration recoveryZone = Duration(milliseconds: 450);
  static const Duration strainGlow = Duration(milliseconds: 1800);
  static const Duration chartBar = Duration(milliseconds: 900);
  static const Duration streakFlicker = Duration(milliseconds: 1800);
  static const Duration heroLoop = Duration(milliseconds: 2400);
  static const Duration sparklinePulse = Duration(milliseconds: 1800);
  static const Duration sparklineDraw = Duration(milliseconds: 900);
  static const SpringDescription sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 28,
  );

  static const double entryOffset = 24;
  static const double tabTransitionOffset = 56;
  static const double tabCardOffset = 22;
  static const double liquidMergeBlur = 5;
  static const double liquidRestingLevel = 0.35;
  static const double liquidTextClearance = 46;
  static const double liquidDropletRise = 35;
  static const double navGlassBlur = 22;
  static const double navBarHeight = 70;
  static const double navBubbleHeight = 58;
  static const double navPillRadius = 999;
  static const double navHorizontalInset = 14;
  static const double navBottomInset = 14;
  static const double navIconSize = 23;
  static const double navLabelSize = 11;
  static const double navStretchFraction = 0.45;
  static const double navBubblePadding = 6;
  static const double cardRadius = 26;
  static const double cardPadding = 18;

  static const Curve linear = Curves.linear;
  static const Curve easeOutFast = Curves.easeOut;
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve streakPop = Curves.easeOutBack;
  static const Curve referenceEase = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve tabBubbleCurve = Cubic(0.45, 0, 0.2, 1);
  static const Curve liquidRiseCurve = Cubic(0.3, 0.7, 0.3, 1);
  static const Curve liquidDrainCurve = Cubic(0.6, 0, 0.3, 1);
}
