# Money Guardian - Implementation Plan v2

> **"Stop losing money to dumb fees."**

---

## Executive Summary

This plan addresses the critical gaps in Money Guardian after comprehensive codebase analysis. The app has a solid foundation with multi-tenant backend, email/banking provider integrations, and mobile BLoCs ready. The primary gaps are:

1. No manual subscription add UI
2. Email scans don't convert to subscriptions
3. Bank recurring transactions don't convert to subscriptions
4. AI waste detection not implemented
5. Onboarding doesn't connect services

**Target Launch Market:** USA/Canada via Plaid
**Approach:** Phase-by-phase, mobile-first with backend support

---

## Architecture Overview

### Multi-Region Banking Strategy

| Region | Provider | Status | Priority |
|--------|----------|--------|----------|
| USA/Canada | **Plaid** | ✅ Implemented | Launch |
| Nigeria, Ghana, Kenya | **Mono** | ✅ Implemented | Phase 2 |
| South Africa | **Stitch** | ✅ Implemented | Phase 2 |
| UK | **TrueLayer** | 🔮 Future | Phase 6 |
| EU | **Tink** | 🔮 Future | Phase 6 |

### Email Providers

| Provider | Status | Folders Accessed |
|----------|--------|------------------|
| **Gmail** | ✅ Complete | Inbox, All Mail, Spam, Promotions |
| **Outlook** | ✅ Complete | All mail via Microsoft Graph |
| **Yahoo** | ❌ Not Implemented | Planned |
| **iCloud** | ❌ Not Implemented | Planned |

### Email Types Detected

1. `subscription_confirmation` - Welcome emails
2. `receipt` - Payment confirmations
3. `billing_reminder` - Payment due notices
4. `price_change` - Price increase notifications
5. `trial_ending` - Trial expiration warnings
6. `payment_failed` - Failed payment notices
7. `cancellation` - Cancellation confirmations
8. `renewal_notice` - Auto-renewal notifications

### Pro/Free Tier Split

| Feature | Free | Pro |
|---------|------|-----|
| Manual subscriptions | 5 max | Unlimited |
| Bank connection | ❌ | ✅ |
| Email scanning | ❌ | ✅ |
| AI waste detection | ❌ | ✅ |
| Basic alerts | ✅ | ✅ |
| Smart alerts | ❌ | ✅ |
| Scan depth | N/A | 3 years |

---

## Phase 0: Foundation (Complete In-Progress Work)

**Duration:** 3-5 days
**Priority:** CRITICAL - Blockers for all other phases

### 0.1 Complete Onboarding Flow

**Status:** Onboarding page exists but only shows intro slides

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add bank connection step | `/mobile/lib/src/pages/onboarding_page.dart` | Medium |
| Add email connection step | `/mobile/lib/src/pages/onboarding_page.dart` | Medium |
| Add "Skip" and "Do later" options | `/mobile/lib/src/pages/onboarding_page.dart` | Low |
| Mark onboarding complete on finish | `/mobile/lib/presentation/blocs/auth/auth_bloc.dart` | Low |
| Add AuthOnboardingCompleted event | `/mobile/lib/presentation/blocs/auth/auth_event.dart` | Low |
| Create backend endpoint: PATCH /users/me/onboarding | `/backend/app/api/v1/endpoints/users.py` | Low |

**Implementation:**
```dart
// onboarding_page.dart - Add steps 5-7
final List<_OnboardingStep> _steps = [
  // ... existing 4 intro steps ...
  _OnboardingStep(
    icon: Icons.account_balance_rounded,
    title: 'Connect Your Bank',
    subtitle: 'See all your charges automatically',
    description: 'Read-only access. We can never move your money.',
    action: OnboardingAction.connectBank,
  ),
  _OnboardingStep(
    icon: Icons.email_rounded,
    title: 'Connect Your Email',
    subtitle: 'Find hidden subscriptions',
    description: 'We scan receipts to find charges your bank missed.',
    action: OnboardingAction.connectEmail,
  ),
  _OnboardingStep(
    icon: Icons.check_circle_rounded,
    title: "You're All Set!",
    subtitle: 'Start protecting your money',
    description: 'We\'ll alert you before charges happen.',
    action: OnboardingAction.complete,
  ),
];
```

