# Money Guardian - Bank & Email Integration Plan

> **Launch Priority:** USA/Canada first (Plaid)
> **Pro Features:** Bank connection + Email scanning

---

## Executive Summary

### Current State
- Manual subscription CRUD ✅ working
- Daily Pulse ⚠️ uses mock $500 balance
- Auth/multi-tenant ✅ complete
- Plaid/Email ❌ infrastructure only, not implemented

### What We're Building
| Feature | Provider(s) | Tier |
|---------|-------------|------|
| Bank Connection | Plaid (US/CA), Mono (Africa), Stitch (SA) | Pro |
| Email Scanning | Gmail, Outlook, Yahoo | Pro |
| Manual Subscriptions | N/A | Free |

---

## 1. Database Schema (New Tables)

### 1.1 `bank_connections`
```sql
CREATE TABLE bank_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),

    -- Provider
    provider VARCHAR(20) NOT NULL,  -- plaid, mono, stitch
    access_token TEXT NOT NULL,      -- Encrypted
    item_id VARCHAR(255),

    -- Institution
    institution_id VARCHAR(100),
    institution_name VARCHAR(255) NOT NULL,
    institution_logo VARCHAR(500),

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'connected',
    error_code VARCHAR(50),
    error_message TEXT,

    -- Sync
    last_sync_at TIMESTAMP WITH TIME ZONE,
    cursor TEXT,

    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,

    INDEX idx_bank_conn_tenant (tenant_id, user_id)
);
```

### 1.2 `bank_accounts`
```sql
CREATE TABLE bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    connection_id UUID NOT NULL REFERENCES bank_connections(id),

    provider_account_id VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    official_name VARCHAR(255),
    mask VARCHAR(10),

    account_type VARCHAR(20) NOT NULL,  -- checking, savings, credit
    account_subtype VARCHAR(30),

    current_balance DECIMAL(12,2),
    available_balance DECIMAL(12,2),
    limit DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'USD',

    is_active BOOLEAN DEFAULT TRUE,
    is_primary BOOLEAN DEFAULT FALSE,
    include_in_pulse BOOLEAN DEFAULT TRUE,

    balance_updated_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 1.3 `transactions`
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    account_id UUID NOT NULL REFERENCES bank_accounts(id),
    subscription_id UUID REFERENCES subscriptions(id),

    provider_transaction_id VARCHAR(255) NOT NULL UNIQUE,

    name VARCHAR(255) NOT NULL,
    merchant_name VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    transaction_type VARCHAR(10) NOT NULL,  -- debit, credit

    transaction_date DATE NOT NULL,
    posted_date DATE,

    category VARCHAR(100),
    is_recurring BOOLEAN DEFAULT FALSE,
    is_subscription BOOLEAN DEFAULT FALSE,
    is_pending BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW(),

    INDEX idx_tx_tenant_date (tenant_id, user_id, transaction_date)
);
```

### 1.4 `email_connections`
```sql
CREATE TABLE email_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),

    provider VARCHAR(20) NOT NULL,  -- gmail, outlook, yahoo
    email_address VARCHAR(255) NOT NULL,

    access_token TEXT NOT NULL,   -- Encrypted
    refresh_token TEXT,           -- Encrypted
    token_expires_at TIMESTAMP WITH TIME ZONE,
    scopes TEXT,

    status VARCHAR(20) NOT NULL DEFAULT 'connected',
    error_message TEXT,

    last_scan_at TIMESTAMP WITH TIME ZONE,
    scan_cursor TEXT,
    scan_depth_days INTEGER DEFAULT 90,

    created_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);
```

