# Money Guardian - Project Guide

> **"Stop losing money to dumb fees."**

---

## ⚠️ PRODUCT FOCUS - READ FIRST

**Money Guardian is NOT a budgeting app.** It's a **money protection/warning system**.

### What It IS:
- **Subscription tracker** with alerts BEFORE charges happen
- **Daily Pulse** - SAFE/CAUTION/FREEZE status in 5 seconds
- **AI waste detector** - flags forgotten/unnecessary subscriptions
- **Calendar view** - see when money leaves your account
- **Warning system** - alerts for overdraft risk, price increases, trials ending

### What It Is NOT:
- ❌ Not a budgeting app
- ❌ Not an expense categorizer
- ❌ Not a savings goal tracker
- ❌ Not a full financial dashboard

### Design Principles (from Business Plan):
- *"Users should understand their money in 5 seconds"*
- *"Silence is a feature - ONLY notify when something matters"*
- *"Quiet but powerful"*
- *"One avoided overdraft = paid for the app"*

### Core Pages (6-8 total):
| # | Page | Purpose |
|---|------|---------|
| 1 | **Daily Pulse (Home)** | SAFE/CAUTION/FREEZE + safe-to-spend + next 7 days |
| 2 | **Subscriptions Hub** | All subs, waste score, AI flags |
| 3 | **Calendar** | Month view with subscription charges on dates |
| 4 | **Alerts Center** | Overdraft warnings, upcoming charges, price increases |
| 5 | **Settings** | Alert preferences, bank/email connections |
| 6 | **Auth** | Login/Register |
| 7 | **Onboarding** | First-time bank + email setup |
| 8 | **Pro Upgrade** | Paywall (shown when hitting Pro features) |

### Design References:
- **Rocket Money** - subscription detection + clean dashboard
- **Bobby App** - simple subscription list with color coding
- **SubPilot** - calendar view for upcoming payments
- **Trackizer UI Kit** - 15 screens including calendar (Dribbble)

---

## Brand Guidelines

### Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Primary (Navy Blue)** | `#15294A` | rgb(21, 41, 74) | Main brand color, headers, cards |
| **Accent (Bright Blue)** | `#375EFD` | rgb(55, 94, 253) | CTAs, links, highlights |
| **Secondary Blue** | `#3554D3` | rgb(53, 84, 211) | Secondary actions |
| **Card Background** | `#2C405B` | rgb(44, 64, 91) | Card surfaces |
| **Muted Blue** | `#6D7F99` | rgb(109, 127, 153) | Icons, secondary elements |
| **Highlight (Gold)** | `#FBBD5C` | rgb(251, 189, 92) | Warnings, highlights, premium |
| **Gold Dark** | `#E7AD03` | rgb(231, 173, 3) | Hover states, accents |
| **Background** | `#FFFFFF` | rgb(255, 255, 255) | App background |
| **Surface** | `#F1F1F3` | rgb(241, 241, 243) | Dividers, cards |
| **Text Primary** | `#1D2635` | rgb(29, 38, 53) | Headlines, titles |
| **Text Secondary** | `#797878` | rgb(121, 120, 120) | Body text, subtitles |
| **Text Muted** | `#B9B9B9` | rgb(185, 185, 185) | Disabled, placeholders |
| **Black** | `#040405` | rgb(4, 4, 5) | Strong emphasis |

### Status Colors (Daily Pulse)

| Status | Color | Hex | Usage |
|--------|-------|-----|-------|
| **SAFE** | Green | `#22C55E` | Safe to spend, positive |
| **CAUTION** | Gold | `#FBBD5C` | Warning, be careful |
| **FREEZE** | Red | `#EF4444` | Stop, danger, overdraft risk |

### Typography

| Element | Font | Weight | Size |
|---------|------|--------|------|
| **Primary Font** | Mulish | - | - |
| **H1** | Mulish | Bold (700) | 24px |
| **H2** | Mulish | Regular | 22px |
| **H3** | Mulish | Regular | 20px |
| **H4** | Mulish | Regular | 18px |
| **H5** | Mulish | Regular | 16px |
| **H6** | Mulish | Regular | 14px |
| **Body** | Mulish | Regular | 14px |
| **Caption** | Mulish | Regular | 12px |

