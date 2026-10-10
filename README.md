<div align="center">

# Forge 

**A local-first fitness, health and nutrition tracker built with Flutter.**
No account. No backend. No cloud. Your data stays on your phone.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)
![Storage](https://img.shields.io/badge/storage-Hive%20(local)-orange)

</div>

<!-- Add screenshots here, for example a row of 3-4 images -->
<!--
<p align="center">
  <img src="screenshots/dashboard.png" width="200" />
  <img src="screenshots/health.png" width="200" />
  <img src="screenshots/workout.png" width="200" />
  <img src="screenshots/nutrition.png" width="200" />
</p>
-->

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Exercise Data](#exercise-data)
- [Health Integration](#health-integration)
- [AI Features and API Keys](#ai-features-and-api-keys)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Monetisation](#monetisation)
- [Roadmap](#roadmap)
- [Known Issues](#known-issues)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

---

## About

Forge is a workout tracker that also pulls in your health data and logs your food, so everything about your training lives in one app. It is built to work fully offline. There is no sign-up, and nothing is sent to a server. The only network calls are optional ones: food lookups from Open Food Facts, AI food photo detection via Google Gemini (with your own API key), tutorial videos from YouTube, exercise images, and ads.

---

## Features

###  Workouts
- **Exercise library** with 870+ exercises. Filter by muscle group, body part, category and equipment, or search by name.
- **Exercise detail screens** with start/end position images, step-by-step instructions, and a tutorial video. If an exercise has a YouTube ID it plays in an embedded player. Otherwise a "Watch tutorial" button opens a YouTube search.
- **Muscle map on every exercise.** A front/back body diagram highlights primary and secondary muscles (red / gold / gray), shown alongside the muscle chips.
- **Workout template builder.** Name a template, search for exercises, add them, and set planned sets and reps for each one.
- **Template detail screen.** Tapping a template opens its details, with **Start Workout** and **Share** buttons, instead of launching a session straight away.
- **Active workout screen** that auto-saves as you go, so an app close or crash will not lose your session. You can search and add exercises while a session is running, and a live timer tracks the workout.
- **Live muscle visualiser** showing which muscles you have hit so far, plus total volume and total reps, updating while you train.
- **Workout summary** at the end of each session.
- **Workout sharing.** Share a workout as an image card (with a plain-text fallback) from the post-workout summary, workout history detail, or a template detail screen.
- **AI workout maker** for generating routines.

###  Health
The Health section has three tabs:

| Tab | What it shows |
|---|---|
| **Overview** | Activity, sleep, vitals and body stats from Apple Health / Health Connect, plus a list of watch workouts with readable sport names, per-sport icons and a "Log in Forge" action |
| **Body Log** | Weight and measurement entries with a trend chart and recent history |
| **Nutrition** | Calorie, protein, carb and fat goals, food search and today's log |

- Expanded health metrics: sleep, active energy, resting heart rate, flights climbed and more
- Whoop-style gradient progress rings for the Overview summary
- Health Monitor grid with vertical pill-slider gauges for vitals
- Circular tick-mark dial for calories, dot-matrix macro bars, and a gradient net-energy bar
- Watch workouts are recognised by type and shown with proper names (for example "Strength Training" or "Basketball") rather than raw HealthKit enum names
- Refresh button to re-pull Health data on demand

###  Nutrition
- Daily goals for calories, protein, carbs and fat
- Add food by **Open Food Facts search**, **barcode scan**, **AI photo detection**, or **manual entry**
- **AI photo detection** uses Google Gemini (multimodal) to estimate what is on your plate. Results are editable before anything is saved.
- Running log of everything eaten today

###  Dashboard
The first screen you see on launch:
- Personalised greeting ("Hey <name>") set on first launch
- Hero card and today's progress
- **Swipe-to-start** workout card: swipe left to right to begin a workout, with animation
- Muscles worked today
- Weekly overview cards
- Sleep, Strain and Recovery rings that **replay their animation every time you return to the Dashboard tab**
- Animated, with polished transitions throughout, including smoother bottom-nav tab switching

###  Design
- Dark and light themes (saved in settings)
- Teal-to-lime gradient accents, card-based stats, arc, bar and line charts, pill tags and a floating bottom nav
- Custom shared widgets (rings, pill gauge, tick dial, dot bar, gradient bar) reused across screens

---

## Tech Stack

| Area | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Local storage | Hive |
| Secure storage | `flutter_secure_storage` (for the Gemini API key) |
| Health data | [`health`](https://pub.dev/packages/health) package (HealthKit on iOS, Health Connect on Android) |
| Food data | Open Food Facts API |
| AI food detection | Google Gemini API (multimodal, bring your own key) |
| Videos | YouTube (embedded player + search fallback) |
| Images | `cached_network_image` |
| Charts | `fl_chart` plus custom-painted widgets |
| Muscle map | `flutter_body_part_selector` |
| Sharing | `share_plus` |
| Ads | Google AdMob (`google_mobile_ads`) |
| Heavy work | Dart isolates via `compute()` |

---

## Architecture

- **Local-first.** All user data (workouts, templates, body log, food log, settings) is stored in Hive on-device. There is no login and no backend.
- **Seeding on first launch.** The bundled exercise dataset is parsed and written to Hive once, on a background isolate using `compute()`, so the UI thread is never blocked (this fixed an ANR caused by parsing the large dataset on the main isolate). A one-time seed flag stops it running again.
- **Exercise model fields** include `category`, `bodyPart`, `target` and `mediaPath`, which power the library filters and detail screens.
- **Templates store plans.** `WorkoutTemplate` holds planned sets and reps per exercise, which powers the template detail screen and sharing.
- **Read-only Health access.** Forge only reads from HealthKit / Health Connect. It never writes back.
- **Auto-save.** The active workout state is persisted continuously so sessions survive app restarts.
- **Shared widget layer.** Rings, gauges and charts are built once as reusable custom-painted widgets and wired into the Dashboard and Health tabs.

---

## Exercise Data

The exercise library is seeded from `assets/exercises.json`:

- 876 exercises in the [free-exercise-db](https://github.com/yuhonas/free-exercise-db) format
- String IDs (for example `3_4_Sit-Up`)
- Two images per exercise (start and end position), loaded with `CachedNetworkImage` from the free-exercise-db GitHub raw URLs, so images need an internet connection the first time
- Fields include name, category, body part, primary and secondary muscles, equipment and instructions

### Adding YouTube tutorial IDs

A helper script lives in `tools/youtube_ids/` and looks up a YouTube video ID for each exercise.

```bash
cd tools/youtube_ids
# Add your YouTube Data API key (see the script's config)
# Then run the script to generate the ID mapping
```

> Update this section with the exact commands once you have run it against the API.

Exercises with an ID get the embedded player. Exercises without one get a "Watch tutorial" search link.

---

## Health Integration

Forge reads these from Apple Health / Health Connect:

- Steps and flights climbed
- Heart rate, resting heart rate and other vitals
- Active calories
- Sleep
- Workouts recorded by a watch

Planned for watch workouts: a GPS route and a map view.

### Platform setup

**iOS**
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select your signing team and set your own bundle identifier.
3. Add the **HealthKit** capability.
4. Make sure `Info.plist` contains the Health usage descriptions.
5. Run on a **physical iPhone**. HealthKit does not work on the simulator.

A free Apple Developer account is enough to install on your own device for testing.

**Android**
1. Install Health Connect on the device (built in on newer Android versions).
2. Check the required permissions and queries in `AndroidManifest.xml`.

---

## AI Features and API Keys

AI photo detection in Nutrition uses the Google Gemini API.

1. Create a Gemini API key in Google AI Studio.
2. Open the Nutrition photo flow in the app and paste your key when asked.
3. The key is stored on-device with `flutter_secure_storage`. It is never bundled in the repo.

Detected foods are shown in an editable list, so you can correct names, portions and macros before saving to your log.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android Studio and/or Xcode
- A physical device for Health features

### Install and run

```bash
git clone https://github.com/<your-username>/forge.git
cd forge
flutter pub get
flutter run
```

### Build

```bash
# Android debug APK
flutter build apk --debug

# Android release APK
flutter build apk --release

# iOS (from macOS)
flutter build ios
```

### Checks

```bash
flutter analyze
flutter test
```

---

## Project Structure

```
forge/
├── lib/
│   ├── models/          # Hive models and adapters
│   ├── screens/         # Dashboard, library, workouts, health, nutrition, settings
│   ├── widgets/         # Shared custom widgets (rings, gauges, dials, charts, muscle map)
│   ├── services/        # Health, food search, Gemini, sharing, seeding, ads
│   └── main.dart
├── assets/
│   └── exercises.json   # Bundled exercise dataset
├── tools/
│   └── youtube_ids/     # Script for fetching YouTube tutorial IDs
├── android/
├── ios/
└── pubspec.yaml
```

> Adjust folder names to match your actual layout.

---

## Monetisation

Forge uses Google AdMob. Current placements:

- 2 ads in Settings
- 1 ad on the exercise screen, shown only after roughly 15 completed workouts
- 1 ad on the workout summary screen

The project currently uses **AdMob test IDs**. Replace them with your own ad unit IDs before releasing, and never click your own live ads.

---

## Roadmap

**In progress / next up**
- [ ] Per-exercise progress charts with estimated 1RM
- [ ] Progressive overload hints after each session
- [ ] Goals and limits in Settings (steps, calories, macros, sleep, workouts, weight)
- [ ] Goals onboarding on first launch
- [ ] Watch workout detail: GPS route and map
- [ ] Data backup and export (JSON / CSV)
- [ ] Project website

**Later**
- [ ] Health coach features
- [ ] Workout polish and more active-workout improvements
- [ ] Optional Garmin Connect support

---

## Known Issues

- Health data requires a physical device
- Exercise images load from GitHub, so they need a connection and can show "Exercise image unavailable" if the request fails
- Some Dashboard and Health widgets are still being polished
- List anything else you are tracking here

---

## Contributing

This is a personal project, but suggestions and bug reports are welcome. Open an issue to start a conversation before sending a pull request.

---

## Credits

- Exercise data: [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db) (public domain)
- Food data: [Open Food Facts](https://world.openfoodfacts.org/)
- AI food detection: Google Gemini
- Design inspiration: Whoop and Musemind Agency's dribbble work

---

##  MIT License

https://github.com/Shriyans737/Forge-Fitness/tree/main?tab=MIT-1-ov-file

---

<div align="center">

Built by [Shriyans]


https://github.com/user-attachments/assets/1f719eea-efbe-443b-ae93-78ba58244a54

<img width="2500" height="2652" alt="collage_2" src="https://github.com/user-attachments/assets/15914d33-781a-4585-b7a4-f6cd927bc47b" />
<img width="3710" height="2652" alt="collage_3" src="https://github.com/user-attachments/assets/176935fd-2d2d-4865-b65e-40f579f5079f" />