### 1.5 `scanned_emails`
```sql
CREATE TABLE scanned_emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    connection_id UUID NOT NULL REFERENCES email_connections(id),
    subscription_id UUID REFERENCES subscriptions(id),

    provider_message_id VARCHAR(255) NOT NULL,

    from_address VARCHAR(255) NOT NULL,
    from_name VARCHAR(255),
    subject TEXT NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE NOT NULL,

    email_type VARCHAR(30) NOT NULL,  -- receipt, confirmation, reminder, price_change
    confidence_score DECIMAL(3,2) NOT NULL,

    merchant_name VARCHAR(255),
    detected_amount DECIMAL(10,2),
    currency VARCHAR(3),
    billing_cycle VARCHAR(20),

    is_processed BOOLEAN DEFAULT FALSE,
    extracted_data JSONB,

    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 2. Backend Architecture

### 2.1 Banking Provider Abstraction

```
/backend/app/services/banking/
├── base.py              # Abstract BankingProvider class
├── plaid_provider.py    # Plaid implementation (US/Canada)
├── mono_provider.py     # Mono implementation (Nigeria)
├── stitch_provider.py   # Stitch implementation (South Africa)
└── factory.py           # Provider selection by region
```

**Interface:**
```python
class BankingProvider(ABC):
    async def create_link_token(user_id: str) -> LinkTokenResponse
    async def exchange_public_token(public_token: str) -> ExchangeTokenResponse
    async def get_accounts(access_token: str) -> list[AccountInfo]
    async def get_balances(access_token: str) -> list[AccountInfo]
    async def get_transactions(access_token, start_date, end_date, cursor) -> tuple[list, str, bool]
    async def get_recurring_transactions(access_token: str) -> list[TransactionInfo]
```

### 2.2 Email Provider Abstraction

```
/backend/app/services/email/
├── base.py              # Abstract EmailProvider class
├── gmail_provider.py    # Gmail implementation
├── outlook_provider.py  # Microsoft Graph implementation
├── yahoo_provider.py    # Yahoo Mail implementation
└── factory.py           # Provider selection
```

**Interface:**
```python
class EmailProvider(ABC):
    @property
    def provider_name() -> Literal["gmail", "outlook", "yahoo"]
    @property
    def oauth_url() -> str
    @property
    def required_scopes() -> list[str]

    async def exchange_code(code, redirect_uri) -> OAuthTokens
    async def refresh_tokens(refresh_token) -> OAuthTokens
    async def get_email_address(access_token) -> str
    async def search_subscription_emails(access_token, since_date, page_token) -> tuple[list, str]
```

### 2.3 Email Parser Service

```python
# /backend/app/services/email_parser_service.py

class EmailParserService:
    """
    Parse emails to detect subscription information.

    Detection Types:
    - subscription_confirmation
    - receipt
    - billing_reminder
    - price_change
    - trial_ending
    - payment_failed
    """

    def parse_email(email: EmailMessage) -> ParsedSubscription | None:
        """
        1. Detect email type from subject/body patterns
        2. Extract merchant from sender
        3. Extract amount using regex ($XX.XX patterns)
        4. Extract billing cycle (monthly, yearly, etc.)
        5. Calculate confidence score
        6. Return structured data if confidence > 0.6
        """
```

**Email Search Patterns:**
```
Subject contains: subscription, receipt, invoice, payment, billing, renewal, trial
From contains: noreply, no-reply, billing, invoice, subscription
```

**Price Extraction Patterns:**
```python
PRICE_PATTERNS = [
    r'\$(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)',      # $99.99
    r'USD\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)',  # USD 99.99
    r'total:\s*\$?(\d+\.\d{2})',                 # total: 99.99
]
```

### 2.4 Tier/Pro Gating Service

```python
class TierLimits:
    FREE = {
        "max_subscriptions": 5,
        "email_scan_days": 90,
        "bank_connections": 0,      # None for free
        "email_connections": 0,     # None for free
        "can_see_ai_insights": False,
    }

    PRO = {
        "max_subscriptions": -1,    # Unlimited
        "email_scan_days": 1095,    # 3 years
        "bank_connections": 5,
        "email_connections": 3,
        "can_see_ai_insights": True,
    }
```

---

## 3. API Endpoints

### 3.1 Banking Endpoints

| Method | Endpoint | Description | Tier |
|--------|----------|-------------|------|
| POST | `/api/v1/banking/link-token` | Create Plaid Link token | Pro |
| POST | `/api/v1/banking/exchange` | Exchange public token | Pro |
| GET | `/api/v1/banking` | List bank connections | Pro |
| POST | `/api/v1/banking/{id}/sync` | Sync transactions | Pro |
| DELETE | `/api/v1/banking/{id}` | Disconnect bank | Pro |
| GET | `/api/v1/banking/transactions` | List transactions | Pro |

### 3.2 Email Endpoints

| Method | Endpoint | Description | Tier |
|--------|----------|-------------|------|
| GET | `/api/v1/email/oauth-url/{provider}` | Get OAuth URL | Pro |
| POST | `/api/v1/email/oauth-callback` | Handle OAuth callback | Pro |
| GET | `/api/v1/email` | List email connections | Pro |
| POST | `/api/v1/email/{id}/scan` | Trigger email scan | Pro |
| DELETE | `/api/v1/email/{id}` | Disconnect email | Pro |

### 3.3 Response: Pro Feature Required

```json
{
  "status_code": 402,
  "detail": "Bank connection requires Pro subscription",
  "upgrade_url": "/pro"
}
```

---

## 4. Mobile Changes

### 4.1 New Packages (pubspec.yaml)

```yaml
dependencies:
  # Re-enable Plaid
  plaid_flutter: ^3.1.1

  # Email OAuth
  flutter_web_auth_2: ^3.0.4
  google_sign_in: ^6.1.6
