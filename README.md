# Money Guardian

**Know before you owe.** A mobile app that protects your money by alerting you before subscriptions charge, overdrafts happen, or free trials end.

## What It Does

- **Daily Pulse**: See your financial status (SAFE/CAUTION/FREEZE) in 5 seconds
- **Subscription Tracking**: Track all your subscriptions with AI-powered waste detection
- **Calendar View**: Visualize when money leaves your account each month
- **Smart Alerts**: Get notified before charges hit, not after

## Tech Stack

- **Mobile**: Dart (iOS & Android)
- **State Management**: BLoC pattern
- **Backend**: FastAPI + PostgreSQL + Redis
- **AI/ML**: Subscription waste detection, spending pattern analysis

## Project Structure

```
money guardian/
├── mobile/              # Money Guardian mobile app
│   ├── lib/
│   │   ├── core/       # Core utilities, DI, network
│   │   ├── data/       # Models, repositories
│   │   ├── presentation/ # BLoCs
│   │   ├── src/        # UI components
│   │   │   ├── pages/  # App screens
│   │   │   ├── widgets/# Reusable widgets
│   │   │   └── theme/  # Colors, typography
│   │   └── main.dart   # App entry point
│   ├── android/        # Android configuration
│   └── ios/            # iOS configuration
├── backend/            # FastAPI backend
│   ├── app/            # API code
│   ├── docker-compose.yml
│   └── Dockerfile
├── CLAUDE.md           # AI assistant context
└── MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md
```

## Getting Started

### Prerequisites
- Dart SDK (3.x)
- Android Studio / Xcode
- Docker (for backend)

### Run the Backend
```bash
cd backend
docker-compose up -d
```

### Run the Mobile App
From the `mobile/` directory, install dependencies and run on your device/simulator.

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
