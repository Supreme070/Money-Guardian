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
├── mobile/                    # Money Guardian mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/             # Infrastructure
│   │   │   ├── config/       # API config (api_config.dart)
│   │   │   ├── di/           # Dependency injection (GetIt + Injectable)
│   │   │   ├── error/        # Exceptions & Failures
│   │   │   ├── network/      # API client, interceptors
│   │   │   ├── storage/      # Secure storage, preferences
│   │   │   └── utils/        # Formatters, validators, model_mappers
│   │   ├── data/             # Data layer ✅ COMPLETE
│   │   │   ├── models/       # auth_models, user_model, subscription_model,
│   │   │   │                 # alert_model, pulse_model (strict typing)
│   │   │   └── repositories/ # auth, subscription, alert, pulse repositories
│   │   ├── domain/           # Business layer (optional - repos handle logic)
│   │   │   ├── entities/     # Business entities
│   │   │   ├── repositories/ # Repository interfaces
│   │   │   └── usecases/     # Business logic
│   │   ├── presentation/     # UI layer ✅ BLoCs COMPLETE
│   │   │   └── blocs/        # auth/, subscriptions/, alerts/, pulse/
│   │   │       ├── auth/     # auth_bloc, auth_event, auth_state
│   │   │       ├── subscriptions/
│   │   │       ├── alerts/
│   │   │       └── pulse/
│   │   └── src/              # Current UI (uses mock data)
│   │       ├── theme/        # Brand colors & typography
│   │       ├── pages/        # homePage, subscriptions_page, alerts_page, calendar_page
│   │       └── widgets/      # pulse_status_card, subscription_card, etc.
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── backend/                   # FastAPI backend ✅ COMPLETE
│   ├── app/
│   │   ├── main.py
│   │   ├── core/             # config, security (JWT with tenant_id)
│   │   ├── db/               # base (TenantMixin, TimestampMixin)
│   │   ├── models/           # tenant, user, subscription, alert
│   │   ├── schemas/          # Pydantic schemas (strict Literal types)
│   │   ├── api/v1/endpoints/ # auth, subscriptions, alerts, pulse
│   │   └── services/         # auth_service, subscription_service
│   ├── alembic/              # Database migrations
│   ├── docker-compose.yml    # API + PostgreSQL + Redis
│   ├── Dockerfile
│   └── requirements.txt
│
├── CLAUDE.md                  # This file
└── MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md
```

---

## Tech Stack

### Mobile
- **Language:** Dart
- **State Management:** BLoC
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

**Pattern:** Monolith-first, clean architecture, multi-tenant, API-first

```
Money Guardian Mobile → Backend (FastAPI) → PostgreSQL + Redis
           ↑                    ↓
           │         External APIs (Plaid, Gmail, Stripe)
           │
           └── NEVER accesses DB directly. Always through Backend API.
```

See `MONEY_GUARDIAN_IMPLEMENTATION_PLAN.md` for full architecture details.

---

## 🚨 CRITICAL ARCHITECTURE RULES

### 1. API-First: Mobile NEVER Touches Database

```
✅ CORRECT:
Mobile App → REST API (FastAPI) → Database

❌ WRONG:
Mobile App → Database (Firebase Firestore, direct SQL, etc.)
```

**All data flows through the backend API.** The mobile app:
- Calls REST endpoints only
- Never imports database drivers
- Never has DB connection strings
- Never executes raw queries

### 2. Strict Typing: NO `any`, `unknown`, or `dynamic`

**Dart:**
```dart
// ❌ NEVER
dynamic data = response.data;
var something = json['field'];
Object? thing;

// ✅ ALWAYS
final UserModel user = UserModel.fromJson(response.data);
final String name = json['name'] as String;
final Subscription? subscription;
```

**Python (FastAPI) - Use Pydantic (like Zod):**
```python
# ❌ NEVER
def get_user(data: dict) -> dict:
    return data

def process(payload: Any) -> Any:
    pass