```

### 4.2 New Models

```dart
// /mobile/lib/data/models/
├── bank_connection_model.dart   // BankConnectionModel, BankAccountModel
├── email_connection_model.dart  // EmailConnectionModel
└── transaction_model.dart       // TransactionModel
```

### 4.3 New Repositories

```dart
// /mobile/lib/data/repositories/
├── banking_repository.dart      // createLinkToken, exchange, list, sync
└── email_repository.dart        // getOAuthUrl, callback, list, scan
```

### 4.4 New BLoCs

```dart
// /mobile/lib/presentation/blocs/
├── banking/
│   ├── banking_bloc.dart
│   ├── banking_event.dart
│   └── banking_state.dart
└── email/
    ├── email_bloc.dart
    ├── email_event.dart
    └── email_state.dart
```

### 4.5 New UI Screens

```dart
// /mobile/lib/presentation/pages/
├── settings_page.dart           // Connected accounts, preferences
├── connect_bank_page.dart       // Plaid Link flow
├── connect_email_page.dart      // Email OAuth flow
└── pro_upgrade_page.dart        // Paywall for Pro features
```

### 4.6 Plaid Link Flow

```dart
// Simplified flow
1. User taps "Connect Bank"
2. Check tier (if free, show upgrade prompt)
3. Call POST /banking/link-token
4. Open PlaidLink with token
5. On success, call POST /banking/exchange with public_token
6. Show connected account
7. Trigger initial sync
```

---

## 5. Multi-Region Banking Strategy

### 5.1 Region → Provider Mapping

| Region | Provider | Notes |
|--------|----------|-------|
| US | Plaid | 12,000+ institutions |
| CA | Plaid | Full coverage |
| NG | Mono | 50+ Nigerian banks |
| GH | Mono | Expanding |
| KE | Mono + M-Pesa | M-Pesa for mobile money |
| ZA | Stitch | Major SA banks |

### 5.2 Single Backend Strategy

```python
def get_provider_for_region(country_code: str) -> Literal["plaid", "mono", "stitch"]:
    PLAID_REGIONS = {"US", "CA"}
    MONO_REGIONS = {"NG", "GH", "KE"}
    STITCH_REGIONS = {"ZA"}

    if country_code in PLAID_REGIONS:
        return "plaid"
    elif country_code in MONO_REGIONS:
        return "mono"
    elif country_code in STITCH_REGIONS:
        return "stitch"
    else:
        return "plaid"  # Default
