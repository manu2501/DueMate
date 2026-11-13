# DueMate

<p align="center">
  <img src="assets/images/app_logo.png" alt="DueMate logo" width="112" height="112" />
</p>

<p align="center">
  <b>Keep track of who owes what.</b><br>
  An offline Android app for money you lend and borrow, EMIs you share, and what you spend.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-003B57?logo=sqlite" alt="Drift (SQLite)" />
  <img src="https://img.shields.io/badge/State-Riverpod%203-388E3C" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT license" />
</p>

---

<p align="center">
  <img src="docs/screenshots/01_home.png" width="200" alt="Home" />
  <img src="docs/screenshots/03_person.png" width="200" alt="A person's ledger" />
  <img src="docs/screenshots/04_expenses.png" width="200" alt="Expenses" />
  <img src="docs/screenshots/13_emi_details_dark.png" width="200" alt="EMI schedule, dark theme" />
</p>

<p align="center">
  <sub>Home · a person's ledger · expenses · an EMI schedule (dark). Every screen, in light and dark, is in <a href="docs/SCREENS.md"><b>docs/SCREENS.md</b></a>.</sub>
</p>

---

## What it does

Everything stays on the phone. There is no account, no server and no analytics.

**People and balances**
- Record money you **give** and money you **receive**, per person, with date, payment method (UPI, cash, card, bank transfer, wallet apps like Paytm or Amazon Pay, other) and a note.
- **UPI**: show a QR with your UPI ID and the amount when you're being paid (or share it as an image), and open your UPI app pre-filled to pay someone whose UPI ID you've saved (when you come back, one tap records it). Reminders include your UPI ID. Rupees only.
- Each person's ledger shows who owes whom, how much has been paid back (a progress bar, also on every row in People, e.g. "Paid ₹2,500 of ₹15,000 · 16%"), their EMIs, and history grouped by month.
- Add people by hand or from phone contacts. Duplicates are caught by phone number (last 10 digits), so two different people with the same name can both be added.
- Remind someone on WhatsApp, or share their statement as PDF or CSV.
- Archive people you're done with; delete asks first and says exactly what goes.

**EMIs and loans**
- Track card EMIs and loans for yourself or shared with someone.
- Enter it either way:
  - **Split a total**: amount, months, optional interest (reducing balance or flat) and charges; the app works out the EMI.
  - **I know the EMI**: type the monthly EMI from your bank; add the original amount to see the extra you pay and the effective yearly rate.
- Charges and fees, with an 18% GST helper applied to fee + interest (never principal).
- Set a different amount for specific months (e.g. a first month with a fee).
- Installments are posted automatically on their due dates: your own EMIs and loans to expenses (in the month each was due, including ones already paid when you add it), shared ones to the person's ledger. "Pay" records one or more months early, dated the day you paid.

**Spending**
- Log expenses by category (groceries, bills, rent, fuel, food, shopping, entertainment, health, EMIs & loans, other) in a few taps; the amount comes first and a description is optional.
- A monthly budget with a clear "left / over" status on Home and Expenses.
- Spending trends: month-by-month bars for any year, where the money went by category, and every expense of a past month (editable).