# ✅ ALWAYS - Pydantic models (Zod pattern)
from pydantic import BaseModel

class UserResponse(BaseModel):
    id: str
    email: str
    tenant_id: str

def get_user(user_id: str) -> UserResponse:
    return UserResponse(id=user_id, email="...", tenant_id="...")
```

**TypeScript (if used) - Use Zod:**
```typescript
// ❌ NEVER
const data: any = response.json();
function process(input: unknown): unknown {}

// ✅ ALWAYS
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  tenantId: z.string().uuid(),
});

type User = z.infer<typeof UserSchema>;
const user = UserSchema.parse(response.json());
```

### 3. Multi-Tenant Architecture

**Every request must be tenant-scoped. No exceptions.**

```python
# ❌ NEVER - Query without tenant filter
def get_subscriptions(db: Session) -> list[Subscription]:
    return db.query(Subscription).all()  # DANGER: Returns ALL tenants!

# ✅ ALWAYS - Tenant-scoped queries
def get_subscriptions(db: Session, tenant_id: str) -> list[Subscription]:
    return db.query(Subscription).filter(
        Subscription.tenant_id == tenant_id
    ).all()
```

**Tenant Isolation Rules:**
| Layer | How to Enforce |
|-------|----------------|
| **API Routes** | Extract `tenant_id` from JWT, pass to all services |
| **Services** | Require `tenant_id` parameter on all methods |
| **Repositories** | Filter ALL queries by `tenant_id` |
| **Database** | Every table has `tenant_id` column (indexed) |

**Database Schema Pattern:**
```sql
-- Every table MUST have tenant_id
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),  -- REQUIRED
    user_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    -- ...
    created_at TIMESTAMP DEFAULT NOW(),

    -- Composite index for tenant queries
    INDEX idx_subscriptions_tenant (tenant_id, user_id)
);
```

**JWT Must Contain Tenant:**
```python
# Token payload
{
    "sub": "user-uuid",
    "tenant_id": "tenant-uuid",  # REQUIRED
    "email": "user@example.com",
    "exp": 1234567890
}
```

### 4. Request/Response Validation

**Every endpoint must validate input and output:**

```python
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends

class CreateSubscriptionRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    amount: float = Field(..., gt=0)
    billing_cycle: Literal["weekly", "monthly", "yearly"]
    next_billing_date: date

class SubscriptionResponse(BaseModel):
    id: str
    tenant_id: str
    name: str
    amount: float
    billing_cycle: str
    next_billing_date: date
    created_at: datetime

    class Config:
        from_attributes = True  # Pydantic v2

@router.post("/subscriptions", response_model=SubscriptionResponse)
async def create_subscription(
    request: CreateSubscriptionRequest,
    current_user: User = Depends(get_current_user),  # Has tenant_id
) -> SubscriptionResponse:
    # tenant_id comes from authenticated user
    return subscription_service.create(
        tenant_id=current_user.tenant_id,
        data=request
    )
