# 🥔 Potato 60 Second Routine

> A Flutter app that helps busy people build healthy daily habits with just 60 seconds of exercise a day.

---

## 📋 Table of Contents
- [App Overview](#app-overview)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Project Setup](#project-setup)
- [Environment Variables (.env)](#environment-variables-env)
- [Firebase Setup](#firebase-setup)
- [Running the App](#running-the-app)
- [Building for Production](#building-for-production)
- [iOS Deployment (Codemagic)](#ios-deployment-codemagic)
- [Android Deployment](#android-deployment)
- [App Architecture](#app-architecture)
- [Key Features](#key-features)
- [Test Accounts](#test-accounts)

---

## App Overview

**App Name:** Potato 60 Second Routine  
**Bundle ID (iOS):** `com.ghiolabs.potato60secondroutine`  
**Application ID (Android):** `com.ghiolabs.potato60secondroutine`  
**Version:** 1.0.4 (Build 39)  
**Flutter Version:** Stable Channel (SDK ^3.11.3)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend / Database | Firebase Firestore |
| Authentication | Firebase Auth (Email, Apple Sign-In) |
| Push Notifications | Firebase Messaging |
| Crash Reporting | Firebase Crashlytics |
| File Storage | Firebase Storage |
| Ads | Google AdMob |
| Paywall / Subscriptions | Superwall |
| Localization | easy_localization |
| In-App Purchase | in_app_purchase |
| Config | flutter_dotenv |

---

## Prerequisites

Before you can run this project, you must have the following installed on your machine:

1. **Flutter SDK** (Stable Channel)
   - Install from: https://flutter.dev/docs/get-started/install
   - Verify: `flutter doctor`

2. **Android Studio** (for Android development)
   - With Android SDK and Emulator configured

3. **Xcode** (for iOS development — macOS only)
   - Requires macOS with Xcode 14+

4. **Git**
   - Install from: https://git-scm.com/

---

## Project Setup

### Step 1: Clone the Repository
```bash
git clone https://github.com/Eranda724/od1.git
cd od1
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Create the `.env` File
The app uses `flutter_dotenv` for secret configuration. You MUST create a `.env` file in the **root of the project** (same folder as `pubspec.yaml`).

See the [Environment Variables](#environment-variables-env) section below for the full list of required keys.

### Step 4: Run the App
```bash
flutter run
```

---

## Environment Variables (.env)

Create a file named `.env` in the project root. This file is **NOT included in the repository** for security reasons. The client must provide these values.

```env
# ─── Google AdMob ───────────────────────────────────────────────
ADMOB_APP_ID_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
ADMOB_APP_ID_IOS=ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
ADMOB_BANNER_ID_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
ADMOB_BANNER_ID_IOS=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
ADMOB_INTERSTITIAL_ID_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
ADMOB_INTERSTITIAL_ID_IOS=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX

# ─── Superwall ──────────────────────────────────────────────────
SUPERWALL_API_KEY_ANDROID=pk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
SUPERWALL_API_KEY_IOS=pk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

> ⚠️ **IMPORTANT:** Never commit the `.env` file to Git. It is already listed in `.gitignore`.

---

## Firebase Setup

The project is connected to a Firebase project named `streak-couch-app`.

### Android
The file `android/app/google-services.json` is included in the repository and is pre-configured for the Bundle ID `com.ghiolabs.potato60secondroutine`.

### iOS
The file `ios/Runner/GoogleService-Info.plist` is included in the repository and is pre-configured for the Bundle ID `com.ghiolabs.potato60secondroutine`.

### If you need to re-connect to Firebase:
1. Go to https://console.firebase.google.com
2. Open the `streak-couch-app` project
3. Go to **Project Settings > Your Apps**
4. Download the new config files and replace the existing ones

### Firebase Services Used:
- **Authentication** — Email/Password and Apple Sign-In
- **Firestore** — All user data, streaks, friends, exercises
- **Firebase Storage** — User profile pictures
- **Firebase Messaging** — Push notifications
- **Firebase Crashlytics** — Crash reporting
- **Firebase App Check** — Security

---

## Running the App

### Debug Mode (Development)
```bash
flutter run
```

### Release Mode (Performance Testing)
```bash
# Android
flutter run --release

# iOS (requires macOS + Xcode)
flutter run --release
```

---

## Building for Production

### Android APK (Direct Install)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Google Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

> ⚠️ The Android Keystore file (`release.keystore`) is required for signing. Keep it secure and never share it publicly. The keystore password is stored in `android/key.properties`.

### iOS (macOS Only)
```bash
flutter build ios --release
```
For cloud builds, see the [iOS Deployment](#ios-deployment-codemagic) section.

---

## iOS Deployment (Codemagic)

Because this project was developed on Windows, **all iOS builds are performed via Codemagic CI/CD** (https://codemagic.io).

### Codemagic Build Settings:
| Setting | Value |
|---|---|
| Flutter Channel | Stable |
| Xcode Version | Latest |
| Mode | Release |
| iOS Build Arguments | *(leave empty)* |
| Signing | Automatic (App Store Connect API Key) |
| Publishing | App Store Connect (enabled) |
| Bundle ID | `com.ghiolabs.potato60secondroutine` |

### Required Codemagic Environment Variables:
| Variable | Description |
|---|---|
| `ENV_CONTENT` | The full contents of your `.env` file |
| `APP_STORE_CONNECT_PUBLISHER_PRIVATE_KEY` | The `.p8` API key from App Store Connect |

### Pre-build Script:
Add this script in Codemagic under "Pre-build scripts" to generate the `.env` file on the cloud build machine:
```bash
echo "$ENV_CONTENT" > .env
```

### Apple Developer Account:
- **Team ID:** `WDFY2JGZ48`
- **App Store Connect App ID:** `6811997436`
- **Provisioning Profile Type:** App Store

---

## Android Deployment

### Google Play Store
1. Build the AAB: `flutter build appbundle --release`
2. Sign the AAB using the `release.keystore`
3. Upload to Google Play Console

### Keystore Information:
- **File:** `android/release.keystore` (NOT committed to Git)
- **Key Alias:** Defined in `android/key.properties`
- **Passwords:** Stored in `android/key.properties` (NOT committed to Git)

---

## App Architecture

```
lib/
├── main.dart                    # App entry point, Firebase & SDK initialization
├── firebase_options.dart        # Auto-generated Firebase config
├── admin/                       # Admin-only screens
├── l10n/                        # Localization files
├── models/                      # Data models
├── screens/                     # All app screens (UI)
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── welcome_screen.dart
│   ├── streak_screen.dart
│   ├── social_screen.dart
│   ├── settings_screen.dart
│   └── ...
└── services/                    # Business logic & API calls
    ├── ad_service.dart          # AdMob banner & interstitial ads
    ├── social_auth_service.dart # Google & Apple Sign-In
    ├── superwall_service.dart   # Superwall paywall
    ├── streak_service.dart      # Streak calculation logic
    ├── notification_service.dart
    └── ...

assets/
├── images/                      # All image assets
├── sounds/                      # Audio files
├── translations/                # Localization JSON files (en, es, etc.)
└── icon/                        # App icon & splash screen assets

ios/
└── Runner/
    ├── Info.plist               # iOS app config (ATT, AdMob, Encryption)
    ├── Runner.entitlements      # Apple Sign-In entitlements
    └── GoogleService-Info.plist # Firebase iOS config

android/
└── app/
    ├── google-services.json     # Firebase Android config
    └── src/main/AndroidManifest.xml
```

---

## Key Features

| Feature | Description |
|---|---|
| 60-Second Workouts | Daily timed exercise routines |
| Streak Tracking | Overall and per-exercise streak counters |
| Freeze Days | Users can freeze their streak to protect it |
| Social / Friends | Add friends, view their streaks, leaderboard |
| Push Notifications | Daily workout reminders |
| Apple Sign-In | Native iOS authentication |
| AdMob Ads | Banner and interstitial ads (removed with subscription) |
| Superwall Paywall | `remove_ads_yearly_subscription` via Superwall |
| Localization | Multi-language support via easy_localization |
| Profile Pictures | Upload via Firebase Storage |
| Dark/Light Mode | Automatic system theme support |

---

## Test Accounts

| Platform | Email | Password |
|---|---|---|
| App (Apple Review) | `applereview@test.com` | `AppleReview123!` |

> These accounts must be created manually inside the app or via Firebase Console before submitting for Apple Review.

---

## Important Files (Do NOT Delete)

| File | Purpose |
|---|---|
| `android/release.keystore` | Android signing key — **keep private!** |
| `android/key.properties` | Keystore passwords — **keep private!** |
| `.env` | All API keys — **keep private!** |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config |
| `android/app/google-services.json` | Firebase Android config |
| `ios/Runner/Runner.entitlements` | Apple Sign-In capability |

---

*Built with ❤️ using Flutter & Firebase*