**Dependencies:** None
**Testing:** Manual flow through onboarding with skip at each step

---

### 0.2 Fix Session Management

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add token refresh on app resume | `/mobile/lib/main.dart` | Medium |
| Handle expired tokens gracefully | `/mobile/lib/core/network/api_interceptors.dart` | Medium |
| Implement forgot password flow | `/mobile/lib/src/pages/login_page.dart` | Medium |
| Add backend forgot password endpoints | `/backend/app/api/v1/endpoints/auth.py` | Medium |

**Dependencies:** None
**Testing:** Login, token refresh after 30min, logout and session clear

---

## Phase 1: Core Subscription Management

**Duration:** 1-2 weeks
**Priority:** HIGH - Core feature gap

### 1.1 Add Subscription Manually (Mobile UI)

**Status:** FAB exists on subscriptions page but onPressed is empty

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create AddSubscriptionPage | `/mobile/lib/src/pages/add_subscription_page.dart` | High |
| Add form with validation | `/mobile/lib/src/pages/add_subscription_page.dart` | Medium |
| Integrate with SubscriptionBloc | `/mobile/lib/presentation/blocs/subscriptions/` | Low |
| Add common subscriptions database | `/mobile/lib/data/common_subscriptions.dart` | Low |

**Implementation:**
```dart
// add_subscription_page.dart
class AddSubscriptionPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Subscription')),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildCommonSuggestions(), // Netflix, Spotify, etc.
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Service Name'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Amount', prefixText: '\$'),
            ),
            DropdownButtonFormField<BillingCycle>(
              value: _billingCycle,
              items: BillingCycle.values.map((c) =>
                DropdownMenuItem(value: c, child: Text(c.displayName))
              ).toList(),
            ),
            _DatePickerField(
              label: 'Next Billing Date',
              value: _nextBillingDate,
              onChanged: (d) => setState(() => _nextBillingDate = d),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Common Subscriptions Database:**
```dart
// common_subscriptions.dart
const commonSubscriptions = [
  SubscriptionTemplate(
    name: 'Netflix',
    logoUrl: 'https://logo.clearbit.com/netflix.com',
    defaultAmount: 15.99,
    defaultCycle: BillingCycle.monthly,
    color: '#E50914',
  ),
  SubscriptionTemplate(
    name: 'Spotify',
    logoUrl: 'https://logo.clearbit.com/spotify.com',
    defaultAmount: 9.99,
    defaultCycle: BillingCycle.monthly,
    color: '#1DB954',
  ),
  // ... 50+ common services
];
```

**Dependencies:** None
**Testing:** Add with all fields, minimal fields, validation errors

---

### 1.2 Edit/Delete Subscription

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create SubscriptionDetailPage | `/mobile/lib/src/pages/subscription_detail_page.dart` | Medium |
| Add edit mode toggle | `/mobile/lib/src/pages/subscription_detail_page.dart` | Low |
| Add delete confirmation | `/mobile/lib/src/pages/subscription_detail_page.dart` | Low |
| Wire up onTap in SubscriptionCard | `/mobile/lib/src/widgets/subscription_card.dart` | Low |

**Dependencies:** 1.1
**Testing:** View details, edit/save, delete with confirmation

---

### 1.3 Free Tier Limit Enforcement

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add tier check in create endpoint | `/backend/app/api/v1/endpoints/subscriptions.py` | Low |
| Return upgrade_required error | `/backend/app/schemas/subscription.py` | Low |
| Handle in mobile BLoC | `/mobile/lib/presentation/blocs/subscriptions/` | Medium |
| Show Pro upgrade prompt | `/mobile/lib/src/pages/subscriptions_page.dart` | Medium |

**Implementation:**
```python
# subscriptions.py
@router.post("", response_model=SubscriptionResponse)
async def create_subscription(
    request: SubscriptionCreate,
    current_user: CurrentUserDep,
    db: DbSessionDep,
) -> SubscriptionResponse:
    tier_service = TierService(db)
    check = await tier_service.check_can_add_subscription(
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
    )

    if not check.allowed:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "upgrade_required",
                "message": check.reason,
                "current_count": check.current_count,
                "limit": check.limit,
            },
        )
    # ... create logic
