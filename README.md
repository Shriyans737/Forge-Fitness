# Forge-Fitness
Forge — an offline-first Flutter workout tracker. Log sets, weights, and reps with zero login or cloud sync. Browse 800+ exercises (free-exercise-db) with instructions, muscle targeting, and images. All data stays local via Hive. Fast, private, distraction-free training.

# Forge 

Forge is an offline-first workout tracking app built with Flutter. No accounts, no cloud sync, no subscriptions — just fast, local logging with full data ownership on your device.

## Features

- **Local-only storage** — all workout data lives on-device via Hive, no internet required for core tracking
- **800+ exercise library** — powered by [free-exercise-db](https://github.com/yuhonas/free-exercise-db), with instructions, muscle groups, equipment, difficulty level, and images
- **Search & filter** — find exercises by name or muscle group
- **Custom exercises** — add your own with description, muscle group, and optional media
- **Workout logging** — start a session, add exercises, log sets (weight × reps) in real time
- **Workout history** — review past sessions with full set-by-set breakdown, duration, and total volume
- **Fast startup** — background-isolate JSON parsing and batched database writes keep first-launch seeding smooth

## Tech Stack

- **Flutter** — cross-platform UI
- **Hive** — local NoSQL database for offline persistence
- **cached_network_image** — exercise image loading with caching
- **uuid** — unique IDs for sessions and custom exercises
- **fl_chart** — (planned) progress visualization

## Getting Started

### Prerequisites
- Flutter SDK installed ([flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install))
- An emulator or physical device

# How to Install Forge

Forge is currently available for **Android** as a downloadable APK file. Follow the steps below to install it on your phone.

##  Step 1: Download the App

Download the latest APK from the Releases page:

 **[https://github.com/Shriyans737/Forge-Fitness/releases]

On the release page, click on the file ending in `.apk` under **Assets** to download it.

## ⚙️ Step 2: Allow Installs from Unknown Sources

Since Forge isn't on the Google Play Store, Android will ask for permission to install it:

1. Open the downloaded APK file from your **Notifications** or **Downloads** folder
2. If prompted with *"For your security, your phone is not allowed to install unknown apps from this source"*, tap **Settings**
3. Toggle on **Allow from this source**
4. Go back and tap the APK file again

*(This is a one-time step — required because the app isn't downloaded from the Play Store, not because it's unsafe.)*

##  Step 3: Install

1. Tap **Install** when prompted
2. Wait for it to finish, then tap **Open**

## Step 4: You're All Set

Forge works fully offline — no sign-up, no login required. Just open the app and start logging your workouts.

##  Troubleshooting

- **"App not installed" error** — make sure you have enough storage space, and that you don't already have an older version installed with a different signature (uninstall the old one first)
- **Nothing happens when I tap the APK** — try downloading it again, the file may not have fully downloaded
- **Still stuck?** — open an issue here: [https://github.com/Shriyans737/Forge-Fitness/issues]
## Project Structure