**Font Source:** Google Fonts (`google_fonts` package)

---

## Project Structure

```
/money guardian/
├── mobile/                    # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/             # Infrastructure (DI, network, storage, utils)
│   │   │   ├── di/           # Dependency injection (GetIt + Injectable)
│   │   │   ├── error/        # Exceptions & Failures
│   │   │   ├── network/      # API client, interceptors
│   │   │   ├── storage/      # Secure storage, preferences
│   │   │   └── utils/        # Formatters, validators
│   │   ├── data/             # Data layer (to be built)
│   │   │   ├── datasources/  # Remote & local data sources
│   │   │   ├── models/       # JSON serializable models
│   │   │   └── repositories/ # Repository implementations
│   │   ├── domain/           # Business layer (to be built)
│   │   │   ├── entities/     # Business entities
│   │   │   ├── repositories/ # Repository interfaces
│   │   │   └── usecases/     # Business logic
│   │   ├── presentation/     # UI layer (to be built)
│   │   │   ├── blocs/        # BLoC state management
│   │   │   ├── pages/        # Screens
│   │   │   └── widgets/      # Reusable components
│   │   ├── services/         # Firebase, notifications, Plaid
│   │   └── src/              # LEGACY template widgets
│   │       ├── theme/        # Brand colors & typography
│   │       ├── pages/        # Original template pages
│   │       └── widgets/      # Original template widgets
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── backend/                   # FastAPI backend (to be created)
│
├── CLAUDE.md                  # This file
└── MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md
```

---

## Tech Stack

### Mobile
- **Framework:** Flutter (Dart)
- **State Management:** TBD (BLoC recommended)
- **Font:** Mulish (Google Fonts)
- **Package ID:** `com.moneyguardian.app`

### Backend
- **Framework:** FastAPI (Python 3.12+)
- **Database:** PostgreSQL
- **Cache:** Redis
- **Queue:** Celery

### External Services
- **Banking:** Plaid
- **Auth:** Firebase Auth
- **Push:** Firebase Cloud Messaging
- **Payments:** Stripe
- **Email:** Gmail API

---

## Key Features

1. **Daily Money Pulse** - SAFE/CAUTION/FREEZE status
2. **Safe-to-Spend** - Daily spending limit
3. **Subscription Tracking** - Detect recurring charges
4. **Smart Alerts** - Warn before fees happen
5. **Bank Connection** - Read-only via Plaid
6. **Gmail Scan** - Find subscriptions in email

---

## Architecture

**Pattern:** Monolith-first, clean architecture

```
Mobile (Flutter) → Backend (FastAPI) → PostgreSQL + Redis
                         ↓
              External APIs (Plaid, Gmail, Stripe)
```

See `MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md` for full architecture details.

---

## Development Commands

### Mobile

```bash
cd mobile
flutter pub get      # Install dependencies
flutter run          # Run app
flutter build apk    # Build Android
flutter build ios    # Build iOS
```

### Backend (when created)

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

---

## Important Notes

- Always use brand colors from `lib/src/theme/light_color.dart`
- Always use Mulish font via Google Fonts
- Mobile package ID: `com.moneyguardian.app`
- Keep UI consistent with existing wallet app design
- Refer to implementation plan for architecture decisions

---

## Architecture Safeguards (Option A Build Rules)

**We are building on an existing UI template. To prevent technical debt, follow these rules strictly:**

### 1. Never Put Business Logic in Widgets
```dart
// ❌ BAD - Logic in widget
class HomePage extends StatefulWidget {
  void calculateSafeToSpend() {
    final balance = accounts.reduce((a, b) => a + b.balance);
    // business logic here...
  }
}

// ✅ GOOD - Widget calls use case via BLoC
class HomePage extends StatelessWidget {
  Widget build(context) {
    return BlocBuilder<PulseBloc, PulseState>(
      builder: (context, state) => PulseCard(pulse: state.pulse),
    );
  }
}
```