```

**Dependencies:** 1.1, 1.2
**Testing:** Create 5 subs (works), create 6th (upgrade prompt)

---

## Phase 2: Email Integration (Email to Subscription)

**Duration:** 2-3 weeks
**Priority:** HIGH - Core value proposition

### 2.1 Email to Subscription Conversion (Backend)

**Status:** ScannedEmail records created but never converted

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create conversion endpoint | `/backend/app/api/v1/endpoints/email.py` | Medium |
| Create email_to_subscription_service.py | `/backend/app/services/email_to_subscription_service.py` | High |
| Add auto-create for high confidence | `/backend/app/services/email_connection_service.py` | Medium |
| Handle duplicate detection | `/backend/app/services/email_to_subscription_service.py` | Medium |

**Implementation:**
```python
# email_to_subscription_service.py
class EmailToSubscriptionService:
    async def create_subscription_from_email(
        self,
        tenant_id: UUID,
        user_id: UUID,
        scanned_email_id: UUID,
        override_amount: Decimal | None = None,
        override_cycle: str | None = None,
    ) -> Subscription:
        email = await self._get_scanned_email(tenant_id, scanned_email_id)

        if email.is_subscription_created:
            raise ValueError("Subscription already created")

        # Check for existing subscription
        existing = await self._find_existing_subscription(
            tenant_id, user_id, email.merchant_name
        )

        if existing:
            # Link to existing instead of creating duplicate
            email.subscription_id = existing.id
            email.is_processed = True
            await self.db.commit()
            return existing

        subscription = Subscription(
            tenant_id=tenant_id,
            user_id=user_id,
            name=email.merchant_name,
            amount=override_amount or email.detected_amount,
            currency=email.currency or "USD",
            billing_cycle=override_cycle or email.billing_cycle,
            next_billing_date=self._estimate_next_date(email),
            source="gmail",
            email_message_id=email.provider_message_id,
        )

        self.db.add(subscription)
        email.is_subscription_created = True
        await self.db.commit()

        return subscription
```

**Dependencies:** Phase 0
**Testing:** Create from email, handle missing amount, detect duplicate

---

### 2.2 Scanned Emails Review UI (Mobile)

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create ScannedEmailsPage | `/mobile/lib/src/pages/scanned_emails_page.dart` | High |
| Create ScannedEmailCard widget | `/mobile/lib/src/widgets/scanned_email_card.dart` | Medium |
| Add approve/edit/reject actions | `/mobile/lib/src/pages/scanned_emails_page.dart` | Medium |
| Add badge in settings | `/mobile/lib/src/pages/settings_page.dart` | Low |
| Create ScannedEmailBloc | `/mobile/lib/presentation/blocs/scanned_email/` | Medium |

**Dependencies:** 2.1
**Testing:** View list, approve high confidence, edit before approve, reject

---

### 2.3 Improve Email Parser - Billing Date Extraction

**Status:** Parser returns None for next_billing_date always

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add date extraction patterns | `/backend/app/services/email/parser_service.py` | High |
| Handle relative dates | `/backend/app/services/email/parser_service.py` | Medium |
| Add dateparser library | `/backend/requirements.txt` | Low |

**Patterns to Add:**
```python
DATE_PATTERNS = [
    r"next\s+(?:billing|charge)\s+(?:date|on):\s*(\w+\s+\d{1,2},?\s+\d{4})",
    r"renews?\s+on\s+(\w+\s+\d{1,2},?\s+\d{4})",
    r"will\s+be\s+charged\s+on\s+(\w+\s+\d{1,2})",
    r"trial\s+ends?\s+in\s+(\d+)\s+days?",
]
```

**Dependencies:** None
**Testing:** Parse various date formats

---

### 2.4 Add Yahoo and iCloud Email Providers

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create yahoo_provider.py | `/backend/app/services/email/yahoo_provider.py` | High |
| Create icloud_provider.py | `/backend/app/services/email/icloud_provider.py` | High |
| Update email factory | `/backend/app/services/email/factory.py` | Low |
| Add config | `/backend/app/core/config.py` | Low |

**Dependencies:** None
**Testing:** Connect each provider, scan emails

---

## Phase 3: Banking Integration (Bank to Subscription)

**Duration:** 2-3 weeks
**Priority:** HIGH - Pro feature differentiator

### 3.1 Integrate Plaid Flutter SDK (Mobile)

**Status:** Connect Bank page exists but doesn't use Plaid SDK

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add plaid_flutter package | `/mobile/pubspec.yaml` | Low |
| Implement PlaidLink widget | `/mobile/lib/src/pages/connect_bank_page.dart` | High |
| Handle success/failure callbacks | `/mobile/lib/src/pages/connect_bank_page.dart` | Medium |
| Exchange token via backend | `/mobile/lib/data/repositories/banking_repository.dart` | Low |

**pubspec.yaml:**
```yaml
dependencies:
  plaid_flutter: ^3.0.0
