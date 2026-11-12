# DueMate

<p align="center">
  <img src="assets/images/app_logo.png" alt="DueMate Logo" width="120" height="120" />
</p>

<p align="center">
  <b>Personal Lending & Credit Card EMI Ledger Vault</b><br>
  A modern, private, and fluid offline-first ledger for tracking personal debts, loans, and monthly credit card EMIs.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-003B57?logo=sqlite" alt="SQLite Drift" />
  <img src="https://img.shields.io/badge/State-Flutter%20Riverpod-388E3C" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/Storage-100%25%20Offline-orange" alt="Offline First" />
</p>

---

## 🌟 Key Features

- **🔒 100% Offline & Private Vault**: Zero accounts, zero ads, and no external cloud servers. All transactions, loans, and contacts remain strictly on your local SQLite storage.
- **💸 Intuitive Lending & Repayments**:
  - Record **Money Given** (_You're owed_) and **Payment Received** with one tap.
  - Tag payment methods: Cash, UPI, Bank Transfer, Cheque, or Other.
  - Add optional reference notes, dates, and custom notes.
- **💳 Credit Card EMI & Monthly Loan Schedules**:
  - Multi-month installment tracking with automated background posting.
  - Flexible tenure selector (custom number entry or quick preset chips).
  - Live breakdown card displaying principal, extra charges, and monthly installments.
- **👥 Contact-Linked People Directory**:
  - Filter ledger instantly: _All_, _Owes You_, _Settled_, or _Archived_.
  - Duplicate contact protection with phone number normalization (`_normalizePhone` matching exact 10 digits).
  - One-tap phone contacts import (`ContactsHelper.pickContact()`).
  - Live real-time avatar preview (`AvatarWidget`) and relationship quick tags (_Friend_, _Colleague_, _Family_, _Roommate_, _Business_).
- **📊 Reports & Financial Analytics**:
  - Overview cards breaking down total given, total received, and net differences.
  - Date range filters: _All Time_, _This Month_, _Last Month_, _This Year_, and _Custom Range_.
  - Activity timeline feed & per-person debt breakdown.
- **📤 Easy Sharing & Smart Reminders**:
  - One-tap formatted WhatsApp payment reminders with custom templates and native SVG vector icon (`WhatsAppIcon`).
  - Automated local push notifications for upcoming EMI due dates with Settings toggle and test alert trigger (`flutter_local_notifications`).
  - Export complete statements as structured CSV or PDF files.
- **🎨 Modern Material 3 UI & Motion Design**:
  - Time-aware greeting header (*Good Morning / Afternoon / Evening*).
  - High-contrast Net Ledger Position hero card with settlement recovery progress bar.
  - Expanding pill capsule floating dock navbar (`_FloatingDockNavBar`).
  - **Animated Currency Rollups** (`AnimatedCurrencyText`), **Staggered Entrance Motion** (`FadeSlideTransition`), and **Tactile Spring Feedback** (`PressableScale`).
  - Full system Dark & Light mode support.
  - Multi-currency support (₹ INR, $ USD, € EUR, £ GBP, AED, S$, A$, C$).

---

## 🏗️ Architecture & Component Structure

DueMate is structured using Clean Architecture separating domain logic, data persistence, and presentation:

```
lib/
├── core/
│   ├── constants/       # App metadata, currency options, default tokens
│   ├── navigation/      # GoRouter configuration & root navigator routes
│   ├── services/        # NotificationService (local push notifications)
│   ├── theme/           # Material 3 light/dark themes & typography
│   ├── utils/           # WhatsAppHelper, ContactsHelper, BackupHelper, Exporters
│   └── widgets/         # Shared UI (AnimatedCurrencyText, FadeSlideTransition, PressableScale, etc.)
├── data/
│   ├── database/        # Drift SQLite schema, migrations & WAL tuning
│   ├── providers/       # Riverpod providers & SharedPreferences
│   └── repositories/   # SQLite concrete repository implementations
├── domain/
│   ├── entities/        # Pure immutable business models (Person, Transaction, CreditCardEmi)
│   └── repositories/   # Abstract repository contracts
└── features/
    ├── dashboard/       # Time greeting, Net Ledger card, quick actions, dues carousel
    ├── emis/            # EMI creation, tenure selector, breakdown card, details sheet
    ├── people/          # Directory, PersonDirectoryTile, AddEditPersonScreen, details
    ├── reports/         # ReportsScreen, cashflow overview, date filters, activity feed
    ├── settings/        # Theme picker, currency selector, notifications, data export
    └── transactions/    # TransactionDetailsDialog modal flow
```

### Performance Enhancements

- **SQLite WAL Mode**: Configured `PRAGMA journal_mode = WAL` and `PRAGMA synchronous = NORMAL` for non-blocking concurrent reads and fast commits.
- **Composite Indexing**: Added database indexes (`idx_transactions_person_id`, `idx_transactions_date`) to ensure fast aggregations over large transaction histories.
- **Zero-Allocation Formatting**: Static singleton caching for `NumberFormat` and `DateFormat` instances, eliminating runtime garbage-collection overhead during rapid list scrolling.
- **Root Navigator Modals**: Modal sheets and create/edit forms open on the root navigator, cleanly hiding the floating dock navbar across sub-routes.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.13.0 or higher)
- Android Studio / VS Code with Flutter extension
- An Android device or emulator (Android 7.0+ / API 24+)

### Installation & Run

1. **Clone the repository:**

   ```bash
   git clone https://github.com/manu2501/DueMate.git
   cd DueMate
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Generate Drift database code:**

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run on a connected device:**

   ```bash
   flutter run
   ```

---

## 🧪 Testing & Verification

Run static analysis and test suite:

```bash
# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test
```

---

## 📦 Building a Release APK

To generate an optimized release APK:

```bash
flutter build apk --release
```

The compiled binary will be placed at:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
