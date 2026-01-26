# Money Guardian

**Know before you owe.** A mobile app that protects your money by alerting you before subscriptions charge, overdrafts happen, or free trials end.

## What It Does

- **Daily Pulse**: See your financial status (SAFE/CAUTION/FREEZE) in 5 seconds
- **Subscription Tracking**: Track all your subscriptions with AI-powered waste detection
- **Calendar View**: Visualize when money leaves your account each month
- **Smart Alerts**: Get notified before charges hit, not after

## Tech Stack

- **Mobile**: Flutter (iOS & Android)
- **State Management**: flutter_bloc
- **Backend**: (Coming soon)
- **AI/ML**: Subscription waste detection, spending pattern analysis

## Project Structure

```
money guardian/
├── mobile/              # Flutter mobile app
│   ├── lib/
│   │   ├── core/       # Core utilities, DI, network
│   │   ├── src/        # UI components
│   │   │   ├── pages/  # App screens
│   │   │   ├── widgets/# Reusable widgets
│   │   │   └── theme/  # Colors, typography
│   │   └── main.dart   # App entry point
│   ├── android/        # Android configuration
│   └── ios/            # iOS configuration
├── CLAUDE.md           # AI assistant context
└── MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md
```

## Getting Started

### Prerequisites
- Flutter SDK (3.x)
- Dart SDK
- Android Studio / Xcode

### Run the App
```bash
cd mobile
flutter pub get
flutter run
```

## Brand Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Navy Blue | `#15294A` | Primary brand |
| Bright Blue | `#375EFD` | CTAs, accents |
| Gold | `#FBBD5C` | Warnings, premium |
| Safe Green | `#22C55E` | Safe status |
| Freeze Red | `#EF4444` | Critical alerts |

## License

Proprietary - All rights reserved
