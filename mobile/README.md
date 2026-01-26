# Money Guardian - Mobile App

> **"Stop losing money to dumb fees."**

A daily-use money protection app that warns users before overdrafts, late fees, and subscription drain happen.

## Features

- **Daily Money Pulse** - SAFE / CAUTION / FREEZE status at a glance
- **Safe-to-Spend** - Know exactly how much you can spend today
- **Subscription Tracking** - See all your recurring charges in one place
- **Smart Alerts** - Get warned BEFORE fees happen, not after
- **Bank Connection** - Secure read-only access via Plaid

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: TBD
- **Architecture**: Clean Architecture
- **Platforms**: iOS & Android

## Getting Started

### Prerequisites

- Flutter SDK (3.x+)
- Dart SDK
- Android Studio / Xcode
- VS Code (recommended)

### Installation

```bash
# Navigate to mobile directory
cd mobile

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Build

```bash
# Android APK
flutter build apk

# iOS
flutter build ios
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
└── src/
    ├── theme/               # App theming
    │   ├── light_color.dart
    │   └── theme.dart
    ├── pages/               # Screen widgets
    │   ├── homePage.dart
    │   └── money_transfer_page.dart
    └── widgets/             # Reusable components
        ├── balance_card.dart
        ├── bottom_navigation_bar.dart
        ├── title_text.dart
        └── customRoute.dart
```

## Attribution

UI based on [flutter_wallet_app](https://github.com/TheAlphamerc/flutter_wallet_app) by [Sonu Sharma](https://github.com/TheAlphamerc), licensed under BSD-2-Clause.

---

**Money Guardian** - Protecting your money, one alert at a time.
