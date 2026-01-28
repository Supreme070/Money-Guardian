# Money Guardian - Complete Implementation Plan

> **"Stop losing money to dumb fees."**

---

## ⚠️ PRODUCT FOCUS - THIS IS NOT A BUDGETING APP

**Money Guardian is a money protection/warning system** that:
1. **Tracks subscriptions** and alerts BEFORE charges happen
2. **Shows Daily Pulse** - SAFE/CAUTION/FREEZE status in 5 seconds
3. **Uses AI** to flag forgotten/unnecessary subscriptions
4. **Provides calendar view** - see when money leaves your account
5. **Warns about** overdraft risk, price increases, trials ending

### Design Principles:
- *"Users should understand their money in 5 seconds"*
- *"Silence is a feature - ONLY notify when something matters"*
- *"One avoided overdraft = paid for the app"*

### Design References:
| App/Resource | What to Study | Link |
|--------------|---------------|------|
| **Rocket Money** | Subscription detection, clean dashboard | [rocketmoney.com](https://www.rocketmoney.com/) |
| **Bobby App** | Simple subscription list, color coding | App Store |
| **SubPilot** | Calendar view for upcoming payments | [App Store](https://apps.apple.com/us/app/subscription-tracker-subpilot/id6475946504) |
| **Trackizer UI Kit** | 15 screens incl. calendar | [Dribbble](https://dribbble.com/tags/subscription-tracker) |
| **Subscription Tracker Behance** | Full case study | [Behance](https://www.behance.net/gallery/193383311/Subscription-Tracking-App-UI-Design) |
| **Figma Community** | Subscription UI template | [Figma](https://www.figma.com/community/file/1297265950603142011) |

### Core Pages (6-8 total, NOT 18):
| # | Page | Purpose |
|---|------|---------|
| 1 | **Daily Pulse (Home)** | SAFE/CAUTION/FREEZE + safe-to-spend + next 7 days |
| 2 | **Subscriptions Hub** | All subs, waste score, AI flags |
| 3 | **Calendar** | Month view with subscription charges on dates |
| 4 | **Alerts Center** | Overdraft warnings, upcoming charges |
| 5 | **Settings** | Alert preferences, connections |
| 6 | **Auth** | Login/Register |
| 7 | **Onboarding** | First-time setup |
| 8 | **Pro Upgrade** | Paywall |

---

## 📱 DETAILED PAGE SPECIFICATIONS

> **Brand Assets (Already Set):**
> - **Font:** Mulish (Google Fonts)
> - **Primary:** Navy Blue `#15294A`
> - **Accent:** Bright Blue `#375EFD`
> - **Highlight:** Gold `#FBBD5C`
> - **Status:** SAFE `#22C55E` / CAUTION `#FBBD5C` / FREEZE `#EF4444`

---

### PAGE 1: Daily Pulse (Home) ⭐ MAIN SCREEN

**Purpose:** User opens app → understands money status in 5 seconds

**Design Reference:** Trackizer home + Bobby simplicity

**UI Elements:**
```
┌─────────────────────────────────────┐
│  [Logo]     Money Guardian    [⚙️]  │  ← Nav bar (Navy Blue)
├─────────────────────────────────────┤
│                                     │
│      ┌─────────────────────┐        │
│      │                     │        │
│      │    🟢 SAFE          │        │  ← BIG status indicator
│      │                     │        │     (Green/Gold/Red circle)
│      │   "You're good"     │        │     Copy: Trackizer status card
│      └─────────────────────┘        │
│                                     │
│   Safe to Spend Today               │
│   ┌─────────────────────────┐       │
│   │      $142              │       │  ← Large number, Navy Blue
│   │  "Spend more = risk"    │       │     Copy: Bobby large amount display
│   └─────────────────────────┘       │
│                                     │
│   Next 7 Days                       │
│   ┌─────────────────────────┐       │
│   │ 📅 Jan 28  Netflix  $15 │       │  ← Upcoming charges list
│   │ 📅 Jan 30  Spotify  $10 │       │     Copy: Trackizer upcoming list
│   │ 📅 Feb 1   Rent    $1200│       │
│   └─────────────────────────┘       │
│                                     │
├─────────────────────────────────────┤
│  [🏠]    [📋]    [📅]    [🔔]      │  ← Bottom nav (4 icons)
│  Home    Subs   Calendar  Alerts    │     Copy: Bobby bottom nav
└─────────────────────────────────────┘
```

**Key Interactions:**
- Pull to refresh → recalculates pulse
- Tap status card → shows breakdown
- Tap subscription → goes to Subscriptions Hub

---

### PAGE 2: Subscriptions Hub

**Purpose:** See ALL subscriptions, AI flags waste, manage recurring charges

**Design Reference:** Bobby list + Trackizer cards

**UI Elements:**
```
┌─────────────────────────────────────┐
│  ←  Subscriptions           [+ Add] │  ← Header with add button
├─────────────────────────────────────┤
│                                     │
│   Monthly Total: $127               │  ← Summary card (Navy Blue bg)
│   Yearly Total: $1,524              │     Copy: Trackizer summary
│                                     │
├─────────────────────────────────────┤
│   ⚠️ AI Flags (2)            [View] │  ← Waste detection section
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────────────────┐       │
│   │ 🔴 Netflix      $15.99  │       │  ← Subscription card
│   │    Renews Jan 28        │       │     - Logo/color dot
│   │    ⚠️ "Price increased" │       │     - Name + amount
│   └─────────────────────────┘       │     - Next charge date
│                                     │     - AI flag if any
│   ┌─────────────────────────┐       │     Copy: Bobby cards
│   │ 🟢 Spotify      $9.99   │       │
│   │    Renews Feb 3         │       │
│   └─────────────────────────┘       │
│                                     │
│   ┌─────────────────────────┐       │
│   │ 🟡 Adobe CC     $54.99  │       │
│   │    Renews Feb 15        │       │
│   │    ⚠️ "Looks forgotten" │       │  ← AI waste flag (Gold)
│   └─────────────────────────┘       │
│                                     │
├─────────────────────────────────────┤
│  [🏠]    [📋]    [📅]    [🔔]      │
└─────────────────────────────────────┘
```

**Key Interactions:**
- Swipe left → snooze/delete
- Tap card → edit subscription details
- Tap AI flag → shows explanation + action
- Long press → drag to reorder (Bobby style)

**AI Flags (Gold warning color):**
- "Looks forgotten" - no usage detected
- "Price increased" - cost went up since last charge
- "Annual renewal in X days" - big charge coming
- "Trial ending" - will start charging soon

---

### PAGE 3: Calendar

**Purpose:** Visual overview of WHEN money leaves your account

**Design Reference:** Bill Reminder Figma + SubPilot calendar

**UI Elements:**
```
┌─────────────────────────────────────┐
│  ←  Calendar                        │
├─────────────────────────────────────┤
│                                     │
│        ◀  January 2026  ▶           │  ← Month selector
│                                     │
│   S   M   T   W   T   F   S         │
│  ───────────────────────────        │
│       1   2   3   4   5   6         │
│                   🟢                │  ← Green dot = 1 charge
│   7   8   9  10  11  12  13         │
│              🟡                     │  ← Yellow dot = 2 charges
│  14  15  16  17  18  19  20         │
│      🔴                             │  ← Red dot = 3+ charges
│  21  22  23  24  25  26  27         │
│                          🟢         │
│  28  29  30  31                     │
│  🟢                                 │
│                                     │
├─────────────────────────────────────┤
│   January 28                        │  ← Selected day detail
│   ┌─────────────────────────┐       │
│   │ Netflix         $15.99  │       │     Copy: Bill Reminder
│   │ Domain renewal  $12.00  │       │     day detail tray
│   └─────────────────────────┘       │
│   Total: $27.99                     │
│                                     │
├─────────────────────────────────────┤
│  [🏠]    [📋]    [📅]    [🔔]      │
└─────────────────────────────────────┘
```

**Color Coding (matches Bill Reminder pattern):**
- 🟢 Green dot = 1 subscription that day
- 🟡 Yellow/Gold dot = 2 subscriptions
- 🔴 Red dot = 3+ subscriptions (heavy day)

**Key Interactions:**
- Tap date → shows charges for that day
- Swipe left/right → change month
- Tap charge → goes to subscription detail

---

### PAGE 4: Alerts Center

**Purpose:** All warnings in one place - overdraft risk, upcoming charges, price changes

**Design Reference:** Trackizer notifications + Rocket Money alerts

**UI Elements:**
```
┌─────────────────────────────────────┐
│  ←  Alerts                   [Mark All Read] │
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────────────────┐       │
│   │ 🔴 URGENT               │       │  ← Alert card (Red = urgent)
│   │ Overdraft Risk          │       │
│   │ "Balance dropping. You  │       │
│   │  could overdraft in 3   │       │
│   │  days if spending       │       │
│   │  continues."            │       │
│   │                         │       │
│   │ [View Details] [Dismiss]│       │
│   └─────────────────────────┘       │
│                                     │
│   ┌─────────────────────────┐       │
│   │ 🟡 WARNING              │       │  ← Alert card (Gold = warning)
│   │ Price Increase          │       │
│   │ "Netflix increased from │       │
│   │  $14.99 to $15.99"      │       │
│   │                         │       │
│   │ [Snooze]      [Got it]  │       │
│   └─────────────────────────┘       │
│                                     │
│   ┌─────────────────────────┐       │
│   │ 🔵 INFO                 │       │  ← Alert card (Blue = info)
│   │ Trial Ending            │       │
│   │ "Hulu trial ends in 2   │       │
│   │  days. Cancel to avoid  │       │
│   │  $7.99 charge."         │       │
│   │                         │       │
│   │ [Remind Me]   [Cancel Sub]│     │
│   └─────────────────────────┘       │
│                                     │
├─────────────────────────────────────┤
│  [🏠]    [📋]    [📅]    [🔔]      │
└─────────────────────────────────────┘
```

**Alert Types:**
| Type | Color | Examples |
|------|-------|----------|
| URGENT | Red `#EF4444` | Overdraft risk, large charge tomorrow |
| WARNING | Gold `#FBBD5C` | Price increase, annual renewal coming |
| INFO | Blue `#375EFD` | Trial ending, subscription detected |

**Key Interactions:**
- Swipe right → dismiss
- Swipe left → snooze (remind later)
- Tap action button → specific action

---

### PAGE 5: Settings

**Purpose:** Manage connections (bank, email), alert preferences, account

**Design Reference:** Standard iOS/Android settings + Trackizer settings

**UI Elements:**
```
┌─────────────────────────────────────┐
│  ←  Settings                        │
├─────────────────────────────────────┤
│                                     │
│   CONNECTIONS                       │
│   ┌─────────────────────────┐       │
│   │ 🏦 Bank Accounts    [→] │       │  ← Plaid connection
│   │    Chase •••4521        │       │
│   │    Connected ✓          │       │
│   └─────────────────────────┘       │
│   ┌─────────────────────────┐       │
│   │ 📧 Email            [→] │       │  ← Gmail connection
│   │    john@gmail.com       │       │
│   │    Last scan: 2 hrs ago │       │
│   └─────────────────────────┘       │
│                                     │
│   NOTIFICATIONS                     │
│   ┌─────────────────────────┐       │
│   │ Push Notifications  [🔘]│       │  ← Toggle
│   │ Email Alerts        [🔘]│       │
│   │ Alert Sensitivity   [→] │       │  ← Low/Medium/High
│   └─────────────────────────┘       │
│                                     │
│   ACCOUNT                           │
│   ┌─────────────────────────┐       │
│   │ Subscription        [→] │       │  ← Free/Pro status
│   │    Free Plan            │       │
│   │ Security            [→] │       │  ← Face ID, PIN
│   │ Export Data         [→] │       │
│   │ Delete Account      [→] │       │  ← Red text
│   └─────────────────────────┘       │
│                                     │
│   App Version 1.0.0                 │
│                                     │
└─────────────────────────────────────┘
```

---

### PAGE 6: Auth (Login/Register)

**Purpose:** User authentication - simple, fast, trust-building

**Design Reference:** Trackizer auth screens + standard patterns

**UI Elements:**
```
┌─────────────────────────────────────┐
│                                     │
│         [Money Guardian Logo]       │
│                                     │
│      "Stop losing money to          │
│         dumb fees."                 │
│                                     │
├─────────────────────────────────────┤
│                                     │
│   Email                             │
│   ┌─────────────────────────┐       │
│   │ john@example.com        │       │
│   └─────────────────────────┘       │
│                                     │
│   Password                          │
│   ┌─────────────────────────┐       │
│   │ ••••••••           [👁️] │       │
│   └─────────────────────────┘       │
│                                     │
│   [Forgot Password?]                │
│                                     │
│   ┌─────────────────────────┐       │
│   │        LOG IN           │       │  ← Primary button (Bright Blue)
│   └─────────────────────────┘       │
│                                     │
│   ─────── or continue with ───────  │
│                                     │
│   [Google]  [Apple]                 │  ← Social login buttons
│                                     │
│   Don't have an account? Sign Up    │
│                                     │
└─────────────────────────────────────┘
```

**Trust Elements:**
- 🔒 "Bank-level security" badge
- "Read-only access" note near bank connection
- Clean, professional design (not flashy)

---

### PAGE 7: Onboarding (First-Time Setup)

**Purpose:** Connect bank + email in 3 simple steps

**Design Reference:** Trackizer onboarding + Plaid Link flow

**UI Elements:**
```
Step 1 of 3: Welcome
┌─────────────────────────────────────┐
│                                     │
│      [Shield Icon Animation]        │
│                                     │
│   "Money Guardian watches           │
│    your money so you don't          │
│    have to."                        │
│                                     │
│   ✓ Warns before overdrafts         │
│   ✓ Tracks all subscriptions        │
│   ✓ Detects forgotten charges       │
│                                     │
│   ┌─────────────────────────┐       │
│   │      GET STARTED        │       │
│   └─────────────────────────┘       │
│                                     │
│         [Skip for now]              │
│                                     │
└─────────────────────────────────────┘

Step 2 of 3: Connect Bank
┌─────────────────────────────────────┐
│         ● ● ○                       │  ← Progress dots
│                                     │
│      [Bank Icon]                    │
│                                     │
│   "Connect your bank"               │
│                                     │
│   We use Plaid for secure,          │
│   read-only access. We can          │
│   never move your money.            │
│                                     │
│   🔒 Bank-level encryption          │
│   👁️ Read-only (view only)          │
│   🚫 We never store credentials     │
│                                     │
│   ┌─────────────────────────┐       │
│   │   CONNECT BANK          │       │  ← Opens Plaid Link
│   └─────────────────────────┘       │
│                                     │
│         [Skip for now]              │
│                                     │
└─────────────────────────────────────┘

Step 3 of 3: Connect Email (Optional)
┌─────────────────────────────────────┐
│         ● ● ●                       │
│                                     │
│      [Email Icon]                   │
│                                     │
│   "Find hidden subscriptions"       │
│                                     │
│   We scan for receipts to find      │
│   subscriptions your bank missed.   │
│                                     │
│   ⚠️ Free: Last 90 days             │
│   ⭐ Pro: 1-3 years (annual subs)   │
│                                     │
│   ┌─────────────────────────┐       │
│   │   CONNECT GMAIL         │       │
│   └─────────────────────────┘       │
│                                     │
│         [Skip for now]              │
│                                     │
└─────────────────────────────────────┘
```

---

### PAGE 8: Pro Upgrade (Paywall)

**Purpose:** Convert free users to Pro when they hit a paid feature

**Design Reference:** Trackizer paywall + Mobbin subscription patterns

**UI Elements:**
```
┌─────────────────────────────────────┐
│  ✕                                  │  ← Close button
│                                     │
│      [Pro Badge / Crown Icon]       │
│                                     │
│      "Unlock Money Guardian Pro"    │
│                                     │
├─────────────────────────────────────┤
│                                     │
│   PRO FEATURES                      │
│                                     │
│   ✓ Deep email scan (1-3 years)     │
│   ✓ Annual renewal detection        │
│   ✓ Price increase alerts           │
│   ✓ SMS alerts                      │
│   ✓ Unlimited subscriptions         │
│   ✓ Advanced AI insights            │
│                                     │
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────────────────┐       │
│   │ YEARLY           $79/yr │       │  ← Best value (highlighted)
│   │ Save 34%    $6.58/month │       │     Gold border
│   └─────────────────────────┘       │
│                                     │
│   ┌─────────────────────────┐       │
│   │ MONTHLY         $9.99/mo│       │  ← Standard option
│   └─────────────────────────┘       │
│                                     │
│   ┌─────────────────────────┐       │
│   │     START FREE TRIAL    │       │  ← Primary CTA (Bright Blue)
│   └─────────────────────────┘       │
│                                     │
│   "One overdraft fee costs more     │
│    than a year of Pro."             │  ← Persuasion copy
│                                     │
│   Restore Purchase | Terms          │
│                                     │
└─────────────────────────────────────┘
```

**Trigger Points (when to show):**
- Tapping "Scan older emails"
- Viewing annual renewal alerts
- Requesting SMS alerts
- After 5 subscriptions on free plan

---

## UI Reference Summary

| Page | Primary Reference | Secondary Reference |
|------|-------------------|---------------------|
| **Daily Pulse** | Trackizer home | Bobby large amount display |
| **Subscriptions** | Bobby card list | Trackizer cards |
| **Calendar** | Bill Reminder Figma | SubPilot calendar |
| **Alerts** | Rocket Money alerts | Trackizer notifications |
| **Settings** | iOS native settings | Trackizer settings |
| **Auth** | Trackizer auth | Standard mobile patterns |
| **Onboarding** | Trackizer onboarding | Plaid Link flow |
| **Pro Upgrade** | Trackizer paywall | Mobbin subscription patterns |

---

## Download These Resources

| Resource | Link | Use For |
|----------|------|---------|
| **Trackizer Figma** | [uistore.design](https://www.uistore.design/items/trackizer-free-app-ui-kit-for-figma/) | Overall structure, cards, paywall |
| **Bill Reminder Figma** | [Figma Community](https://www.figma.com/community/file/1005565711137777791/bill-reminder-mobile-app) | Calendar view pattern |
| **Bobby App** | App Store | Subscription list interaction |
| **SubPilot App** | [App Store](https://apps.apple.com/us/app/subscription-tracker-subpilot/id6475946504) | Calendar with payment markers |

---

**Document Version:** 1.4
**Created:** January 26, 2026
**Last Updated:** January 26, 2026
**Status:** Implementation In Progress

### Mobile Foundation Status

> **Approach:** Option A - Building on existing UI template (wallet_app)

| Component | Status | Notes |
|-----------|--------|-------|
| iOS Configuration | ✅ Complete | Bundle ID: com.moneyguardian.app |
| Android Configuration | ✅ Complete | Package: com.moneyguardian.app |
| Brand Colors | ✅ Complete | Navy, Blue, Gold + Status colors |
| Typography | ✅ Complete | Mulish via Google Fonts |
| GitHub Repo | ✅ Complete | github.com/Supreme070/Money-Guardian |
| UI Pages | ✅ Complete | Home, Subscriptions, Calendar, Alerts (mock data) |
| Core Widgets | ✅ Complete | PulseStatusCard, SubscriptionCard, BottomNav |
| Core Layer | ✅ Complete | DI, network, storage, utils |
| Backend API | 🔄 **NEXT** | FastAPI + PostgreSQL + multi-tenant |
| Mobile Integration | ⏳ Waiting | Needs backend API first |

**Critical Rules:** API-first (no direct DB), strict typing (no `any`), multi-tenant (tenant_id everywhere). See Section 4.3.

### Architecture Quality Assessment

| Criteria | Rating | Notes |
|----------|--------|-------|
| **Industry Standard** | ✅ Excellent | Same patterns used by Nubank, Chime, Venmo |
| **MVP Appropriate** | ✅ Excellent | Monolith-first approach, no over-engineering |
| **Security** | ✅ Excellent | AES-256 encryption, tokens never exposed to mobile |
| **Scalability** | ✅ Good | Handles 100K+ users, clear evolution path |
| **Maintainability** | ✅ Excellent | Clean layered architecture, testable |
| **Cost Efficiency** | ✅ Excellent | Low infrastructure costs for MVP |

**Verdict:** Production-ready architecture following 2025-2026 fintech best practices. Not "revolutionary" — intentionally **boring, reliable, and secure**.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Overview](#2-product-overview)
3. [Technology Stack](#3-technology-stack)
4. [System Architecture](#4-system-architecture)
5. [Database Schema](#5-database-schema)
6. [API Specification](#6-api-specification)
7. [Mobile App Architecture](#7-mobile-app-architecture)
8. [AI/ML Pipeline](#8-aiml-pipeline)
9. [Security Architecture](#9-security-architecture)
10. [Implementation Phases](#10-implementation-phases)
11. [Progress Tracker](#11-progress-tracker)
12. [Risk Management](#12-risk-management)
13. [Success Metrics](#13-success-metrics)
14. [Cost Estimates](#14-cost-estimates)
15. [Appendix](#15-appendix)

---

## 1. Executive Summary

### 1.1 Problem Statement

People don't lose money because they're irresponsible. They lose money because:
- Bills hit unexpectedly
- Subscriptions renew quietly
- Balances drop slowly until BOOM → overdraft
- Banks warn AFTER damage is done

**Money Guardian fixes timing.**

### 1.2 Solution

Money Guardian watches your money, subscriptions, and receipts in the background and warns you BEFORE fees, overdrafts, or surprise charges happen.

### 1.3 Target Market

| Segment | Description | Priority |
|---------|-------------|----------|
| **Primary** | 25-45 year olds, paycheck to paycheck, hate surprises, multiple subscriptions | Highest |
| **Secondary** | Couples/families, contractors, small business owners | Medium |

**Market Size:** $21-25B (2025) → $115B+ (2033) at 20%+ CAGR

### 1.4 Business Model

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | 1 bank, 90-day email scan, basic alerts |
| **Pro** | $9.99/month or $79/year | Deep email scan (1-3 years), SMS alerts, advanced AI |
| **Family** | $19.99/month | Shared bills, household safe-to-spend, multiple alerts |

### 1.5 Revenue Projections

| Scenario | Paying Users | Monthly Revenue | Annual Revenue |
|----------|--------------|-----------------|----------------|
| Conservative (40% conversion) | 4,000 | $39,960 | $479,520 |
| Moderate (60% conversion) | 6,000 | $59,940 | $719,280 |
| Optimistic (100% paying) | 10,000 | $99,900 | $1,198,800 |

---

## 2. Product Overview

### 2.1 Core Features (MVP - Phase 1)

#### A. Bank Connection
- Read-only access via Plaid
- Auto-sync transactions
- Detect income, bills, spending patterns

#### B. Daily Money Pulse (Home Screen)
The heart of the app. Users understand their money in 5 seconds.

| Status | Meaning | Visual |
|--------|---------|--------|
| **SAFE** | > $500 safe to spend | Green |
| **CAUTION** | $100 - $500 safe to spend | Yellow/Orange |
| **FREEZE** | < $100 safe to spend | Red |

**Components:**
- Safe-to-Spend Today: "Safe to spend today: $42"
- Next 7 Days: Bills, Subscriptions, Renewals
- Quick Insights: Price increases, forgotten subscriptions

#### C. Subscriptions Hub
- All subscriptions (bank + email detected)
- Monthly equivalent cost
- Next charge date
- Waste score
- AI flags: "Looks forgotten", "Annual renewal coming", "Price went up"

#### D. Alerts Center
Alert types:
- Overdraft risk warning
- Upcoming charges
- Trial ending
- Price increase detected
- Suspicious charge
- Low balance warning

Each alert includes: why it happened, what to do, snooze/resolve options

#### E. Gmail Integration (Free + Pro)

| Feature | Free | Pro |
|---------|------|-----|
| Scan history | 90 days | 1-3 years |
| Annual renewals | No | Yes |
| Price increase detection | No | Yes |
| Receipt matching | Basic | Advanced |

#### F. Settings & Control
- Alert sensitivity
- Safe-to-spend style
- Notification channels (push, email, SMS)
- Email disconnect
- Data delete (GDPR)
- Subscription management

### 2.2 AI Systems

| AI System | Purpose | Output |
|-----------|---------|--------|
| **Spending Risk Predictor** | Predicts overdrafts before they happen | SAFE/CAUTION/FREEZE + days-to-risk |
| **Smart Safe-to-Spend** | Daily adaptive spending limit | Dollar amount |
| **Subscription Waste Detector** | Flags unused/forgotten subscriptions | Waste score + yearly savings |
| **Email Receipt Intelligence** | Extracts renewal dates, detects price hikes | Matched receipts |
| **Micro Money Coach** | One-line advice when needed | "Not a good spending day" |

---

## 3. Technology Stack

### 3.1 Stack Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOBILE (Dart)                         │
│  iOS + Android | Dart | BLoC State Management | Clean Arch      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (FastAPI)                          │
│  Python 3.12+ | Async | Pydantic | SQLAlchemy | Celery          │
└─────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  PostgreSQL   │     │     Redis       │     │  Celery Workers │
│  Primary DB   │     │  Cache + Queue  │     │  Background Jobs│
└───────────────┘     └─────────────────┘     └─────────────────┘
```

### 3.2 Detailed Stack

| Layer | Technology | Version | Rationale |
|-------|------------|---------|-----------|
| **Mobile** | Dart | 3.x | Cross-platform, single codebase, excellent performance, security |
| **Mobile State** | flutter_bloc | 8.x | Predictable state management, testable |
| **Backend** | FastAPI | 0.109+ | Async-first, great ML integration, type hints |
| **Database** | PostgreSQL | 15+ | ACID compliance, JSON support, financial data integrity |
| **Cache** | Redis | 7+ | Session management, rate limiting, job queues |
| **Task Queue** | Celery | 5.x | Background jobs, scheduled tasks |
| **ORM** | SQLAlchemy | 2.x | Async support, migrations with Alembic |
| **Auth** | Firebase Auth | Latest | Proven security, social login, mobile SDKs |
| **Banking API** | Plaid | Latest | Industry standard, 10,000+ banks |
| **Email API** | Gmail API | v1 | OAuth2, secure scanning |
| **Payments** | Stripe | Latest | Subscription management, mobile SDKs |
| **Push** | Firebase Cloud Messaging | Latest | Reliable cross-platform push |
| **Infrastructure** | AWS | - | Lambda, RDS, ElastiCache, S3 |

### 3.3 Why These Choices?

#### Flutter over React Native
| Factor | Flutter | React Native | Winner |
|--------|---------|--------------|--------|
| Security | Compiles to native ARM (hard to reverse-engineer) | JS bundles (easier to inspect) | Flutter |
| UI Consistency | Pixel-perfect across platforms | Platform differences | Flutter |
| Fintech Adoption | Nubank (80M users), Google Pay | Many apps | Flutter |
| Performance | Native machine code | JS bridge | Flutter |

#### FastAPI over NestJS
| Factor | FastAPI | NestJS | Winner |
|--------|---------|--------|--------|
| ML/AI Integration | Native Python (NumPy, scikit-learn) | Requires subprocess | FastAPI |
| Development Speed | Less boilerplate | More structure | FastAPI |
| Async Performance | Excellent (Starlette) | Good (Node.js) | Tie |
| Type Safety | Pydantic + hints | TypeScript | Tie |

---

## 4. System Architecture

### 4.1 Architecture Philosophy

> **"Start with a monolith. Scale later."**

This architecture follows 2025-2026 fintech best practices:

| Principle | Rationale |
|-----------|-----------|
| **Monolith First** | 87% of orgs use microservices, but 62% report challenges in Year 1 ROI. Start simple. |
| **Proven Patterns** | Same architecture used by Nubank (80M users), Chime, and successful fintechs |
| **Security by Design** | Financial data encrypted at rest, tokens never exposed to mobile |
| **Scale-Ready** | Can handle 100,000+ users before needing architectural changes |

**Industry Validation:**
- *"Avoid microservices while creating financial apps from scratch. Start monolithic, then evolve."* — DEV Community
- *"In contexts with one hard deadline, one clear business goal – a monolith was a survival tool."* — Medium (Fintech Marketplaces)

---

### 4.2 The Simple Answer

```
┌──────────────┐      HTTPS       ┌──────────────┐                ┌──────────────┐
│              │  ───────────────▶│              │ ──────────────▶│              │
│  Mobile App  │                  │   Backend    │                │   Database   │
│   (Dart)     │◀─────────────────│   (FastAPI)  │◀───────────────│ (PostgreSQL) │
│              │      JSON        │              │                │              │
└──────────────┘                  └──────────────┘                └──────────────┘
                                         │
                                         │ API Calls
                                         ▼
                                  ┌──────────────┐
                                  │  3rd Party   │
                                  │  APIs (Plaid,│
                                  │  Gmail, etc) │
                                  └──────────────┘
```

**That's it. Classic 3-tier architecture: Mobile → Backend → Database + External APIs**

---

### 4.3 🚨 CRITICAL ARCHITECTURE RULES

> **These rules are NON-NEGOTIABLE. Violations will cause security issues and tech debt.**

#### Rule 1: API-First — Mobile NEVER Touches Database

```
✅ CORRECT:
Mobile App → REST API (FastAPI) → Database

❌ WRONG:
Mobile App → Database (Firebase Firestore, direct SQL, etc.)
```

**The mobile app:**
- Calls REST endpoints ONLY
- Never imports database drivers
- Never has DB connection strings
- Never executes raw queries
- Never uses Firebase Firestore directly

#### Rule 2: Strict Typing — NO `any`, `unknown`, `dynamic`, or `dict`

**Python (FastAPI) — Use Pydantic:**
```python
# ❌ NEVER
def get_user(data: dict) -> dict:
def process(payload: Any) -> Any:

# ✅ ALWAYS — Pydantic models
class UserResponse(BaseModel):
    id: str
    email: str
    tenant_id: str

def get_user(user_id: str) -> UserResponse:
```

**Dart — Explicit types:**
```dart
// ❌ NEVER
dynamic data = response.data;
var something = json['field'];

// ✅ ALWAYS
final UserModel user = UserModel.fromJson(response.data);
final String name = json['name'] as String;
```

#### Rule 3: Multi-Tenant Architecture — tenant_id EVERYWHERE

**Every request must be tenant-scoped. No exceptions.**

```python
# ❌ NEVER — Query without tenant filter
def get_subscriptions(db: Session) -> list[Subscription]:
    return db.query(Subscription).all()  # DANGER: Returns ALL tenants!

# ✅ ALWAYS — Tenant-scoped queries
def get_subscriptions(db: Session, tenant_id: str) -> list[Subscription]:
    return db.query(Subscription).filter(
        Subscription.tenant_id == tenant_id
    ).all()
```

**Enforcement by Layer:**
| Layer | How to Enforce |
|-------|----------------|
| **JWT Token** | Contains `tenant_id` claim |
| **API Routes** | Extract `tenant_id` from JWT, pass to services |
| **Services** | Require `tenant_id` parameter on ALL methods |
| **Repositories** | Filter ALL queries by `tenant_id` |
| **Database** | Every table has `tenant_id` column (indexed) |

**Database Schema Pattern:**
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,  -- REQUIRED on every table
    user_id UUID NOT NULL,
    -- ... other fields
    CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);
CREATE INDEX idx_subscriptions_tenant ON subscriptions(tenant_id);
```

#### Rule 4: Request/Response Validation

Every endpoint validates input AND output:
```python
@router.post("/subscriptions", response_model=SubscriptionResponse)
async def create_subscription(
    request: CreateSubscriptionRequest,  # Validated input
    current_user: User = Depends(get_current_user),
) -> SubscriptionResponse:  # Validated output
    return subscription_service.create(
        tenant_id=current_user.tenant_id,
        data=request
    )
```

---

### 4.4 Full System Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              MONEY GUARDIAN ARCHITECTURE                       ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ┌─────────────────────────────────────────────────────────────────────────┐  ║
║  │                            CLIENT LAYER                                  │  ║
║  │                                                                         │  ║
║  │    ┌─────────────┐          ┌─────────────┐          ┌─────────────┐   │  ║
║  │    │             │          │             │          │             │   │  ║
║  │    │  iOS App    │          │ Android App │          │  (Future)   │   │  ║
║  │    │  Flutter    │          │   Flutter   │          │   Web App   │   │  ║
║  │    │             │          │             │          │             │   │  ║
║  │    └──────┬──────┘          └──────┬──────┘          └──────┬──────┘   │  ║
║  │           │                        │                        │          │  ║
║  └───────────┼────────────────────────┼────────────────────────┼──────────┘  ║
║              │                        │                        │             ║
║              └────────────────────────┼────────────────────────┘             ║
║                                       │                                      ║
║                                       │ HTTPS (TLS 1.3)                      ║
║                                       │ REST API + JSON                      ║
║                                       ▼                                      ║
║  ┌─────────────────────────────────────────────────────────────────────────┐  ║
║  │                            API GATEWAY                                   │  ║
║  │         (AWS ALB / nginx) - SSL termination, rate limiting              │  ║
║  └─────────────────────────────────────────────────────────────────────────┘  ║
║                                       │                                      ║
║                                       ▼                                      ║
║  ┌─────────────────────────────────────────────────────────────────────────┐  ║
║  │                         BACKEND (FastAPI - Python)                       │  ║
║  │                              MONOLITH                                    │  ║
║  │  ┌─────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                         API LAYER                                │   │  ║
║  │  │  /auth  /banking  /accounts  /transactions  /pulse  /alerts     │   │  ║
║  │  │  /subscriptions  /predictions  /gmail  /billing  /webhooks      │   │  ║
║  │  └─────────────────────────────────────────────────────────────────┘   │  ║
║  │                                   │                                     │  ║
║  │  ┌─────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                       SERVICE LAYER                              │   │  ║
║  │  │  AuthService  PlaidService  TransactionService  AlertService    │   │  ║
║  │  │  SubscriptionService  PredictionService  GmailService           │   │  ║
║  │  │  NotificationService  StripeService  EncryptionService          │   │  ║
║  │  └─────────────────────────────────────────────────────────────────┘   │  ║
║  │                                   │                                     │  ║
║  │  ┌─────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                         AI LAYER                                 │   │  ║
║  │  │  OverdraftPredictor  SafeToSpendCalculator  WasteDetector       │   │  ║
║  │  │  SubscriptionDetector  EmailParser  TransactionCategorizer      │   │  ║
║  │  └─────────────────────────────────────────────────────────────────┘   │  ║
║  │                                   │                                     │  ║
║  │  ┌─────────────────────────────────────────────────────────────────┐   │  ║
║  │  │                        DATA LAYER                                │   │  ║
║  │  │  SQLAlchemy Models + Repositories                                │   │  ║
║  │  └─────────────────────────────────────────────────────────────────┘   │  ║
║  └─────────────────────────────────────────────────────────────────────────┘  ║
║              │                   │                   │                       ║
║              ▼                   ▼                   ▼                       ║
║  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────────────────┐ ║
║  │                 │ │                 │ │                                 │ ║
║  │   PostgreSQL    │ │     Redis       │ │      Celery Workers             │ ║
║  │   (Primary DB)  │ │  (Cache/Queue)  │ │    (Background Jobs)            │ ║
║  │                 │ │                 │ │                                 │ ║
║  │  - Users        │ │  - Sessions     │ │  - Sync transactions            │ ║
║  │  - Accounts     │ │  - Rate limits  │ │  - Generate predictions         │ ║
║  │  - Transactions │ │  - Pulse cache  │ │  - Process alerts               │ ║
║  │  - Subscriptions│ │  - Job queues   │ │  - Scan Gmail                   │ ║
║  │  - Alerts       │ │                 │ │  - Send notifications           │ ║
║  │  - Predictions  │ │                 │ │                                 │ ║
║  │                 │ │                 │ │                                 │ ║
║  └─────────────────┘ └─────────────────┘ └─────────────────────────────────┘ ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                            EXTERNAL SERVICES                                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ║
║  │               │  │               │  │               │  │               │  ║
║  │     PLAID     │  │  GMAIL API    │  │    STRIPE     │  │   FIREBASE    │  ║
║  │               │  │               │  │               │  │               │  ║
║  │  Bank linking │  │ Email scan    │  │  Payments     │  │  Auth + Push  │  ║
║  │  Transactions │  │ Receipt parse │  │  Subscriptions│  │  FCM          │  ║
║  │  Balances     │  │               │  │               │  │               │  ║
║  │               │  │               │  │               │  │               │  ║
║  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

### 4.4 Data Flow Diagrams

#### 4.4.1 User Links Bank Account (Plaid Flow)

```
┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
│ Mobile │     │Backend │     │ Plaid  │     │  Bank  │     │   DB   │
└───┬────┘     └───┬────┘     └───┬────┘     └───┬────┘     └───┬────┘
    │              │              │              │              │
    │ 1. Open Plaid│              │              │              │
    │─────────────▶│              │              │              │
    │              │              │              │              │
    │              │ 2. Get link_token          │              │
    │              │─────────────▶│              │              │
    │              │              │              │              │
    │              │◀─────────────│              │              │
    │◀─────────────│ 3. link_token│              │              │
    │              │              │              │              │
    │ 4. User selects bank & logs in            │              │
    │────────────────────────────▶│              │              │
    │              │              │ 5. Verify    │              │
    │              │              │─────────────▶│              │
    │              │              │◀─────────────│              │
    │◀────────────────────────────│              │              │
    │ 6. public_token             │              │              │
    │              │              │              │              │
    │ 7. Exchange  │              │              │              │
    │─────────────▶│              │              │              │
    │              │ 8. Exchange for access_token│              │
    │              │─────────────▶│              │              │
    │              │◀─────────────│              │              │
    │              │ 9. access_token (encrypted) │              │
    │              │─────────────────────────────────────────▶│
    │              │              │              │              │
    │              │ 10. Fetch accounts          │              │
    │              │─────────────▶│              │              │
    │              │◀─────────────│              │              │
    │              │─────────────────────────────────────────▶│
    │◀─────────────│              │              │              │
    │ 11. Success! │              │              │              │
    │              │              │              │              │
```

**Security Note:** The mobile app NEVER sees the `access_token`. It stays server-side, encrypted with AES-256.

---

#### 4.4.2 Daily Money Pulse Calculation

```
┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
│ Mobile │     │Backend │     │ Redis  │     │   DB   │
└───┬────┘     └───┬────┘     └───┬────┘     └───┬────┘
    │              │              │              │
    │ GET /pulse   │              │              │
    │─────────────▶│              │              │
    │              │              │              │
    │              │ Check cache  │              │
    │              │─────────────▶│              │
    │              │              │              │
    │              │ Cache MISS   │              │
    │              │◀─────────────│              │
    │              │              │              │
    │              │ Get accounts & transactions │
    │              │─────────────────────────────▶
    │              │◀─────────────────────────────
    │              │              │              │
    │              │              │              │
    │      ┌───────┴───────┐     │              │
    │      │ AI CALCULATION │     │              │
    │      │               │     │              │
    │      │ total_balance │     │              │
    │      │ - upcoming_bills    │              │
    │      │ - pending     │     │              │
    │      │ - buffer      │     │              │
    │      │ = safe_to_spend     │              │
    │      │               │     │              │
    │      │ Determine:    │     │              │
    │      │ SAFE/CAUTION/ │     │              │
    │      │ FREEZE        │     │              │
    │      └───────┬───────┘     │              │
    │              │              │              │
    │              │ Cache result │              │
    │              │─────────────▶│              │
    │              │              │              │
    │◀─────────────│              │              │
    │  {           │              │              │
    │   status: "SAFE",          │              │
    │   safe_to_spend: 342.50,   │              │
    │   ...        │              │              │
    │  }           │              │              │
```

---

#### 4.4.3 Alert Generation (Background Job)

```
┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
│ Celery │     │   AI   │     │   DB   │     │Firebase│     │ Mobile │
│ Worker │     │ Engine │     │        │     │  FCM   │     │        │
└───┬────┘     └───┬────┘     └───┬────┘     └───┬────┘     └───┬────┘
    │              │              │              │              │
    │ Scheduled job (daily 6am)  │              │              │
    │              │              │              │              │
    │ Get all users│              │              │              │
    │─────────────────────────────▶              │              │
    │◀─────────────────────────────              │              │
    │              │              │              │              │
    │ For each user:             │              │              │
    │              │              │              │              │
    │ Run predictions            │              │              │
    │─────────────▶│              │              │              │
    │              │ Analyze patterns            │              │
    │              │─────────────▶│              │              │
    │              │◀─────────────│              │              │
    │◀─────────────│              │              │              │
    │ [Prediction results]       │              │              │
    │              │              │              │              │
    │ If HIGH/CRITICAL risk:     │              │              │
    │              │              │              │              │
    │ Create alert│              │              │              │
    │─────────────────────────────▶              │              │
    │              │              │              │              │
    │ Send push notification     │              │              │
    │───────────────────────────────────────────▶│              │
    │              │              │              │─────────────▶│
    │              │              │              │  "Warning:   │
    │              │              │              │  Low balance │
    │              │              │              │  in 3 days"  │
```

---

### 4.5 Layer Responsibilities

| Layer | Technology | Responsibility |
|-------|------------|----------------|
| **Mobile** | Dart | UI rendering, local state, API calls, push handling, offline cache |
| **API Gateway** | nginx / AWS ALB | SSL termination, rate limiting, load balancing, request routing |
| **API Layer** | FastAPI routes | Request validation, authentication, response formatting |
| **Service Layer** | Python classes | Business logic, orchestration, external API calls |
| **AI Layer** | Python + NumPy | Predictions, calculations, pattern detection |
| **Data Layer** | SQLAlchemy | Database operations, queries, transactions |
| **Cache** | Redis | Sessions, rate limits, pulse cache, job queues |
| **Queue** | Celery + Redis | Background jobs, scheduled tasks, async processing |
| **Database** | PostgreSQL | Persistent data storage, ACID transactions |

---

### 4.6 Why This Architecture?

| Decision | Rationale |
|----------|-----------|
| **Monolith backend** | Faster MVP development, easier debugging, lower infrastructure cost, small team friendly |
| **Separate mobile app** | Better UX, offline capability, push notifications, app store distribution |
| **Redis cache** | Sub-100ms pulse response, session management, rate limiting |
| **Celery workers** | Non-blocking bank syncs, scheduled predictions, won't slow down API |
| **PostgreSQL** | ACID compliance critical for financial data integrity |
| **API Gateway** | Security layer before app code, SSL termination, DDoS protection |
| **Firebase Auth** | Battle-tested auth, social login, reduces implementation risk |

---

### 4.7 Architecture Evolution Path

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ARCHITECTURE EVOLUTION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1 (MVP)              PHASE 2 (Growth)           PHASE 3 (Scale)     │
│  0 - 10K users              10K - 100K users           100K+ users         │
│                                                                             │
│  ┌───────────────┐          ┌───────────────┐          ┌───────────────┐   │
│  │               │          │   MODULAR     │          │ MICROSERVICES │   │
│  │   MONOLITH    │   ───▶   │   MONOLITH    │   ───▶   │               │   │
│  │               │          │               │          │ ┌───┐ ┌───┐   │   │
│  │  All services │          │  Internal     │          │ │Auth│ │Bank│  │   │
│  │  in one app   │          │  service      │          │ └───┘ └───┘   │   │
│  │               │          │  boundaries   │          │ ┌───┐ ┌───┐   │   │
│  │               │          │               │          │ │AI │ │Notif│  │   │
│  │               │          │               │          │ └───┘ └───┘   │   │
│  └───────────────┘          └───────────────┘          └───────────────┘   │
│                                                                             │
│  Timeline: Months 1-6       Timeline: Months 6-18      Timeline: 18+       │
│                                                                             │
│  Focus:                     Focus:                     Focus:              │
│  - Ship fast                - Define service APIs      - Independent deploy│
│  - Prove product            - Add observability        - Team autonomy     │
│  - Find PMF                 - Improve testing          - Global scale      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key Insight:** You can run a $1M+/year business on a monolith. Only split to microservices when you have:
- Multiple independent teams (5+ engineers)
- Different scaling requirements per service
- Clear service boundaries proven by usage patterns

---

### 4.8 Backend Directory Structure

```
/money-guardian/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                    # FastAPI app entry point
│   │   │
│   │   ├── config/
│   │   │   ├── __init__.py
│   │   │   ├── settings.py            # Environment configuration
│   │   │   ├── database.py            # Database connection
│   │   │   ├── redis.py               # Redis connection
│   │   │   └── security.py            # Security settings
│   │   │
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── deps.py                # Dependency injection
│   │   │   └── v1/
│   │   │       ├── __init__.py
│   │   │       ├── router.py          # API router aggregator
│   │   │       ├── auth.py            # Authentication endpoints
│   │   │       ├── users.py           # User management
│   │   │       ├── banking.py         # Plaid bank connection
│   │   │       ├── accounts.py        # Bank account management
│   │   │       ├── transactions.py    # Transaction endpoints
│   │   │       ├── subscriptions.py   # Subscription detection
│   │   │       ├── alerts.py          # Alert management
│   │   │       ├── predictions.py     # AI predictions
│   │   │       ├── pulse.py           # Daily Money Pulse
│   │   │       ├── gmail.py           # Gmail OAuth & scan
│   │   │       ├── billing.py         # Stripe subscription
│   │   │       └── webhooks.py        # External webhooks
│   │   │
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── security.py            # JWT, encryption
│   │   │   ├── exceptions.py          # Custom exceptions
│   │   │   ├── rate_limiting.py       # Rate limiter
│   │   │   └── middleware.py          # Request middleware
│   │   │
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── user.py                # User model
│   │   │   ├── bank_connection.py     # Plaid connection
│   │   │   ├── account.py             # Bank account
│   │   │   ├── transaction.py         # Transaction
│   │   │   ├── subscription.py        # Detected subscription
│   │   │   ├── alert.py               # User alert
│   │   │   ├── prediction.py          # AI prediction
│   │   │   ├── gmail_token.py         # Gmail OAuth token
│   │   │   ├── email_receipt.py       # Parsed receipt
│   │   │   └── billing.py             # Pro subscription
│   │   │
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   ├── user.py                # User DTOs
│   │   │   ├── banking.py             # Banking DTOs
│   │   │   ├── transaction.py         # Transaction DTOs
│   │   │   ├── subscription.py        # Subscription DTOs
│   │   │   ├── alert.py               # Alert DTOs
│   │   │   ├── prediction.py          # Prediction DTOs
│   │   │   ├── pulse.py               # Daily Pulse DTOs
│   │   │   └── billing.py             # Billing DTOs
│   │   │
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── auth_service.py        # Authentication logic
│   │   │   ├── user_service.py        # User business logic
│   │   │   ├── plaid_service.py       # Plaid API integration
│   │   │   ├── account_service.py     # Account management
│   │   │   ├── transaction_service.py # Transaction processing
│   │   │   ├── subscription_service.py# Subscription detection
│   │   │   ├── alert_service.py       # Alert generation
│   │   │   ├── gmail_service.py       # Gmail API integration
│   │   │   ├── stripe_service.py      # Stripe integration
│   │   │   ├── notification_service.py# Push notifications
│   │   │   ├── encryption_service.py  # Data encryption
│   │   │   └── cache_service.py       # Redis caching
│   │   │
│   │   ├── ai/
│   │   │   ├── __init__.py
│   │   │   ├── predictor.py           # Overdraft prediction engine
│   │   │   ├── categorizer.py         # Transaction categorization
│   │   │   ├── subscription_detector.py# Subscription pattern detection
│   │   │   ├── safe_to_spend.py       # Safe-to-spend calculator
│   │   │   ├── email_parser.py        # Email receipt parser
│   │   │   └── waste_detector.py      # Subscription waste detection
│   │   │
│   │   ├── workers/
│   │   │   ├── __init__.py
│   │   │   ├── celery_app.py          # Celery configuration
│   │   │   ├── tasks/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── sync_transactions.py# Bank sync job
│   │   │   │   ├── generate_predictions.py# Daily prediction job
│   │   │   │   ├── process_alerts.py  # Alert processing
│   │   │   │   ├── gmail_scan.py      # Gmail scanning job
│   │   │   │   ├── subscription_refresh.py# Subscription updates
│   │   │   │   └── notification_sender.py# Push notification job
│   │   │   └── schedulers/
│   │   │       ├── __init__.py
│   │   │       └── daily_jobs.py      # Cron job definitions
│   │   │
│   │   └── utils/
│   │       ├── __init__.py
│   │       ├── date_utils.py          # Date helpers
│   │       ├── money_utils.py         # Currency formatting
│   │       └── validators.py          # Input validation
│   │
│   ├── migrations/                     # Alembic migrations
│   │   ├── versions/
│   │   └── env.py
│   │
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── conftest.py                # Pytest fixtures
│   │   ├── test_api/
│   │   ├── test_services/
│   │   └── test_ai/
│   │
│   ├── alembic.ini
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .env.example
│   └── pyproject.toml
│
├── mobile/                             # Money Guardian mobile app (see Section 7)
├── docs/                               # Documentation
├── infrastructure/                     # Terraform/K8s configs
└── .github/workflows/                  # CI/CD pipelines
```

---

## 5. Database Schema

### 5.1 Entity Relationship Diagram

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────────┐
│    users    │───────│ bank_connections │───────│  bank_accounts  │
└─────────────┘       └──────────────────┘       └─────────────────┘
      │                                                   │
      │                                                   │
      ▼                                                   ▼
┌─────────────┐       ┌──────────────────┐       ┌─────────────────┐
│   alerts    │       │  subscriptions   │◄──────│  transactions   │
└─────────────┘       └──────────────────┘       └─────────────────┘
      │                       │
      │                       │
      ▼                       ▼
┌─────────────┐       ┌──────────────────┐       ┌─────────────────┐
│ predictions │       │ gmail_connections│───────│ email_receipts  │
└─────────────┘       └──────────────────┘       └─────────────────┘
      │
      ▼
┌──────────────────┐
│ daily_pulse_cache│
└──────────────────┘
```

### 5.2 Table Definitions

#### 5.2.1 users

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid VARCHAR(128) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    phone VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    display_name VARCHAR(100),
    avatar_url VARCHAR(500),
    timezone VARCHAR(50) DEFAULT 'America/New_York',

    -- Pro Subscription
    subscription_tier VARCHAR(20) DEFAULT 'FREE', -- FREE, PRO, FAMILY
    subscription_status VARCHAR(20) DEFAULT 'ACTIVE',
    stripe_customer_id VARCHAR(100),
    pro_expires_at TIMESTAMP WITH TIME ZONE,

    -- Settings
    notification_preferences JSONB DEFAULT '{
        "push": true,
        "email": false,
        "sms": false
    }',
    alert_thresholds JSONB DEFAULT '{
        "low_balance": 100,
        "overdraft_warning": 50
    }',

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE -- Soft delete for GDPR
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_stripe_customer ON users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
```

#### 5.2.2 bank_connections

```sql
CREATE TABLE bank_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Plaid Data (encrypted at application level)
    plaid_access_token_encrypted TEXT NOT NULL,
    plaid_item_id VARCHAR(100) NOT NULL UNIQUE,
    institution_id VARCHAR(50),
    institution_name VARCHAR(100),
    institution_logo_url VARCHAR(500),

    -- Connection Status
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, ERROR, DISCONNECTED
    error_code VARCHAR(50),
    error_message TEXT,
    requires_reauth BOOLEAN DEFAULT FALSE,

    -- Sync Tracking
    last_synced_at TIMESTAMP WITH TIME ZONE,
    cursor VARCHAR(500), -- Plaid sync cursor for incremental updates

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_bank_connections_user ON bank_connections(user_id);
CREATE INDEX idx_bank_connections_plaid_item ON bank_connections(plaid_item_id);
CREATE INDEX idx_bank_connections_status ON bank_connections(user_id, status);
```

#### 5.2.3 bank_accounts

```sql
CREATE TABLE bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    connection_id UUID NOT NULL REFERENCES bank_connections(id) ON DELETE CASCADE,

    -- Plaid Account Data
    plaid_account_id VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100),
    official_name VARCHAR(200),
    type VARCHAR(30), -- checking, savings, credit, loan, investment
    subtype VARCHAR(50), -- checking, savings, credit card, etc.
    mask VARCHAR(10), -- Last 4 digits

    -- Balances
    current_balance DECIMAL(15,2),
    available_balance DECIMAL(15,2),
    credit_limit DECIMAL(15,2), -- For credit cards
    balance_currency VARCHAR(3) DEFAULT 'USD',
    balance_updated_at TIMESTAMP WITH TIME ZONE,

    -- User Preferences
    is_primary BOOLEAN DEFAULT FALSE,
    include_in_pulse BOOLEAN DEFAULT TRUE,
    nickname VARCHAR(50),

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_bank_accounts_user ON bank_accounts(user_id);
CREATE INDEX idx_bank_accounts_connection ON bank_accounts(connection_id);
CREATE INDEX idx_bank_accounts_plaid ON bank_accounts(plaid_account_id);
CREATE INDEX idx_bank_accounts_primary ON bank_accounts(user_id, is_primary) WHERE is_primary = TRUE;
```

#### 5.2.4 transactions

```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES bank_accounts(id) ON DELETE CASCADE,

    -- Plaid Transaction Data
    plaid_transaction_id VARCHAR(100) NOT NULL UNIQUE,
    amount DECIMAL(15,2) NOT NULL, -- Positive = debit/expense, Negative = credit/income
    currency VARCHAR(3) DEFAULT 'USD',
    date DATE NOT NULL,
    authorized_date DATE,

    -- Merchant Info
    merchant_name VARCHAR(200),
    merchant_logo_url VARCHAR(500),
    merchant_category VARCHAR(100),

    -- Categorization
    plaid_category VARCHAR(100)[], -- Array of category hierarchy
    plaid_category_id VARCHAR(50),
    custom_category VARCHAR(50), -- User override

    -- Metadata
    name VARCHAR(500), -- Transaction description from bank
    payment_channel VARCHAR(30), -- online, in store, other
    pending BOOLEAN DEFAULT FALSE,

    -- AI Analysis
    is_recurring BOOLEAN,
    is_subscription BOOLEAN,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_date ON transactions(user_id, date DESC);
CREATE INDEX idx_transactions_account ON transactions(account_id, date DESC);
CREATE INDEX idx_transactions_plaid ON transactions(plaid_transaction_id);
CREATE INDEX idx_transactions_subscription ON transactions(subscription_id) WHERE subscription_id IS NOT NULL;
CREATE INDEX idx_transactions_recurring ON transactions(user_id, is_recurring) WHERE is_recurring = TRUE;
CREATE INDEX idx_transactions_merchant ON transactions(user_id, merchant_name);
```

#### 5.2.5 subscriptions

```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Subscription Details
    name VARCHAR(200) NOT NULL,
    merchant_name VARCHAR(200),
    logo_url VARCHAR(500),
    category VARCHAR(50), -- streaming, software, fitness, etc.

    -- Amount & Frequency
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    frequency VARCHAR(20) NOT NULL, -- weekly, biweekly, monthly, quarterly, yearly
    monthly_equivalent DECIMAL(15,2), -- Normalized to monthly for comparison

    -- Dates
    first_detected_at DATE,
    next_charge_date DATE,
    last_charge_date DATE,

    -- Source
    source VARCHAR(20) NOT NULL, -- bank, email, manual
    source_account_id UUID REFERENCES bank_accounts(id) ON DELETE SET NULL,
    confidence_score DECIMAL(3,2), -- 0.00 to 1.00, how confident detection is

    -- Price History
    price_history JSONB DEFAULT '[]', -- [{date, amount}]
    price_increased BOOLEAN DEFAULT FALSE,
    price_increase_amount DECIMAL(15,2),

    -- Status & Analysis
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, PAUSED, CANCELLED, WASTE_DETECTED
    waste_score DECIMAL(3,2), -- 0.00 to 1.00
    waste_reason TEXT,
    last_used_at TIMESTAMP WITH TIME ZONE, -- For usage tracking

    -- User Actions
    is_hidden BOOLEAN DEFAULT FALSE,
    user_notes TEXT,
    reminder_enabled BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(user_id, status);
CREATE INDEX idx_subscriptions_next_charge ON subscriptions(user_id, next_charge_date);
CREATE INDEX idx_subscriptions_waste ON subscriptions(user_id, waste_score DESC) WHERE waste_score > 0.5;
```

#### 5.2.6 alerts

```sql
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Alert Type & Severity
    type VARCHAR(50) NOT NULL,
    -- Types: overdraft_warning, low_balance, subscription_charge,
    --        trial_ending, price_increase, large_purchase,
    --        unusual_activity, upcoming_bill
    severity VARCHAR(20) NOT NULL, -- info, warning, critical

    -- Content
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    action_text VARCHAR(100), -- "View Details", "Snooze", etc.
    action_url VARCHAR(500),

    -- Related Entities (optional, for context)
    account_id UUID REFERENCES bank_accounts(id) ON DELETE SET NULL,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    prediction_id UUID REFERENCES predictions(id) ON DELETE SET NULL,

    -- Amount (if applicable)
    amount DECIMAL(15,2),

    -- State
    status VARCHAR(20) DEFAULT 'UNREAD', -- UNREAD, READ, DISMISSED, ACTIONED, SNOOZED
    read_at TIMESTAMP WITH TIME ZONE,
    dismissed_at TIMESTAMP WITH TIME ZONE,
    snoozed_until TIMESTAMP WITH TIME ZONE,

    -- Delivery Tracking
    push_sent BOOLEAN DEFAULT FALSE,
    push_sent_at TIMESTAMP WITH TIME ZONE,
    email_sent BOOLEAN DEFAULT FALSE,
    sms_sent BOOLEAN DEFAULT FALSE,

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE -- Auto-expire old alerts
);

CREATE INDEX idx_alerts_user_status ON alerts(user_id, status);
CREATE INDEX idx_alerts_user_created ON alerts(user_id, created_at DESC);
CREATE INDEX idx_alerts_unread ON alerts(user_id, status, created_at DESC) WHERE status = 'UNREAD';
CREATE INDEX idx_alerts_type ON alerts(user_id, type);
```

#### 5.2.7 predictions

```sql
CREATE TABLE predictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Prediction Type
    type VARCHAR(50) NOT NULL, -- overdraft, low_balance, subscription_spike, income_delay

    -- Prediction Data
    prediction_date DATE NOT NULL,
    risk_level VARCHAR(20) NOT NULL, -- LOW, MEDIUM, HIGH, CRITICAL
    confidence_score DECIMAL(3,2), -- 0.00 to 1.00
    predicted_balance DECIMAL(15,2),

    -- Analysis Details
    factors JSONB NOT NULL DEFAULT '[]',
    -- Array of: {type, description, impact_amount, severity}

    recommendations JSONB NOT NULL DEFAULT '[]',
    -- Array of: {text, priority, action_type}

    -- Outcome Tracking (for ML feedback loop)
    was_accurate BOOLEAN,
    actual_balance DECIMAL(15,2),
    verified_at TIMESTAMP WITH TIME ZONE,
    user_feedback VARCHAR(20), -- helpful, not_helpful, ignored

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_predictions_user_date ON predictions(user_id, prediction_date DESC);
CREATE INDEX idx_predictions_risk ON predictions(user_id, risk_level) WHERE risk_level IN ('HIGH', 'CRITICAL');
CREATE INDEX idx_predictions_unverified ON predictions(user_id, was_accurate) WHERE was_accurate IS NULL;
```

#### 5.2.8 gmail_connections

```sql
CREATE TABLE gmail_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- OAuth Tokens (encrypted at application level)
    access_token_encrypted TEXT NOT NULL,
    refresh_token_encrypted TEXT NOT NULL,
    token_expires_at TIMESTAMP WITH TIME ZONE,

    -- Scopes
    granted_scopes TEXT[], -- Array of granted OAuth scopes

    -- Sync Status
    last_synced_at TIMESTAMP WITH TIME ZONE,
    last_history_id VARCHAR(50), -- Gmail history ID for incremental sync
    emails_scanned_count INTEGER DEFAULT 0,

    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE', -- ACTIVE, ERROR, DISCONNECTED, RATE_LIMITED
    error_message TEXT,

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT one_gmail_per_user UNIQUE(user_id)
);

CREATE INDEX idx_gmail_connections_user ON gmail_connections(user_id);
CREATE INDEX idx_gmail_connections_status ON gmail_connections(status);
```

#### 5.2.9 email_receipts

```sql
CREATE TABLE email_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gmail_connection_id UUID REFERENCES gmail_connections(id) ON DELETE SET NULL,

    -- Email Metadata (no full email content stored)
    gmail_message_id VARCHAR(100) UNIQUE,
    from_email VARCHAR(255),
    subject_hash VARCHAR(64), -- Hashed subject for privacy
    received_at TIMESTAMP WITH TIME ZONE,

    -- Parsed Data
    merchant_name VARCHAR(200),
    amount DECIMAL(15,2),
    currency VARCHAR(3),
    receipt_type VARCHAR(30), -- purchase, subscription, renewal, refund, trial_start, trial_end

    -- Extracted Details
    subscription_name VARCHAR(200),
    renewal_date DATE,
    trial_end_date DATE,

    -- Matching
    matched_subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    matched_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    match_confidence DECIMAL(3,2),

    -- Audit
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_email_receipts_user ON email_receipts(user_id);
CREATE INDEX idx_email_receipts_merchant ON email_receipts(user_id, merchant_name);
CREATE INDEX idx_email_receipts_date ON email_receipts(user_id, received_at DESC);
CREATE INDEX idx_email_receipts_unmatched ON email_receipts(user_id, matched_subscription_id)
    WHERE matched_subscription_id IS NULL;
```

#### 5.2.10 daily_pulse_cache

```sql
CREATE TABLE daily_pulse_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Pulse Data
    pulse_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL, -- SAFE, CAUTION, FREEZE
    safe_to_spend DECIMAL(15,2) NOT NULL,

    -- Breakdown
    total_balance DECIMAL(15,2),
    pending_amount DECIMAL(15,2),
    upcoming_bills DECIMAL(15,2),
    reserved_buffer DECIMAL(15,2),

    -- Additional Context
    days_until_income INTEGER,
    overdraft_risk_score DECIMAL(3,2),

    -- Risk Factors & Insights
    risk_factors JSONB DEFAULT '[]',
    quick_insights JSONB DEFAULT '[]',
    upcoming_bills_detail JSONB DEFAULT '[]',

    -- Accounts Included
    accounts_included UUID[],

    -- Audit
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT unique_user_pulse_date UNIQUE(user_id, pulse_date)
);

CREATE INDEX idx_daily_pulse_user_date ON daily_pulse_cache(user_id, pulse_date DESC);
```

#### 5.2.11 audit_logs

```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Action Details
    action VARCHAR(100) NOT NULL,
    -- Actions: user.login, user.logout, bank.connect, bank.disconnect,
    --          gmail.connect, gmail.disconnect, data.export, data.delete,
    --          subscription.cancel, settings.update, billing.subscribe

    resource_type VARCHAR(50), -- user, bank_connection, subscription, etc.
    resource_id UUID,

    -- Context
    ip_address INET,
    user_agent TEXT,

    -- Additional Data
    metadata JSONB, -- Action-specific details

    -- Audit (immutable - no updated_at)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, created_at DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
```

---

## 6. API Specification

### 6.1 API Overview

**Base URL:** `https://api.moneyguardian.app/api/v1`

**Authentication:** Bearer token (JWT) in Authorization header

**Rate Limits:**

| Endpoint Category | Limit |
|-------------------|-------|
| Authentication | 5/minute |
| Banking operations | 10/minute |
| Pulse/Dashboard | 60/minute |
| Transactions | 30/minute |
| Gmail operations | 3/minute |
| Default | 100/minute |

### 6.2 Endpoint Specifications

#### 6.2.1 Authentication

```yaml
# Register new user
POST /auth/register
Request:
  firebase_token: string (required)
  display_name: string (optional)
  timezone: string (optional)
Response:
  user: User object
  access_token: string
  refresh_token: string

# Login existing user
POST /auth/login
Request:
  firebase_token: string (required)
Response:
  user: User object
  access_token: string
  refresh_token: string

# Refresh access token
POST /auth/refresh
Request:
  refresh_token: string (required)
Response:
  access_token: string
  refresh_token: string

# Logout
DELETE /auth/logout
Response:
  success: boolean

# Delete account (GDPR)
DELETE /auth/account
Request:
  confirmation: string ("DELETE MY ACCOUNT")
Response:
  success: boolean
  message: string
```

#### 6.2.2 User Profile

```yaml
# Get current user
GET /users/me
Response:
  id: uuid
  email: string
  display_name: string
  subscription_tier: string
  notification_preferences: object
  alert_thresholds: object
  created_at: datetime

# Update profile
PATCH /users/me
Request:
  display_name: string (optional)
  timezone: string (optional)
Response:
  user: User object

# Get settings
GET /users/me/settings
Response:
  notification_preferences: object
  alert_thresholds: object

# Update settings
PATCH /users/me/settings
Request:
  notification_preferences: object (optional)
  alert_thresholds: object (optional)
Response:
  settings: object
```

#### 6.2.3 Banking (Plaid)

```yaml
# Get Plaid Link token
POST /banking/link-token
Response:
  link_token: string
  expiration: datetime

# Exchange public token for access
POST /banking/exchange
Request:
  public_token: string (required)
  institution_id: string (required)
  institution_name: string (required)
Response:
  connection: BankConnection object
  accounts: BankAccount[]

# List bank connections
GET /banking/connections
Response:
  connections: BankConnection[]

# Remove bank connection
DELETE /banking/connections/{connection_id}
Response:
  success: boolean

# Force sync connection
POST /banking/connections/{connection_id}/sync
Response:
  success: boolean
  transactions_added: integer
  transactions_modified: integer
```

#### 6.2.4 Bank Accounts

```yaml
# List all accounts
GET /accounts
Query params:
  include_hidden: boolean (default: false)
Response:
  accounts: BankAccount[]

# Get account details
GET /accounts/{account_id}
Response:
  account: BankAccount object
  recent_transactions: Transaction[]

# Update account preferences
PATCH /accounts/{account_id}
Request:
  nickname: string (optional)
  include_in_pulse: boolean (optional)
  is_primary: boolean (optional)
Response:
  account: BankAccount object

# Get real-time balance
GET /accounts/{account_id}/balance
Response:
  current_balance: decimal
  available_balance: decimal
  updated_at: datetime
```

#### 6.2.5 Transactions

```yaml
# List transactions
GET /transactions
Query params:
  account_id: uuid (optional)
  start_date: date (optional)
  end_date: date (optional)
  category: string (optional)
  is_recurring: boolean (optional)
  limit: integer (default: 50, max: 200)
  offset: integer (default: 0)
Response:
  transactions: Transaction[]
  total: integer
  has_more: boolean

# Get transaction details
GET /transactions/{transaction_id}
Response:
  transaction: Transaction object

# Update transaction
PATCH /transactions/{transaction_id}
Request:
  custom_category: string (optional)
  notes: string (optional)
Response:
  transaction: Transaction object

# Search transactions
GET /transactions/search
Query params:
  q: string (required, min 2 chars)
  limit: integer (default: 20)
Response:
  transactions: Transaction[]
```

#### 6.2.6 Daily Money Pulse

```yaml
# Get today's pulse
GET /pulse
Response:
  status: string (SAFE | CAUTION | FREEZE)
  safe_to_spend: decimal
  total_balance: decimal
  upcoming_bills: decimal
  reserved_amount: decimal
  days_until_income: integer | null
  risk_factors: RiskFactor[]
  quick_insights: string[]
  calculated_at: datetime

# Get pulse history
GET /pulse/history
Query params:
  days: integer (default: 30, max: 90)
Response:
  history: DailyPulse[]

# Get detailed breakdown
GET /pulse/breakdown
Response:
  accounts: AccountBalance[]
  upcoming_bills: UpcomingBill[]
  pending_transactions: Transaction[]
  income_projection: IncomeProjection
```

#### 6.2.7 Subscriptions

```yaml
# List all subscriptions
GET /subscriptions
Query params:
  status: string (optional) - ACTIVE, PAUSED, CANCELLED
  include_hidden: boolean (default: false)
Response:
  subscriptions: Subscription[]
  monthly_total: decimal
  yearly_total: decimal

# Get subscription details
GET /subscriptions/{subscription_id}
Response:
  subscription: Subscription object
  related_transactions: Transaction[]
  price_history: PriceChange[]

# Update subscription
PATCH /subscriptions/{subscription_id}
Request:
  is_hidden: boolean (optional)
  user_notes: string (optional)
  reminder_enabled: boolean (optional)
Response:
  subscription: Subscription object

# Snooze subscription alerts
POST /subscriptions/{subscription_id}/snooze
Request:
  days: integer (required, max: 30)
Response:
  subscription: Subscription object

# Get waste analysis
GET /subscriptions/waste
Response:
  waste_subscriptions: Subscription[]
  potential_yearly_savings: decimal
  recommendations: WasteRecommendation[]
```

#### 6.2.8 Alerts

```yaml
# List alerts
GET /alerts
Query params:
  status: string (optional) - UNREAD, READ, ALL
  type: string (optional)
  limit: integer (default: 50)
Response:
  alerts: Alert[]
  unread_count: integer

# Get unread count
GET /alerts/unread-count
Response:
  count: integer

# Mark alert as read
PATCH /alerts/{alert_id}/read
Response:
  alert: Alert object

# Dismiss alert
PATCH /alerts/{alert_id}/dismiss
Response:
  success: boolean

# Snooze alert
POST /alerts/{alert_id}/snooze
Request:
  hours: integer (required, max: 168)
Response:
  alert: Alert object
```

#### 6.2.9 Predictions

```yaml
# Get current predictions
GET /predictions
Query params:
  days: integer (default: 14, max: 30)
Response:
  predictions: Prediction[]
  overall_risk: string

# Get upcoming risk events
GET /predictions/upcoming
Response:
  events: RiskEvent[]
  high_risk_days: date[]
```

#### 6.2.10 Gmail Integration

```yaml
# Get Gmail OAuth URL
GET /gmail/auth-url
Response:
  auth_url: string
  state: string

# OAuth callback
POST /gmail/callback
Request:
  code: string (required)
  state: string (required)
Response:
  connection: GmailConnection object

# Get connection status
GET /gmail/status
Response:
  connected: boolean
  last_synced_at: datetime | null
  emails_scanned: integer
  subscriptions_found: integer

# Trigger manual scan
POST /gmail/scan
Response:
  job_id: string
  status: string

# Disconnect Gmail
DELETE /gmail/disconnect
Response:
  success: boolean
```

#### 6.2.11 Billing (Stripe)

```yaml
# Get available plans
GET /billing/plans
Response:
  plans: Plan[]

# Create checkout session
POST /billing/checkout
Request:
  plan_id: string (required)
  success_url: string (required)
  cancel_url: string (required)
Response:
  checkout_url: string
  session_id: string

# Get current subscription
GET /billing/subscription
Response:
  subscription: BillingSubscription object | null

# Get billing portal URL
POST /billing/portal
Request:
  return_url: string (required)
Response:
  portal_url: string

# Cancel subscription
POST /billing/cancel
Request:
  reason: string (optional)
  feedback: string (optional)
Response:
  subscription: BillingSubscription object
  effective_date: date
```

#### 6.2.12 Webhooks (Server-to-Server)

```yaml
# Plaid webhooks
POST /webhooks/plaid
Headers:
  Plaid-Verification: string
Body:
  webhook_type: string
  webhook_code: string
  item_id: string
  ...

# Stripe webhooks
POST /webhooks/stripe
Headers:
  Stripe-Signature: string
Body:
  type: string
  data: object
  ...
```

---

## 7. Mobile App Architecture

### 7.1 Directory Structure

```
/mobile/
├── lib/
│   ├── main.dart                      # App entry point
│   ├── app.dart                       # MaterialApp configuration
│   │
│   ├── config/
│   │   ├── app_config.dart            # Environment config
│   │   ├── routes.dart                # Route definitions
│   │   ├── theme.dart                 # App theme (light/dark)
│   │   └── constants.dart             # App constants
│   │
│   ├── core/
│   │   ├── di/
│   │   │   └── injection.dart         # GetIt dependency injection
│   │   ├── error/
│   │   │   ├── exceptions.dart        # Custom exceptions
│   │   │   └── failures.dart          # Failure types
│   │   ├── network/
│   │   │   ├── api_client.dart        # Dio HTTP client
│   │   │   ├── api_interceptors.dart  # Auth, logging interceptors
│   │   │   └── network_info.dart      # Connectivity check
│   │   ├── storage/
│   │   │   ├── secure_storage.dart    # Encrypted local storage
│   │   │   └── preferences.dart       # Shared preferences
│   │   └── utils/
│   │       ├── date_formatter.dart
│   │       ├── currency_formatter.dart
│   │       └── validators.dart
│   │
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── remote/                # API data sources
│   │   │   │   ├── auth_remote_ds.dart
│   │   │   │   ├── banking_remote_ds.dart
│   │   │   │   ├── pulse_remote_ds.dart
│   │   │   │   ├── transactions_remote_ds.dart
│   │   │   │   ├── subscriptions_remote_ds.dart
│   │   │   │   ├── alerts_remote_ds.dart
│   │   │   │   └── billing_remote_ds.dart
│   │   │   └── local/                 # Local cache
│   │   │       ├── user_local_ds.dart
│   │   │       └── cache_local_ds.dart
│   │   ├── models/                    # JSON serializable models
│   │   │   ├── user_model.dart
│   │   │   ├── bank_account_model.dart
│   │   │   ├── transaction_model.dart
│   │   │   ├── subscription_model.dart
│   │   │   ├── alert_model.dart
│   │   │   ├── pulse_model.dart
│   │   │   └── prediction_model.dart
│   │   └── repositories/              # Repository implementations
│   │       ├── auth_repository_impl.dart
│   │       ├── banking_repository_impl.dart
│   │       ├── pulse_repository_impl.dart
│   │       ├── transactions_repository_impl.dart
│   │       ├── subscriptions_repository_impl.dart
│   │       ├── alerts_repository_impl.dart
│   │       └── billing_repository_impl.dart
│   │
│   ├── domain/
│   │   ├── entities/                  # Business entities
│   │   │   ├── user.dart
│   │   │   ├── bank_account.dart
│   │   │   ├── transaction.dart
│   │   │   ├── subscription.dart
│   │   │   ├── alert.dart
│   │   │   ├── pulse.dart
│   │   │   └── prediction.dart
│   │   ├── repositories/              # Repository interfaces
│   │   │   ├── auth_repository.dart
│   │   │   ├── banking_repository.dart
│   │   │   ├── pulse_repository.dart
│   │   │   ├── transactions_repository.dart
│   │   │   ├── subscriptions_repository.dart
│   │   │   ├── alerts_repository.dart
│   │   │   └── billing_repository.dart
│   │   └── usecases/                  # Business logic
│   │       ├── auth/
│   │       │   ├── login_usecase.dart
│   │       │   ├── register_usecase.dart
│   │       │   └── logout_usecase.dart
│   │       ├── banking/
│   │       │   ├── link_bank_usecase.dart
│   │       │   ├── get_accounts_usecase.dart
│   │       │   └── sync_accounts_usecase.dart
│   │       ├── pulse/
│   │       │   └── get_daily_pulse_usecase.dart
│   │       ├── subscriptions/
│   │       │   ├── get_subscriptions_usecase.dart
│   │       │   └── detect_waste_usecase.dart
│   │       └── alerts/
│   │           ├── get_alerts_usecase.dart
│   │           └── mark_alert_read_usecase.dart
│   │
│   ├── presentation/
│   │   ├── blocs/                     # BLoC state management (5 core BLoCs)
│   │   │   ├── auth/                  # Login/logout state
│   │   │   │   ├── auth_bloc.dart
│   │   │   │   ├── auth_event.dart
│   │   │   │   └── auth_state.dart
│   │   │   ├── pulse/                 # Daily Pulse (SAFE/CAUTION/FREEZE)
│   │   │   │   ├── pulse_bloc.dart
│   │   │   │   ├── pulse_event.dart
│   │   │   │   └── pulse_state.dart
│   │   │   ├── subscriptions/         # Subscription list + waste detection
│   │   │   │   ├── subscriptions_bloc.dart
│   │   │   │   ├── subscriptions_event.dart
│   │   │   │   └── subscriptions_state.dart
│   │   │   ├── calendar/              # Calendar with charges
│   │   │   │   └── calendar_bloc.dart
│   │   │   └── alerts/                # Alert center
│   │   │       └── alerts_bloc.dart
│   │   │
│   │   ├── pages/                     # 6-8 CORE PAGES ONLY
│   │   │   │
│   │   │   ├── auth/                  # Page 6: Auth
│   │   │   │   ├── login_page.dart
│   │   │   │   └── register_page.dart
│   │   │   │
│   │   │   ├── onboarding/            # Page 7: First-time setup
│   │   │   │   └── onboarding_page.dart
│   │   │   │
│   │   │   ├── home/                  # Page 1: Daily Pulse (MAIN)
│   │   │   │   ├── home_page.dart     # SAFE/CAUTION/FREEZE status
│   │   │   │   └── widgets/
│   │   │   │       ├── pulse_status_card.dart
│   │   │   │       ├── safe_to_spend_widget.dart
│   │   │   │       └── next_7_days_widget.dart
│   │   │   │
│   │   │   ├── subscriptions/         # Page 2: Subscriptions Hub
│   │   │   │   ├── subscriptions_page.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── subscription_card.dart
│   │   │   │       └── waste_flag_widget.dart
│   │   │   │
│   │   │   ├── calendar/              # Page 3: Calendar View
│   │   │   │   └── calendar_page.dart # Month view with sub charges
│   │   │   │
│   │   │   ├── alerts/                # Page 4: Alerts Center
│   │   │   │   ├── alerts_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── alert_card.dart
│   │   │   │
│   │   │   ├── settings/              # Page 5: Settings
│   │   │   │   └── settings_page.dart # Connections + preferences
│   │   │   │
│   │   │   └── pro/                   # Page 8: Paywall
│   │   │       └── paywall_page.dart
│   │   │
│   │   └── widgets/                   # Shared widgets
│   │       ├── common/
│   │       │   ├── mg_app_bar.dart
│   │       │   ├── mg_button.dart
│   │       │   ├── mg_card.dart
│   │       │   ├── mg_loading.dart
│   │       │   └── mg_empty_state.dart
│   │       ├── charts/
│   │       │   ├── balance_chart.dart
│   │       │   └── spending_chart.dart
│   │       └── animations/
│   │           ├── pulse_animation.dart
│   │           └── status_animation.dart
│   │
│   └── services/
│       ├── firebase_service.dart      # Firebase initialization
│       ├── notification_service.dart  # Push notifications
│       ├── plaid_service.dart         # Plaid Link SDK
│       └── analytics_service.dart     # Analytics tracking
│
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/                    # Lottie files
│   └── fonts/
│
├── ios/
├── android/
├── test/
├── integration_test/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

### 7.2 Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.0
  equatable: ^2.0.5

  # Dependency Injection
  get_it: ^7.6.0
  injectable: ^2.3.0

  # Network
  dio: ^5.4.0
  connectivity_plus: ^5.0.0

  # Local Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0
  hive_flutter: ^1.1.0

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  firebase_messaging: ^14.7.0
  firebase_analytics: ^10.7.0

  # Banking
  plaid_flutter: ^3.1.0

  # Payments
  flutter_stripe: ^10.0.0

  # UI Components
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.0
  lottie: ^3.0.0
  shimmer: ^3.0.0
  fl_chart: ^0.65.0

  # Utilities
  intl: ^0.18.0
  url_launcher: ^6.2.0
  package_info_plus: ^5.0.0
  permission_handler: ^11.0.0

  # Forms
  flutter_form_builder: ^9.1.0
  form_builder_validators: ^9.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.0
  injectable_generator: ^2.4.0
  freezed: ^2.4.0
  freezed_annotation: ^2.4.0
  json_serializable: ^6.7.0

  # Testing
  bloc_test: ^9.1.0
  mocktail: ^1.0.0

  # Linting
  flutter_lints: ^3.0.0
```

### 7.3 Screen Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         SPLASH                                   │
│                    (Check auth state)                            │
└─────────────────────────────────────────────────────────────────┘
                    │                    │
          (Not authenticated)    (Authenticated)
                    │                    │
                    ▼                    ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│       ONBOARDING        │   │         HOME            │
│    (First time only)    │   │    (Daily Pulse)        │
└─────────────────────────┘   └─────────────────────────┘
                    │                    │
                    ▼                    │
┌─────────────────────────┐              │
│      LOGIN/REGISTER     │              │
└─────────────────────────┘              │
                    │                    │
                    ▼                    │
┌─────────────────────────┐              │
│      LINK BANK          │◄─────────────┤
│   (Plaid Link flow)     │              │
└─────────────────────────┘              │
                    │                    │
                    └──────────┬─────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      MAIN APP (Bottom Nav)                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │  HOME   │  │ACCOUNTS │  │SUBSCRIP │  │ ALERTS  │            │
│  │ (Pulse) │  │         │  │  TIONS  │  │         │            │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘            │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      SETTINGS       │
                    │  - Notifications    │
                    │  - Gmail Connect    │
                    │  - Pro Upgrade      │
                    │  - Account          │
                    └─────────────────────┘
```

---

## 8. AI/ML Pipeline

### 8.1 Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      DATA COLLECTION                             │
│  Transactions │ Account Balances │ Subscriptions │ Email Data   │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FEATURE ENGINEERING                         │
│  - Spending patterns (daily, weekly, monthly)                    │
│  - Income timing detection                                       │
│  - Recurring transaction identification                          │
│  - Seasonal adjustments                                          │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI ENGINES                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Overdraft  │  │ Safe-to-    │  │Subscription │             │
│  │  Predictor  │  │   Spend     │  │  Detector   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │   Waste     │  │   Email     │                               │
│  │  Detector   │  │   Parser    │                               │
│  └─────────────┘  └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OUTPUTS                                     │
│  Daily Pulse │ Alerts │ Predictions │ Recommendations           │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 Overdraft Prediction Engine

**Purpose:** Predict overdrafts 1-14 days before they happen

**Inputs:**
- Historical transactions (90 days)
- Current account balances
- Detected recurring bills
- Income timing patterns
- User-defined buffer

**Algorithm (V1 - Rule-based):**

```python
def predict_overdraft(user_data):
    """
    14-day rolling forecast with daily projections.
    """
    predictions = []
    projected_balance = current_balance

    for day in range(1, 15):
        target_date = today + timedelta(days=day)

        # Known expenses (subscriptions, bills)
        known_expenses = get_upcoming_bills(target_date)

        # Estimated daily spending (historical average)
        avg_daily = calculate_daily_average(transactions)
        dow_multiplier = get_day_of_week_multiplier(target_date)
        estimated_spending = avg_daily * dow_multiplier

        # Expected income
        expected_income = predict_income(target_date, income_patterns)

        # Project balance
        projected_balance = (
            projected_balance
            - known_expenses
            - estimated_spending
            + expected_income
        )

        # Calculate risk
        if projected_balance < 0:
            risk = 'CRITICAL'
        elif projected_balance < 50:
            risk = 'HIGH'
        elif projected_balance < 100:
            risk = 'MEDIUM'
        else:
            risk = 'LOW'

        # Confidence decreases with forecast distance
        confidence = max(0.5, 1.0 - (day * 0.03))

        if risk in ['MEDIUM', 'HIGH', 'CRITICAL']:
            predictions.append({
                'date': target_date,
                'balance': projected_balance,
                'risk': risk,
                'confidence': confidence,
                'factors': identify_factors(target_date),
                'recommendations': generate_recommendations(risk)
            })

    return predictions
```

### 8.3 Safe-to-Spend Calculator

**Purpose:** Calculate daily "safe to spend" amount

**Formula:**
```
Safe to Spend = Available Balance
                - Upcoming Bills (7 days)
                - Pending Transactions
                - Buffer Reserve
```

**Status Thresholds:**
- SAFE: > $500 safe to spend
- CAUTION: $100 - $500 safe to spend
- FREEZE: < $100 safe to spend

### 8.4 Subscription Detection

**Detection Sources:**
1. **Bank transactions** - recurring patterns
2. **Email receipts** - subscription confirmations

**Detection Algorithm:**

```python
def detect_subscriptions(transactions):
    """
    Identify recurring charges as subscriptions.
    """
    # Group by merchant
    by_merchant = group_transactions_by_merchant(transactions)

    subscriptions = []
    for merchant, txns in by_merchant.items():
        if len(txns) < 2:
            continue

        # Analyze frequency
        intervals = calculate_intervals(txns)
        avg_interval = mean(intervals)
        interval_variance = variance(intervals)

        # Check for regular pattern
        if interval_variance < 3:  # Low variance = regular pattern
            frequency = determine_frequency(avg_interval)
            # weekly (7), biweekly (14), monthly (30), yearly (365)

            if frequency:
                subscriptions.append({
                    'merchant': merchant,
                    'amount': txns[-1].amount,
                    'frequency': frequency,
                    'next_charge': predict_next_charge(txns, frequency),
                    'confidence': calculate_confidence(interval_variance, len(txns))
                })

    return subscriptions
```

### 8.5 Waste Detection

**Waste Indicators:**
- No recent transactions (30+ days for monthly subs)
- Low usage relative to cost
- Duplicate services
- Free alternatives available
- Price increased without usage increase

**Waste Score:** 0.0 (no waste) to 1.0 (definite waste)

### 8.6 Email Receipt Parser

**Parsed Fields:**
- Merchant name
- Amount
- Date
- Receipt type (purchase, subscription, renewal, refund)
- Subscription details (if applicable)

**Privacy:**
- Full email content is NEVER stored
- Only parsed metadata is retained
- Subject lines are hashed for privacy

---

## 9. Security Architecture

### 9.1 Security Overview

| Category | Requirement | Implementation |
|----------|-------------|----------------|
| **Data at Rest** | Encrypt sensitive data | AES-256-GCM for tokens, PII |
| **Data in Transit** | All traffic encrypted | TLS 1.3, HSTS headers |
| **Authentication** | Secure user auth | Firebase Auth + JWT |
| **Authorization** | Role-based access | Scoped JWT claims |
| **Token Security** | Protect API tokens | Encrypted database storage |
| **Rate Limiting** | Prevent abuse | Per-endpoint limits |
| **Audit Logging** | Track sensitive ops | Immutable audit trail |
| **GDPR Compliance** | Data portability/deletion | Export & delete endpoints |

### 9.2 Encryption Implementation

```python
# AES-256-GCM encryption for sensitive data

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os
import base64

class EncryptionService:
    def __init__(self, master_key: bytes):
        self.aesgcm = AESGCM(master_key)

    def encrypt(self, plaintext: str) -> str:
        """Encrypt and return base64-encoded ciphertext."""
        nonce = os.urandom(12)  # 96-bit nonce
        ciphertext = self.aesgcm.encrypt(
            nonce,
            plaintext.encode(),
            None
        )
        return base64.b64encode(nonce + ciphertext).decode()

    def decrypt(self, encrypted: str) -> str:
        """Decrypt base64-encoded ciphertext."""
        data = base64.b64decode(encrypted)
        nonce, ciphertext = data[:12], data[12:]
        plaintext = self.aesgcm.decrypt(nonce, ciphertext, None)
        return plaintext.decode()
```

### 9.3 Rate Limiting

| Endpoint | Limit | Rationale |
|----------|-------|-----------|
| `/auth/login` | 5/min | Prevent brute force |
| `/auth/register` | 3/min | Prevent spam accounts |
| `/banking/link` | 10/min | Plaid rate limits |
| `/gmail/scan` | 3/min | Gmail API quotas |
| `/pulse` | 60/min | Dashboard refresh |
| `/billing/checkout` | 5/min | Prevent payment abuse |
| Default | 100/min | General protection |

### 9.4 Data Privacy

**What We Store:**
- Encrypted Plaid access tokens
- Encrypted Gmail OAuth tokens
- Transaction metadata (amounts, dates, merchants)
- Parsed receipt data (no full emails)
- User settings and preferences

**What We DON'T Store:**
- Bank account credentials (Plaid handles this)
- Full email content
- Credit card numbers
- Social security numbers

**Data Retention:**
- Transactions: Indefinite (user's financial history)
- Email receipts: 90 days (Free) or 3 years (Pro)
- Audit logs: 7 years (compliance)
- Deleted accounts: 30-day grace period, then permanent

### 9.5 GDPR Compliance

| Right | Implementation |
|-------|----------------|
| **Right to Access** | `GET /users/me/data-export` |
| **Right to Rectification** | `PATCH /users/me` |
| **Right to Erasure** | `DELETE /auth/account` |
| **Right to Portability** | JSON export of all user data |
| **Right to Object** | Unsubscribe from marketing |

---

## 10. Implementation Phases

### 10.1 Phase Overview

| Phase | Weeks | Focus | Deliverables |
|-------|-------|-------|--------------|
| **1: Foundation** | 1-3 | Setup, Auth, DB | Project scaffold, user auth |
| **2: Banking** | 4-6 | Plaid, Transactions | Bank linking, sync |
| **3: Core Features** | 7-9 | Pulse, Subscriptions, Alerts | Main app functionality |
| **4: AI & Gmail** | 10-11 | Predictions, Email | AI systems, Gmail scan |
| **5: Monetization** | 12-13 | Stripe, Polish | Pro tier, app store prep |

### 10.2 Detailed Phase Breakdown

#### Phase 1: Foundation (Weeks 1-3)

**Week 1: Project Setup**
- Initialize FastAPI project with directory structure
- Set up PostgreSQL database
- Configure Alembic for migrations
- Set up Redis for caching
- Initialize mobile project
- Configure Firebase project
- Set up GitHub repository and CI/CD

**Week 2: Authentication**
- Implement Firebase Auth integration (backend)
- Create auth endpoints (register, login, refresh, logout)
- Build mobile auth screens (login, register, forgot password)
- Implement secure token storage (mobile)
- Add session management

**Week 3: Database & Core**
- Create all database migrations
- Implement user service
- Set up encryption service
- Implement audit logging
- Create base repository patterns
- Build settings endpoints

#### Phase 2: Banking Integration (Weeks 4-6)

**Week 4: Plaid Setup**
- Set up Plaid developer account
- Implement Plaid Link token generation
- Build public token exchange endpoint
- Store encrypted access tokens
- Implement account retrieval

**Week 5: Transaction Sync**
- Implement transaction sync service
- Set up Celery workers
- Build transaction categorization
- Implement Plaid webhook handlers
- Add balance refresh endpoints

**Week 6: Mobile Banking UI**
- Integrate Plaid Link SDK in mobile
- Build accounts list screen
- Create transactions list with search
- Implement pull-to-refresh sync
- Add account detail views

#### Phase 3: Core Features (Weeks 7-9)

**Week 7: Daily Money Pulse**
- Implement Safe-to-Spend calculator
- Build Daily Pulse endpoint
- Create pulse caching strategy
- Design and build Pulse home screen
- Add status animations (SAFE/CAUTION/FREEZE)

**Week 8: Subscription Detection**
- Build subscription detection algorithm
- Implement subscription service
- Create waste detection logic
- Build subscriptions hub UI
- Add subscription detail screens

**Week 9: Alerts System**
- Implement alert generation service
- Build FCM push notification integration
- Create alert endpoints
- Build alerts center UI
- Implement alert actions (dismiss, snooze)

#### Phase 4: AI & Predictions (Weeks 10-11)

**Week 10: Overdraft Predictor**
- Build prediction engine
- Implement factor analysis
- Create scheduled prediction jobs
- Build predictions API
- Create prediction UI widgets

**Week 11: Gmail Integration**
- Set up Google Cloud project
- Implement Gmail OAuth flow
- Build email parsing service
- Create receipt matching logic
- Add Gmail connection UI

#### Phase 5: Monetization & Polish (Weeks 12-13)

**Week 12: Pro Subscription**
- Set up Stripe account
- Implement Stripe checkout
- Build subscription management
- Create paywall UI
- Implement feature gating

**Week 13: Polish & Launch**
- Performance optimization
- Comprehensive testing
- App store assets preparation
- Security audit
- Documentation finalization
- Beta testing

---

## 11. Progress Tracker

### 11.1 Overall Progress

| Phase | Status | Progress | Start Date | Target Date |
|-------|--------|----------|------------|-------------|
| Phase 1: Foundation | In Progress | 6% | Jan 26, 2026 | - |
| Phase 2: Banking | Not Started | 0% | - | - |
| Phase 3: Core Features | Not Started | 0% | - | - |
| Phase 4: AI & Gmail | Not Started | 0% | - | - |
| Phase 5: Monetization | Not Started | 0% | - | - |

**Overall Project Progress: 1% (2/144 tasks)**

> **Note:** Mobile foundation (UI shell + Clean Architecture structure + core layer) established via Option A approach. See CLAUDE.md for architecture safeguards.

---

### 11.2 Phase 1: Foundation (Weeks 1-3)

#### Week 1: Project Setup

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Initialize FastAPI project | [ ] Not Started | - | **NEXT: Backend first** |
| Set up PostgreSQL database | [ ] Not Started | - | With multi-tenant schema |
| Configure Alembic migrations | [ ] Not Started | - | - |
| Set up Redis | [ ] Not Started | - | - |
| Initialize mobile project | [x] Complete | - | Built on wallet_app template |
| Configure Firebase project | [ ] Not Started | - | Auth only (not Firestore) |
| Set up GitHub repo + CI/CD | [x] Complete | - | github.com/Supreme070/Money-Guardian |
| Create .env.example | [ ] Not Started | - | - |
| Docker compose setup | [ ] Not Started | - | - |

**Week 1 Progress: 2/9 tasks (22%)**

> **Additional work completed (mobile UI - jumped to Week 6-7):**
> - Clean Architecture folder structure + core layer
> - All 4 main UI pages (Home, Subscriptions, Calendar, Alerts)
> - Custom widgets (PulseStatusCard, SubscriptionCard, UpcomingItem, BottomNav)
> - **UI is complete with mock data — now needs backend to provide real data**

#### Week 2: Authentication

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Firebase Auth backend integration | [ ] Not Started | - | - |
| POST /auth/register endpoint | [ ] Not Started | - | - |
| POST /auth/login endpoint | [ ] Not Started | - | - |
| POST /auth/refresh endpoint | [ ] Not Started | - | - |
| DELETE /auth/logout endpoint | [ ] Not Started | - | - |
| DELETE /auth/account endpoint | [ ] Not Started | - | - |
| Mobile login screen | [ ] Not Started | - | - |
| Mobile register screen | [ ] Not Started | - | - |
| Secure token storage (mobile) | [ ] Not Started | - | - |
| Session management | [ ] Not Started | - | - |

**Week 2 Progress: 0/10 tasks (0%)**

#### Week 3: Database & Core

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| users table migration | [ ] Not Started | - | - |
| bank_connections table migration | [ ] Not Started | - | - |
| bank_accounts table migration | [ ] Not Started | - | - |
| transactions table migration | [ ] Not Started | - | - |
| subscriptions table migration | [ ] Not Started | - | - |
| alerts table migration | [ ] Not Started | - | - |
| predictions table migration | [ ] Not Started | - | - |
| gmail_connections table migration | [ ] Not Started | - | - |
| email_receipts table migration | [ ] Not Started | - | - |
| daily_pulse_cache table migration | [ ] Not Started | - | - |
| audit_logs table migration | [ ] Not Started | - | - |
| User service implementation | [ ] Not Started | - | - |
| Encryption service | [ ] Not Started | - | - |
| Audit logging service | [ ] Not Started | - | - |
| User settings endpoints | [ ] Not Started | - | - |

**Week 3 Progress: 0/15 tasks (0%)**

**Phase 1 Total: 2/34 tasks (6%)**

---

### 11.3 Phase 2: Banking Integration (Weeks 4-6)

#### Week 4: Plaid Setup

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Plaid developer account setup | [ ] Not Started | - | - |
| POST /banking/link-token endpoint | [ ] Not Started | - | - |
| POST /banking/exchange endpoint | [ ] Not Started | - | - |
| Plaid service implementation | [ ] Not Started | - | - |
| Encrypted token storage | [ ] Not Started | - | - |
| GET /banking/connections endpoint | [ ] Not Started | - | - |
| DELETE /banking/connections/:id | [ ] Not Started | - | - |
| Account retrieval service | [ ] Not Started | - | - |

**Week 4 Progress: 0/8 tasks (0%)**

#### Week 5: Transaction Sync

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Transaction sync service | [ ] Not Started | - | - |
| Celery worker setup | [ ] Not Started | - | - |
| Sync transactions task | [ ] Not Started | - | - |
| Transaction categorization | [ ] Not Started | - | - |
| Plaid webhook handler | [ ] Not Started | - | - |
| POST /banking/connections/:id/sync | [ ] Not Started | - | - |
| GET /accounts endpoint | [ ] Not Started | - | - |
| GET /accounts/:id/balance endpoint | [ ] Not Started | - | - |

**Week 5 Progress: 0/8 tasks (0%)**

#### Week 6: Mobile Banking UI

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Plaid Link SDK integration | [ ] Not Started | - | - |
| Link bank flow (Mobile) | [ ] Not Started | - | - |
| Accounts list screen | [ ] Not Started | - | - |
| Account detail screen | [ ] Not Started | - | - |
| Transactions list screen | [ ] Not Started | - | - |
| Transaction search | [ ] Not Started | - | - |
| Pull-to-refresh sync | [ ] Not Started | - | - |
| Account BLoC | [ ] Not Started | - | - |
| Transactions BLoC | [ ] Not Started | - | - |

**Week 6 Progress: 0/9 tasks (0%)**

**Phase 2 Total: 0/25 tasks (0%)**

---

### 11.4 Phase 3: Core Features (Weeks 7-9)

#### Week 7: Daily Money Pulse

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Safe-to-Spend calculator | [ ] Not Started | - | - |
| GET /pulse endpoint | [ ] Not Started | - | - |
| GET /pulse/history endpoint | [ ] Not Started | - | - |
| GET /pulse/breakdown endpoint | [ ] Not Started | - | - |
| Pulse caching (Redis) | [ ] Not Started | - | - |
| Home screen (Mobile) | [ ] Not Started | - | - |
| Pulse status card widget | [ ] Not Started | - | - |
| Safe-to-spend widget | [ ] Not Started | - | - |
| Upcoming bills widget | [ ] Not Started | - | - |
| Status animations (SAFE/CAUTION/FREEZE) | [ ] Not Started | - | - |
| Pulse BLoC | [ ] Not Started | - | - |

**Week 7 Progress: 0/11 tasks (0%)**

#### Week 8: Subscription Detection

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Subscription detection algorithm | [ ] Not Started | - | - |
| Subscription service | [ ] Not Started | - | - |
| Waste detection logic | [ ] Not Started | - | - |
| GET /subscriptions endpoint | [ ] Not Started | - | - |
| GET /subscriptions/:id endpoint | [ ] Not Started | - | - |
| PATCH /subscriptions/:id endpoint | [ ] Not Started | - | - |
| POST /subscriptions/:id/snooze | [ ] Not Started | - | - |
| GET /subscriptions/waste endpoint | [ ] Not Started | - | - |
| Subscriptions hub screen | [ ] Not Started | - | - |
| Subscription detail screen | [ ] Not Started | - | - |
| Subscription card widget | [ ] Not Started | - | - |
| Waste alert widget | [ ] Not Started | - | - |
| Subscriptions BLoC | [ ] Not Started | - | - |

**Week 8 Progress: 0/13 tasks (0%)**

#### Week 9: Alerts System

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Alert generation service | [ ] Not Started | - | - |
| FCM integration (backend) | [ ] Not Started | - | - |
| Notification service | [ ] Not Started | - | - |
| GET /alerts endpoint | [ ] Not Started | - | - |
| GET /alerts/unread-count endpoint | [ ] Not Started | - | - |
| PATCH /alerts/:id/read endpoint | [ ] Not Started | - | - |
| PATCH /alerts/:id/dismiss endpoint | [ ] Not Started | - | - |
| POST /alerts/:id/snooze endpoint | [ ] Not Started | - | - |
| Alert processing Celery task | [ ] Not Started | - | - |
| Alerts center screen | [ ] Not Started | - | - |
| Alert card widget | [ ] Not Started | - | - |
| Push notification handling (Mobile) | [ ] Not Started | - | - |
| Alerts BLoC | [ ] Not Started | - | - |

**Week 9 Progress: 0/13 tasks (0%)**

**Phase 3 Total: 0/37 tasks (0%)**

---

### 11.5 Phase 4: AI & Predictions (Weeks 10-11)

#### Week 10: Overdraft Predictor

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Overdraft prediction engine | [ ] Not Started | - | - |
| Income pattern detection | [ ] Not Started | - | - |
| Spending pattern analysis | [ ] Not Started | - | - |
| Factor identification logic | [ ] Not Started | - | - |
| Recommendation generator | [ ] Not Started | - | - |
| GET /predictions endpoint | [ ] Not Started | - | - |
| GET /predictions/upcoming endpoint | [ ] Not Started | - | - |
| Daily prediction Celery job | [ ] Not Started | - | - |
| Prediction feedback loop | [ ] Not Started | - | - |
| Predictions UI widget | [ ] Not Started | - | - |

**Week 10 Progress: 0/10 tasks (0%)**

#### Week 11: Gmail Integration

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Google Cloud project setup | [ ] Not Started | - | - |
| Gmail OAuth service | [ ] Not Started | - | - |
| GET /gmail/auth-url endpoint | [ ] Not Started | - | - |
| POST /gmail/callback endpoint | [ ] Not Started | - | - |
| GET /gmail/status endpoint | [ ] Not Started | - | - |
| POST /gmail/scan endpoint | [ ] Not Started | - | - |
| DELETE /gmail/disconnect endpoint | [ ] Not Started | - | - |
| Email receipt parser | [ ] Not Started | - | - |
| Receipt-subscription matcher | [ ] Not Started | - | - |
| Gmail scan Celery task | [ ] Not Started | - | - |
| Gmail connection screen (Mobile) | [ ] Not Started | - | - |

**Week 11 Progress: 0/11 tasks (0%)**

**Phase 4 Total: 0/21 tasks (0%)**

---

### 11.6 Phase 5: Monetization & Polish (Weeks 12-13)

#### Week 12: Pro Subscription

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Stripe account setup | [ ] Not Started | - | - |
| Stripe service implementation | [ ] Not Started | - | - |
| GET /billing/plans endpoint | [ ] Not Started | - | - |
| POST /billing/checkout endpoint | [ ] Not Started | - | - |
| GET /billing/subscription endpoint | [ ] Not Started | - | - |
| POST /billing/portal endpoint | [ ] Not Started | - | - |
| POST /billing/cancel endpoint | [ ] Not Started | - | - |
| Stripe webhook handler | [ ] Not Started | - | - |
| Feature gating middleware | [ ] Not Started | - | - |
| Paywall screen (Mobile) | [ ] Not Started | - | - |
| Pro features screen | [ ] Not Started | - | - |
| Billing BLoC | [ ] Not Started | - | - |

**Week 12 Progress: 0/12 tasks (0%)**

#### Week 13: Polish & Launch

| Task | Status | Assignee | Notes |
|------|--------|----------|-------|
| Performance optimization | [ ] Not Started | - | - |
| API load testing | [ ] Not Started | - | - |
| Mobile performance testing | [ ] Not Started | - | - |
| Unit tests (backend) | [ ] Not Started | - | - |
| Unit tests (mobile) | [ ] Not Started | - | - |
| Integration tests | [ ] Not Started | - | - |
| Security audit | [ ] Not Started | - | - |
| App Store assets (iOS) | [ ] Not Started | - | - |
| Play Store assets (Android) | [ ] Not Started | - | - |
| Privacy policy | [ ] Not Started | - | - |
| Terms of service | [ ] Not Started | - | - |
| API documentation | [ ] Not Started | - | - |
| User documentation | [ ] Not Started | - | - |
| Beta testing | [ ] Not Started | - | - |
| Bug fixes from beta | [ ] Not Started | - | - |

**Week 13 Progress: 0/15 tasks (0%)**

**Phase 5 Total: 0/27 tasks (0%)**

---

### 11.7 Summary Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│                    MONEY GUARDIAN - BUILD TRACKER                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Overall Progress:  [█░░░░░░░░░░░░░░░░░░░]  1% (2/144 tasks)    │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Phase 1: Foundation    [█░░░░░░░░░]  6%  (2/34 tasks)          │
│  Phase 2: Banking       [░░░░░░░░░░]  0%  (0/25 tasks)          │
│  Phase 3: Core          [░░░░░░░░░░]  0%  (0/37 tasks)          │
│  Phase 4: AI & Gmail    [░░░░░░░░░░]  0%  (0/21 tasks)          │
│  Phase 5: Monetization  [░░░░░░░░░░]  0%  (0/27 tasks)          │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Current Phase: Phase 1 - Foundation                             │
│  Current Week:  Week 1 - Project Setup                           │
│  Blockers:      None                                             │
│  Next Milestone: Phase 1 Complete                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12. Risk Management

### 12.1 Risk Register

| Risk | Probability | Impact | Mitigation | Status |
|------|-------------|--------|------------|--------|
| Plaid API changes | Medium | High | Abstract behind service layer | Monitoring |
| Gmail API quota limits | Low | Medium | Implement backoff, daily limits | Planned |
| User data breach | Low | Critical | Encryption, audits, pen testing | Planned |
| Prediction accuracy issues | Medium | Medium | Feedback loop, confidence scores | Planned |
| App store rejection | Low | Medium | Follow guidelines, privacy policy | Planned |
| Scale issues at launch | Medium | High | Load testing, auto-scaling | Planned |
| Bank connection failures | Medium | Medium | Retry logic, user notifications | Planned |
| Low conversion rate | Medium | High | A/B test paywall, prove ROI | Planned |
| High churn rate | Medium | High | Monthly value reminders | Planned |
| Competitor copies feature | Medium | Low | Execute faster, build trust | Monitoring |

### 12.2 Contingency Plans

**If Plaid costs become prohibitive:**
- Consider Teller as backup provider
- Implement connection limits for free tier
- Negotiate volume discounts

**If Gmail API access restricted:**
- Fallback to manual subscription entry
- Partner with email providers
- Focus on bank-only detection

**If prediction accuracy < 70%:**
- Add more data signals
- Implement ML models (Phase 2)
- Allow user corrections for feedback

---

## 13. Success Metrics

### 13.1 MVP Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| User can link bank | 100% success | Plaid completion rate |
| Daily Pulse accuracy | > 90% | Balance vs prediction |
| Subscription detection | > 80% accuracy | User verification |
| Alert timeliness | > 24 hours before | Time to event |
| App load time | < 2 seconds | Performance monitoring |
| API response time (p95) | < 500ms | Backend metrics |

### 13.2 Post-Launch KPIs

| KPI | Target | Timeframe |
|-----|--------|-----------|
| D1 Retention | > 60% | Day 1 |
| D7 Retention | > 40% | Day 7 |
| D30 Retention | > 20% | Day 30 |
| Bank connections/user | > 1.5 | Average |
| Overdraft warning accuracy | > 75% | Verified predictions |
| Pro conversion rate | > 3% | Free to paid |
| Monthly churn rate | < 5% | Pro subscribers |
| NPS Score | > 40 | User surveys |
| App Store rating | > 4.5 | Store reviews |

### 13.3 Financial Targets (Year 1)

| Milestone | Users | MRR | Target Date |
|-----------|-------|-----|-------------|
| Launch | 100 | $0 | Month 1 |
| First revenue | 500 | $500 | Month 2 |
| Product-market fit | 2,000 | $4,000 | Month 6 |
| Sustainable | 5,000 | $15,000 | Month 9 |
| Scale ready | 10,000 | $40,000 | Month 12 |

---

## 14. Cost Estimates

### 14.1 Development Costs

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| Backend Developer | $8,000-15,000 | Full-time or contractor |
| Mobile Developer | $8,000-15,000 | Full-time or contractor |
| Designer (Part-time) | $2,000-4,000 | UI/UX design |
| **Total (Dev Phase)** | **$18,000-34,000/mo** | 3-4 months |

### 14.2 Infrastructure Costs (MVP)

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| AWS (RDS, ElastiCache, Lambda) | $200-500 | Scales with users |
| Plaid | $0-500 | Free tier, then per connection |
| Firebase | $0-100 | Free tier generous |
| Stripe | 2.9% + $0.30/txn | Per transaction |
| Domain + SSL | $20 | Annual |
| **Total (MVP)** | **$200-1,100/mo** | < 1,000 users |

### 14.3 Infrastructure Costs (Scale)

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| AWS | $1,000-3,000 | 10,000+ users |
| Plaid | $2,000-5,000 | Per connection fees |
| Firebase | $200-500 | Push notifications |
| Monitoring | $100-300 | Datadog, Sentry |
| **Total (Scale)** | **$3,300-8,800/mo** | 10,000+ users |

### 14.4 Break-Even Analysis

```
Fixed Costs (10,000 users): ~$5,000/month
Variable Cost per User: ~$0.50/month (Plaid)

Revenue per Pro User: $9.99/month
Gross Margin per Pro User: $9.49/month

Break-even Pro Users: 5,000 / 9.49 = ~527 users
At 10% conversion: Need 5,270 total users to break even
At 20% conversion: Need 2,635 total users to break even
```

---

## 15. Appendix

### 15.1 Glossary

| Term | Definition |
|------|------------|
| **Plaid** | Third-party service that connects to bank accounts |
| **Safe-to-Spend** | Amount user can spend without risking overdraft |
| **Daily Pulse** | Home screen showing financial health status |
| **Waste Score** | 0-1 measure of subscription being unused |
| **Overdraft** | Spending more than available balance |
| **Pro Tier** | Paid subscription with advanced features |

### 15.2 External Resources

- [Plaid Documentation](https://plaid.com/docs/)
- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [Stripe Documentation](https://stripe.com/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Documentation](https://docs.flutter.dev/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

### 15.3 Reference Competitors

| App | What They Do | Pricing |
|-----|--------------|---------|
| Rocket Money | Subscription tracking, bill negotiation | Free / $7-14/mo |
| Monarch Money | Full PFM, collaborative | $14.99/mo |
| PocketGuard | Budget tracking, safe-to-spend | Free / $12.99/mo |
| Chime | Banking with overdraft protection | Free (banking) |
| Dave | Cash advances | Free / $5/mo |

### 15.4 Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 26, 2026 | - | Initial document |

---

## Quick Reference

### Key Files to Create First

1. `/backend/app/main.py` - FastAPI entry point
2. `/backend/app/config/settings.py` - Environment config
3. `/backend/app/models/user.py` - User model
4. `/backend/app/services/plaid_service.py` - Plaid integration
5. `/backend/app/ai/safe_to_spend.py` - Core algorithm
6. `/mobile/lib/main.dart` - Mobile entry point
7. `/mobile/lib/presentation/pages/home/home_page.dart` - Pulse screen

### Commands to Start

```bash
# Backend setup
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload

# Mobile setup
cd mobile
# Install dependencies and run from mobile directory

# Database
docker-compose up -d postgres redis
alembic upgrade head
```

---

**Document Status:** Complete and ready for implementation

**Next Action:** Begin Phase 1, Week 1 - Project Setup