```

**Implementation:**
```dart
import 'package:plaid_flutter/plaid_flutter.dart';

Future<void> _initializePlaid() async {
  final linkToken = await context.read<BankingBloc>().getLinkToken();

  _plaidLink = PlaidLink(
    configuration: LinkTokenConfiguration(token: linkToken),
  );

  _plaidLink!.onSuccess(_onPlaidSuccess);
  _plaidLink!.onExit(_onPlaidExit);
}

void _onPlaidSuccess(LinkSuccess success) {
  context.read<BankingBloc>().add(
    BankingExchangeTokenRequested(
      publicToken: success.publicToken,
      metadata: success.metadata,
    ),
  );
}
```

**Dependencies:** Phase 0
**Testing:** Open Plaid Link, connect sandbox bank, see accounts

---

### 3.2 Bank Recurring to Subscriptions (Backend)

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create bank_to_subscription_service.py | `/backend/app/services/bank_to_subscription_service.py` | High |
| Create detect endpoint | `/backend/app/api/v1/endpoints/banking.py` | Medium |
| Add auto-detect on sync | `/backend/app/services/bank_connection_service.py` | Medium |

**Implementation:**
```python
class BankToSubscriptionService:
    async def detect_subscriptions(
        self,
        tenant_id: UUID,
        user_id: UUID,
        connection_id: UUID,
    ) -> list[DetectedBankSubscription]:
        bank_service = BankConnectionService(self.db)

        recurring = await bank_service.get_recurring_subscriptions(
            tenant_id=tenant_id,
            user_id=user_id,
            connection_id=connection_id,
        )

        detected: list[DetectedBankSubscription] = []

        for stream in recurring:
            if stream.category in self.EXCLUDED_CATEGORIES:
                continue

            existing = await self._find_existing_subscription(
                tenant_id, user_id, stream.merchant_name
            )

            detected.append(DetectedBankSubscription(
                stream_id=stream.stream_id,
                merchant_name=stream.merchant_name,
                amount=stream.average_amount,
                frequency=stream.frequency,
                next_expected_date=stream.next_expected_date,
                existing_subscription_id=existing.id if existing else None,
            ))

        return detected