**Everything else**
- **Home**: where you stand overall, Give / Receive / Expense buttons, the largest balances, this month's spending against budget, the next EMI due, and recent activity; sections without data stay hidden.
- **Activity**: one timeline of ledger entries and expenses, grouped by day, with search and filters for type, period and payment method; export as PDF or CSV.
- **EMI reminders**: a notification the day before each installment is due, kept in step with your EMIs automatically; tap it to open that EMI. Amounts are left out while they're hidden or App Lock is on.
- **Backup and restore**: back up everything to one file, and restore it later (DueMate shows what's in the file and asks before replacing your data).
- **Due dates on loans**: give money with a "return by" date; People shows *due back by …* or *overdue since …* (with an Overdue filter), and you get a reminder the day before.
- **Recurring expenses**: mark an expense as repeating every month (rent, subscriptions) and it's added automatically on that day; change the amount or stop it any time.
- **Lending trends**: money lent vs collected, month by month (chart icon on People).
- **Hide amounts**: the eye icon on Home (or the switch in Settings) replaces every balance and total with dots, e.g. when using the app in public. Amounts you're typing, exports and shared messages are never hidden. The choice is remembered, and showing amounts again asks for fingerprint, face or screen lock.
- **App Lock**: ask for fingerprint, face or the phone's screen lock to open DueMate, on launch and after you've been away for a chosen time. Balances are hidden from the recent-apps view while it's on.
- **Settings**: theme (system / light / dark), hide amounts, App Lock, currency (₹, $, €, £, AED, S$, A$, C$), monthly budget, notifications, backup and restore, CSV export, erase all data, and the version with **What's new** (from [CHANGELOG.md](CHANGELOG.md)).

## Design

The app follows a small set of rules (detailed in [`CLAUDE.md`](CLAUDE.md)):

- **Colour means money direction.** Green is money coming to you, red is money you owe. Spending and lending are neutral with a +/− sign. Colour is never the only signal.
- **Each screen leads with its one important number**, then the actions, then the detail. Related items share one surface instead of a card each.
- **Motion explains navigation and nothing else**: tabs fade through, deeper pages slide in from the side. It all switches off with the system "remove animations" setting.
- **Destructive actions live in detail views** and always confirm.
- **Logo**: a "D" with a small "due" dot, drawn from one vector source and shipped as an Android adaptive icon (with a themed-icon layer).

## Architecture

Clean architecture with Riverpod and Drift:

```
lib/
├── core/
│   ├── constants/     # App constants, currencies, expense categories
│   ├── navigation/    # GoRouter: tab shell + pushed pages
│   ├── services/      # NotificationService, EmiProcessorService
│   ├── theme/         # AppTheme (colours, type, components), AppMotion
│   ├── utils/         # Formatters, CSV/PDF export, backup, WhatsApp, contacts
│   └── widgets/       # Shared UI: ui_kit (TabScaffold, GroupCard, MoneyText, PersonRow…),
│                      #   LedgerEntrySheet, AmountField, ChoiceTileGroup, SuggestTextField,
│                      #   confirm dialogs, AppLogo
├── data/
│   ├── database/      # Drift schema (v7) and migrations
│   ├── providers/     # Riverpod providers, one file per area; app_providers.dart re-exports
│   └── repositories/  # Drift-backed repository implementations
├── domain/
│   ├── entities/      # Person, LedgerTransaction, CreditCardEmi, PersonalExpense, summaries
│   ├── repositories/  # Repository interfaces
│   ├── emi_calculator.dart   # EMI plans, interest, GST, implied rate (pure, unit-tested)
│   └── person_matcher.dart   # Duplicate-contact detection (pure, unit-tested)
└── features/          # dashboard, people, emis, expenses, reports (Activity), settings, transactions
```

- Balances are derived from ledger transactions; EMIs post their installments as transactions.
- SQLite runs in WAL mode with indexes on person, date and EMI lookups.

## Getting started

Requirements: Flutter SDK (Dart 3.13+), an Android device or emulator.

```bash
git clone https://github.com/manu2501/DueMate.git
cd DueMate
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code
flutter run
```

Release build:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

## Tests

```bash
flutter analyze
flutter test                        # unit, repository (in-memory SQLite) and widget tests
```

Tests time out after 30 seconds instead of hanging.

### Screenshots without a device

```bash
flutter test test_screens/screens_test.dart --update-goldens
```

Seeds a realistic ledger and renders every main screen, sheet and form in light and dark to `test_screens/out/` (not committed).

The screenshots in this README and [docs/SCREENS.md](docs/SCREENS.md) come from the same harness. After a UI change, refresh them:

```bash
flutter test test_screens/screens_test.dart --update-goldens --dart-define=DOCS=true   # writes docs/screenshots/
```

### Regenerating the launcher icons

The logo is defined once in `lib/core/widgets/app_logo.dart`. After changing it, update the matching paths in `android/app/src/main/res/drawable/ic_launcher_*.xml`, then regenerate the PNG icons and `assets/images/app_logo.png`:

```bash
flutter test test_screens/logo_export_test.dart --update-goldens
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) (also in the app under Settings › What's new). Current version: **1.1.0 (build 2)**.

## License

[MIT](LICENSE) © 2026 Manoj Kumar Kothuru