```

### 5.3 Adding New Provider

1. Create `{provider}_provider.py` implementing `BankingProvider`
2. Add to factory
3. Update region mapping
4. No changes to services/endpoints/mobile

---

## 6. Implementation Phases

### Phase 1: Backend Foundation (Week 1-2)

**Database:**
- [ ] Create Alembic migration for all new tables
- [ ] Add indexes for query performance

**Services:**
- [ ] `BankingProvider` abstract base
- [ ] `PlaidProvider` implementation
- [ ] `BankConnectionService`
- [ ] Token encryption utilities
- [ ] `TierService` for Pro gating

**Endpoints:**
- [ ] POST `/banking/link-token`
- [ ] POST `/banking/exchange`
- [ ] GET `/banking`
- [ ] POST `/banking/{id}/sync`
- [ ] DELETE `/banking/{id}`

**Config:**
- [ ] Add to `.env`: `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ENVIRONMENT`

---

### Phase 2: Plaid Mobile Integration (Week 2-3)

**Mobile:**
- [ ] Re-enable `plaid_flutter` in pubspec.yaml
- [ ] `BankConnectionModel`, `BankAccountModel`
- [ ] `BankingRepository`
- [ ] `BankingBloc`
- [ ] Connect Bank page with Plaid Link

**Backend:**
- [ ] Plaid webhook handler
- [ ] Transaction sync Celery task
- [ ] Recurring transaction detection

**Pulse Update:**
- [ ] Replace mock $500 balance with real data
- [ ] Handle no connected accounts gracefully

---

### Phase 3: Email Integration (Week 3-4)

**Backend:**
- [ ] `EmailProvider` abstract base
- [ ] `GmailProvider` implementation
- [ ] `OutlookProvider` implementation
- [ ] `EmailConnectionService`
- [ ] `EmailParserService`
- [ ] Email scan Celery task

**Endpoints:**
- [ ] GET `/email/oauth-url/{provider}`
- [ ] POST `/email/oauth-callback`
- [ ] GET `/email`
- [ ] POST `/email/{id}/scan`
- [ ] DELETE `/email/{id}`

**Mobile:**
- [ ] `EmailConnectionModel`
- [ ] `EmailRepository`
- [ ] `EmailBloc`
- [ ] Connect Email page with OAuth flow

**Config:**
- [ ] Add to `.env`: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
- [ ] Add to `.env`: `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`

---

### Phase 4: Settings & Pro Upgrade (Week 4-5)

**Mobile:**
- [ ] Settings page with:
  - Connected bank accounts
  - Connected email accounts
  - Notification preferences
  - Account management
- [ ] Pro upgrade page/paywall
- [ ] Pro feature prompts when hitting limits

**Backend:**
- [ ] Stripe integration for Pro subscriptions
- [ ] Webhook for subscription changes
- [ ] Tier upgrade endpoint

---

### Phase 5: African Banking (Week 6-7)

**Backend:**
- [ ] `MonoProvider` implementation
- [ ] `StitchProvider` implementation
- [ ] Update factory with region mapping

**Testing:**
- [ ] Test with Mono sandbox
- [ ] Test with Stitch sandbox

---

### Phase 6: Polish & Testing (Week 7-8)

- [ ] Error handling edge cases
- [ ] Rate limiting for API calls
- [ ] Retry logic for failed syncs
- [ ] Analytics/logging
- [ ] End-to-end testing
- [ ] Performance optimization

---

## 7. Key Files to Modify

### Backend

| File | Change |
|------|--------|
| `/backend/app/core/config.py` | Add Google OAuth, Plaid, Stripe config |
| `/backend/app/api/v1/endpoints/pulse.py:123` | Replace mock $500 with real balance |
| `/backend/app/api/v1/router.py` | Add banking, email routers |
| `/backend/requirements.txt` | Add `plaid-python`, `google-api-python-client`, `stripe` |

### Mobile

| File | Change |
|------|--------|
| `/mobile/pubspec.yaml` | Enable `plaid_flutter`, add `flutter_web_auth_2` |
| `/mobile/lib/core/config/api_config.dart` | Add banking, email endpoints |
| `/mobile/lib/core/di/injection.dart` | Register new repositories and BLoCs |

---

## 8. Environment Variables

### Add to `.env`

```bash
# Plaid (US/Canada)
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
PLAID_ENVIRONMENT=sandbox  # sandbox, development, production

# Google OAuth (Gmail)
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_secret

# Microsoft OAuth (Outlook)
MICROSOFT_CLIENT_ID=your_client_id
MICROSOFT_CLIENT_SECRET=your_secret

# Mono (Nigeria/Africa)
MONO_SECRET_KEY=your_secret

# Stitch (South Africa)
STITCH_CLIENT_ID=your_client_id
STITCH_CLIENT_SECRET=your_secret

# Stripe (Pro subscriptions)
STRIPE_SECRET_KEY=your_secret
STRIPE_WEBHOOK_SECRET=your_webhook_secret
STRIPE_PRO_PRICE_ID=price_xxx
```

---

## 9. Success Metrics

| Metric | Target |
|--------|--------|
| Bank link success rate | > 85% |
| Email scan success rate | > 90% |
| Subscription detection accuracy | > 80% |
| Time to first value | < 2 minutes |
| Pro conversion rate | > 5% |

---

## 10. Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Plaid iOS issues | Test thoroughly on device, have fallback |
| OAuth token expiry | Implement robust refresh logic |
| Email parsing accuracy | Start conservative, improve over time |
| Rate limits | Implement exponential backoff |
| Multi-tenant data leak | Filter ALL queries by tenant_id |

---

*Last Updated: January 2026*
*Status: Ready for Implementation*