```

**Dependencies:** 3.1
**Testing:** Detect recurring, create subscription, handle duplicates

---

### 3.3 Detected Bank Subscriptions Review UI

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create DetectedSubscriptionsPage | `/mobile/lib/src/pages/detected_subscriptions_page.dart` | Medium |
| Add navigation in settings | `/mobile/lib/src/pages/settings_page.dart` | Low |

**Dependencies:** 3.2
**Testing:** View detections, approve, reject

---

## Phase 4: AI & Intelligence

**Duration:** 2-3 weeks
**Priority:** MEDIUM - Differentiator feature

### 4.1 Implement AI Flag Detection (Backend)

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create ai_flag_service.py | `/backend/app/services/ai_flag_service.py` | High |
| Add Celery task for daily scan | `/backend/app/tasks/ai_tasks.py` | Medium |
| Add manual trigger endpoint | `/backend/app/api/v1/endpoints/subscriptions.py` | Low |

**AI Flag Types:**
- `unused`: No transactions in 30+ days
- `duplicate`: Similar service already tracked
- `price_increase`: Amount increased
- `trial_ending`: Trial ends within 7 days
- `forgotten`: Added 90+ days ago, no interactions

**Implementation:**
```python
class AIFlagService:
    async def analyze_subscription(
        self,
        subscription: Subscription,
    ) -> tuple[AIFlag, str | None]:
        # Check trial ending
        if subscription.trial_end_date:
            days_until = (subscription.trial_end_date - date.today()).days
            if 0 < days_until <= 7:
                return (
                    "trial_ending",
                    f"Free trial ends in {days_until} days. "
                    f"You'll be charged ${subscription.amount}.",
                )

        # Check price increase
        if subscription.previous_amount:
            if subscription.amount > subscription.previous_amount:
                increase = subscription.amount - subscription.previous_amount
                return (
                    "price_increase",
                    f"Price increased by ${increase:.2f}.",
                )

        # Check duplicates
        duplicate = await self._find_duplicate(subscription)
        if duplicate:
            return ("duplicate", f"Similar to '{duplicate.name}'.")

        # Check unused
        if subscription.last_usage_detected:
            days_since = (date.today() - subscription.last_usage_detected.date()).days
            if days_since > 30:
                return ("unused", f"No usage in {days_since} days.")

        return ("none", None)
```

**Dependencies:** Phase 1, 2, 3
**Testing:** Each flag type detected correctly

---

### 4.2 Smart Alerts System (Backend)

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create alert_generation_service.py | `/backend/app/services/alert_generation_service.py` | High |
| Generate from AI flags | `/backend/app/services/alert_generation_service.py` | Medium |
| Generate overdraft risk alerts | `/backend/app/services/alert_generation_service.py` | High |
| Add Celery task | `/backend/app/tasks/alert_tasks.py` | Medium |

**Alert Types:**
- `upcoming_charge` - Charges in next 3 days
- `overdraft_risk` - Balance < upcoming charges
- `ai_*` - Generated from AI flags

**Dependencies:** 4.1
**Testing:** Each alert type generated correctly

---

### 4.3 Display AI Flags in Mobile

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Update SubscriptionCard | `/mobile/lib/src/widgets/subscription_card.dart` | Medium |
| Add flag explanation sheet | `/mobile/lib/src/widgets/ai_flag_explanation_sheet.dart` | Medium |
| Add action buttons per flag type | `/mobile/lib/src/widgets/ai_flag_explanation_sheet.dart` | Low |

**Dependencies:** 4.1, 4.2
**Testing:** Tap flagged card, see explanation, take action

---

## Phase 5: Monetization

**Duration:** 1-2 weeks
**Priority:** HIGH - Revenue enablement

### 5.1 Integrate RevenueCat (Mobile)

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add purchases_flutter package | `/mobile/pubspec.yaml` | Low |
| Configure in main.dart | `/mobile/lib/main.dart` | Low |
| Create PurchaseService | `/mobile/lib/data/services/purchase_service.dart` | High |
| Update ProUpgradePage | `/mobile/lib/src/pages/pro_upgrade_page.dart` | Medium |
| Create backend webhook | `/backend/app/api/v1/endpoints/webhooks.py` | Medium |

**pubspec.yaml:**
```yaml
dependencies:
  purchases_flutter: ^6.0.0
```

**Implementation:**
```dart
@lazySingleton
class PurchaseService {
  Future<void> initialize(String userId) async {
    PurchasesConfiguration config = PurchasesConfiguration(_apiKey)
      ..appUserID = userId;
    await Purchases.configure(config);
  }