### 2. Always Add New Code to Correct Layer
```
lib/
├── src/                      # LEGACY - existing template widgets (migrate gradually)
│   ├── theme/               # ✅ Keep using
│   ├── pages/               # ⚠️ Migrate to presentation/pages/
│   └── widgets/             # ⚠️ Migrate to presentation/widgets/
│
├── core/                     # NEW - infrastructure code
├── data/                     # NEW - API calls, models, repositories
├── domain/                   # NEW - entities, use cases, repository interfaces
└── presentation/             # NEW - BLoCs, new pages, new widgets
```

### 3. Data Flow Rules
```
UI Widget → BLoC → UseCase → Repository → DataSource
    ↑                                          ↓
    └──────────── State Update ←───────────────┘
```

- Widgets ONLY dispatch events to BLoC
- BLoCs ONLY call UseCases
- UseCases ONLY call Repositories
- Repositories ONLY call DataSources
- DataSources handle API/DB calls

### 4. Migration Strategy for Existing Widgets
1. **Don't refactor existing widgets until needed**
2. When adding features to an existing page:
   - Create the BLoC first
   - Create the use case
   - Wrap existing widget with BlocProvider
   - Replace hardcoded data with BLoC state
3. Move widget to `presentation/pages/` only after full migration

### 5. Dependency Injection Rules
- All dependencies via GetIt
- Never instantiate services/repos directly in widgets
- Register dependencies in `core/di/injection.dart`

### 6. State Management Rules
- Use flutter_bloc for all new features
- One BLoC per feature/domain
- Events are past-tense (UserLoggedIn, PulseLoaded)
- States are nouns (PulseInitial, PulseLoading, PulseLoaded, PulseError)

### 7. File Naming Conventions
```
# Entities (domain layer)
user.dart, transaction.dart, pulse.dart

# Models (data layer)
user_model.dart, transaction_model.dart, pulse_model.dart

# BLoCs
pulse_bloc.dart, pulse_event.dart, pulse_state.dart

# Use Cases
get_daily_pulse_usecase.dart, link_bank_usecase.dart

# Repositories
pulse_repository.dart (interface)
pulse_repository_impl.dart (implementation)
```

### 8. Import Rules
```dart
// ✅ Use relative imports within same layer
import '../widgets/pulse_card.dart';

// ✅ Use package imports across layers
import 'package:money_guardian/domain/entities/pulse.dart';

// ❌ Never import data layer from domain
// ❌ Never import presentation from domain/data
```

---

## Current Status

**Approach:** Option A - Building on existing template
**Template:** flutter_wallet_app (BSD-2-Clause)
**Status:** UI shell complete, architecture layers needed

### What's Done
- [x] iOS/Android configurations
- [x] Brand colors defined
- [x] Font setup (Mulish)
- [x] Package ID set (com.moneyguardian.app)
- [x] 2 basic screens (HomePage, MoneyTransferPage)
- [x] 4 reusable widgets
- [x] Basic routing
- [x] Clean Architecture folder structure created
- [x] Dependencies added (flutter_bloc, get_it, dio, firebase, plaid, etc.)
- [x] Core layer created:
  - [x] Dependency injection (GetIt + Injectable)
  - [x] Error handling (Failures + Exceptions)
  - [x] Network layer (ApiClient, Interceptors, NetworkInfo)
  - [x] Storage layer (SecureStorage, Preferences)
  - [x] Utils (CurrencyFormatter, DateFormatter, Validators)

### What's Next
- [ ] Create domain layer (entities, repositories, use cases)
- [ ] Create data layer (models, data sources, repo implementations)
- [ ] Set up Firebase project
- [ ] Create auth flow (login/register screens + BLoC)
- [ ] Migrate existing HomePage to use BLoC
- [ ] Implement Daily Pulse feature