```

---

## Development Commands

### Mobile

From the `mobile/` directory:
- Install dependencies
- Run build_runner to generate DI config
- Run on device/simulator

### Backend

From the `backend/` directory:
- `docker-compose up -d` - Start all services (API, PostgreSQL, Redis)
- `docker-compose logs -f api` - View API logs
- `docker-compose down` - Stop all services

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
- Use BLoC pattern for all new features
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
**Template:** wallet_app (BSD-2-Clause)
**Status:** Backend complete, mobile data layer complete, all UI pages wired to BLoCs, Pro features UI complete
**Repo:** https://github.com/Supreme070/Money-Guardian

### What's Done

**Infrastructure:**
- [x] iOS/Android configurations
- [x] Brand colors defined (`light_color.dart`)
- [x] Font setup (Mulish via Google Fonts)
- [x] Package ID set (`com.moneyguardian.app`)
- [x] GitHub repo created and pushed
- [x] Clean Architecture folder structure
- [x] Core layer (DI, network, storage, utils)

**Backend (FastAPI - `/backend/`):**
- [x] FastAPI project setup with Pydantic models (strict typing, no `Any`)
- [x] PostgreSQL + multi-tenant schema (tenant_id on all tables)
- [x] Auth endpoints (JWT with tenant_id in payload)
- [x] Core API endpoints (subscriptions, alerts, pulse)
- [x] Docker Compose setup (API + PostgreSQL + Redis)
- [x] All schemas with Literal types (like Zod pattern)
- [x] TenantMixin and TimestampMixin for database models

**Mobile Data Layer (`/mobile/lib/data/`):**
- [x] API configuration (`core/config/api_config.dart`)
- [x] Auth models (`data/models/auth_models.dart`)
- [x] User model (`data/models/user_model.dart`)
- [x] Subscription model with enums (`data/models/subscription_model.dart`)
- [x] Alert model with enums (`data/models/alert_model.dart`)
- [x] Pulse model with enums (`data/models/pulse_model.dart`)
- [x] Auth repository (`data/repositories/auth_repository.dart`)
- [x] Subscription repository (`data/repositories/subscription_repository.dart`)
- [x] Alert repository (`data/repositories/alert_repository.dart`)
- [x] Pulse repository (`data/repositories/pulse_repository.dart`)

**Mobile BLoCs (`/mobile/lib/presentation/blocs/`):**
- [x] AuthBloc - login, register, logout, profile update
- [x] SubscriptionBloc - CRUD, pause, resume, cancel
- [x] AlertBloc - list, mark read, dismiss
- [x] PulseBloc - load, refresh
- [x] BankingBloc - connect bank, sync transactions, disconnect
- [x] EmailScanningBloc - connect email, scan emails, disconnect

**UI Pages (all screens wired to BLoCs):**
- [x] Daily Pulse (Home) - PulseBloc, PulseStatusCard, quick stats, next 7 days
- [x] Subscriptions Hub - SubscriptionBloc, list with AI flags, filter/sort, monthly total
- [x] Calendar - SubscriptionBloc, month view with charge markers, day detail (typed SubscriptionModel)
- [x] Alerts Center - AlertBloc, severity levels, unread badges, alert cards
- [x] Settings - BankingBloc, EmailScanningBloc, connections overview, preferences
- [x] Connect Bank - Multi-region (Plaid/Mono/Stitch), account listing, sync status
- [x] Connect Email - Gmail/Outlook OAuth, scanned emails, confidence badges
- [x] Pro Upgrade - Pricing tiers, feature comparison, subscription flow

**Widgets:**
- [x] `PulseStatusCard` - SAFE/CAUTION/FREEZE with safe-to-spend
- [x] `SubscriptionCard` - with AI flags (unused, duplicate, price increase, etc.)
- [x] `UpcomingSubscriptionItem` - compact list item
- [x] `BottomNavigation` - 4 tabs (Home, Subs, Calendar, Alerts)

**Backend Pro Features (Celery + Background Tasks):**
- [x] Banking providers (Plaid, Mono, Stitch) with abstract factory
- [x] Email providers (Gmail, Outlook) with OAuth 2.0
- [x] Celery task queue for background sync
- [x] Scheduled tasks for transaction/balance sync

**Mobile Pro Features:**
- [x] Bank connection models (`data/models/bank_connection_model.dart`)
- [x] Email connection models (`data/models/email_connection_model.dart`)
- [x] Banking repository (`data/repositories/banking_repository.dart`)
- [x] Email repository (`data/repositories/email_repository.dart`)

### What's Next (Priority Order)

**Before Running:**
1. Start backend (docker-compose up in backend directory)
2. Configure environment variables (Plaid, Google, Microsoft API keys)

**Remaining Work:**
- [ ] Integrate Plaid Flutter SDK for bank connection flow
- [ ] Implement OAuth WebView for email connection
- [ ] Integrate RevenueCat/Stripe for Pro subscriptions
- [ ] Add onboarding flow for new users
- [ ] Add push notifications (Firebase Cloud Messaging)