  Future<bool> purchasePackage(Package package) async {
    final customerInfo = await Purchases.purchasePackage(package);
    return customerInfo.entitlements.all['pro']?.isActive ?? false;
  }
}
```

**Dependencies:** Phase 0
**Testing:** View pricing, purchase sandbox, restore, verify Pro unlocked

---

### 5.2 Enforce Pro Features

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Add Pro gate to bank connection | `/mobile/lib/src/pages/connect_bank_page.dart` | Low |
| Add Pro gate to email connection | `/mobile/lib/src/pages/connect_email_page.dart` | Low |
| Add Pro gate to AI insights | `/mobile/lib/src/pages/subscriptions_page.dart` | Low |
| Create UpgradePrompt widget | `/mobile/lib/src/widgets/upgrade_prompt.dart` | Medium |

**Dependencies:** 5.1
**Testing:** Access Pro feature on free tier shows prompt

---

## Phase 6: Regional Expansion

**Duration:** 2-4 weeks per region
**Priority:** LOW - Post-launch

### 6.1 Add TrueLayer for UK

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create truelayer_provider.py | `/backend/app/services/banking/truelayer_provider.py` | High |
| Add config | `/backend/app/core/config.py` | Low |
| Update factory | `/backend/app/services/banking/factory.py` | Low |

**Countries:** GB, IE, FR, DE, ES, IT

**Dependencies:** Phase 3

---

### 6.2 Add Tink for EU

**Tasks:**
| Task | File | Complexity |
|------|------|------------|
| Create tink_provider.py | `/backend/app/services/banking/tink_provider.py` | High |
| Add config | `/backend/app/core/config.py` | Low |
| Update factory | `/backend/app/services/banking/factory.py` | Low |

**Countries:** Pan-European (6,000+ banks)

**Dependencies:** Phase 3

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **Phase 0** | 3-5 days | Onboarding flow, login polish |
| **Phase 1** | 1-2 weeks | Manual subscription add/edit, tier limits |
| **Phase 2** | 2-3 weeks | Email→subscription conversion, Yahoo/iCloud |
| **Phase 3** | 2-3 weeks | Plaid SDK, bank→subscription conversion |
| **Phase 4** | 2-3 weeks | AI flags, smart alerts |
| **Phase 5** | 1-2 weeks | RevenueCat, Pro enforcement |
| **Phase 6** | 2-4 weeks/region | UK/EU expansion |

**Total MVP (Phases 0-5):** 10-15 weeks
**Full Product (+ Phase 6):** 14-20 weeks

---

## Critical Files Summary

### NEW Files to Create

| File | Phase | Purpose |
|------|-------|---------|
| `/mobile/lib/src/pages/add_subscription_page.dart` | 1 | Manual subscription UI |
| `/mobile/lib/src/pages/subscription_detail_page.dart` | 1 | View/edit subscription |
| `/mobile/lib/src/pages/scanned_emails_page.dart` | 2 | Review detected emails |
| `/mobile/lib/src/pages/detected_subscriptions_page.dart` | 3 | Review bank detections |
| `/mobile/lib/data/services/purchase_service.dart` | 5 | RevenueCat integration |
| `/mobile/lib/data/common_subscriptions.dart` | 1 | Common services database |
| `/backend/app/services/email_to_subscription_service.py` | 2 | Convert emails to subs |
| `/backend/app/services/bank_to_subscription_service.py` | 3 | Convert bank data to subs |
| `/backend/app/services/ai_flag_service.py` | 4 | AI waste detection |
| `/backend/app/services/alert_generation_service.py` | 4 | Smart alerts |
| `/backend/app/tasks/ai_tasks.py` | 4 | Daily AI analysis |
| `/backend/app/services/email/yahoo_provider.py` | 2 | Yahoo email support |
| `/backend/app/services/email/icloud_provider.py` | 2 | iCloud email support |
| `/backend/app/services/banking/truelayer_provider.py` | 6 | UK banking |
| `/backend/app/services/banking/tink_provider.py` | 6 | EU banking |

### Files to UPDATE

| File | Phase | Changes |
|------|-------|---------|
| `/mobile/lib/src/pages/onboarding_page.dart` | 0 | Add connection steps |
| `/mobile/lib/src/pages/connect_bank_page.dart` | 3 | Plaid SDK integration |
| `/mobile/lib/src/pages/subscriptions_page.dart` | 1 | Wire up FAB, add flags |
| `/mobile/lib/src/pages/settings_page.dart` | 2,3 | Add detection badges |
| `/mobile/lib/src/widgets/subscription_card.dart` | 4 | AI flag display |
| `/mobile/lib/src/pages/pro_upgrade_page.dart` | 5 | Real purchases |
| `/mobile/pubspec.yaml` | 3,5 | Add plaid_flutter, purchases_flutter |
| `/backend/app/api/v1/endpoints/email.py` | 2 | Conversion endpoint |
| `/backend/app/api/v1/endpoints/banking.py` | 3 | Detection endpoint |
| `/backend/app/api/v1/endpoints/subscriptions.py` | 1 | Tier enforcement |
| `/backend/app/services/email/parser_service.py` | 2 | Date extraction |
| `/backend/app/services/email/factory.py` | 2 | Yahoo, iCloud |
| `/backend/app/services/banking/factory.py` | 6 | TrueLayer, Tink |

---

## Environment Configuration

### Backend (.env)

```env
# Core
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/money_guardian
REDIS_URL=redis://localhost:6379/0
JWT_SECRET_KEY=your-secret-key
ENVIRONMENT=development

# Plaid (USA/Canada)
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENVIRONMENT=sandbox

# Google (Gmail)
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Microsoft (Outlook)
MICROSOFT_CLIENT_ID=your-microsoft-client-id
MICROSOFT_CLIENT_SECRET=your-microsoft-client-secret

# Mono (Africa)
MONO_SECRET_KEY=your-mono-secret
MONO_PUBLIC_KEY=your-mono-public

# Stitch (South Africa)
STITCH_CLIENT_ID=your-stitch-client-id
STITCH_CLIENT_SECRET=your-stitch-secret

# RevenueCat Webhook
REVENUECAT_WEBHOOK_SECRET=your-webhook-secret
```

### Mobile (dart-define)

```bash
# Development
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=REVENUECAT_API_KEY=your-dev-key

# Production
flutter run --release \
  --dart-define=API_BASE_URL=https://api.moneyguardian.app/api/v1 \
  --dart-define=REVENUECAT_API_KEY=your-prod-key
```

---

## Testing Requirements

### Unit Tests

| Service | File | Coverage |
|---------|------|----------|
| EmailParserService | `/backend/tests/services/test_email_parser.py` | 90% |
| AIFlagService | `/backend/tests/services/test_ai_flag_service.py` | 85% |
| TierService | `/backend/tests/services/test_tier_service.py` | 95% |
| EmailToSubscriptionService | `/backend/tests/services/test_email_to_sub.py` | 85% |
| BankToSubscriptionService | `/backend/tests/services/test_bank_to_sub.py` | 85% |

### Integration Tests

| Flow | Description |
|------|-------------|
| Email Flow | Connect → Scan → Review → Create subscription |
| Bank Flow | Connect → Sync → Detect → Create subscription |
| Pro Upgrade | Hit limit → Prompt → Purchase → Access |
| Onboarding | Register → Steps → Connect/Skip → Home |

### E2E Tests (Mobile)

| Flow | Description |
|------|-------------|
| New User | Install → Register → Onboard → Add sub |
| Returning User | Login → View pulse → Check subs → Dismiss alert |
| Pro User | Login → Connect bank → Connect email → AI insights |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Manual subscription adds | 80% of users add 1+ in first week |
| Email connection rate | 40% of Pro users connect email |
| Bank connection rate | 60% of Pro users connect bank |
| Pro conversion | 5% free → Pro in first month |
| Alert engagement | 70% of alerts viewed within 24h |
| Subscription saved | Average $15/user/month identified |
