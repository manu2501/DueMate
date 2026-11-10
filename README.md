# DueMate (Smarava)

<p align="center">
  <img src="assets/images/app_logo.png" alt="DueMate Logo" width="120" height="120" />
</p>

<p align="center">
  <b>Personal Lending & Repayment Tracker</b><br>
  A modern, private, and fluid offline-first ledger for tracking personal debts, loans, and shared expenses.
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

- **🔒 100% Offline & Private**: Zero accounts, zero ads, and no external cloud servers. All transactions and contacts remain strictly on your device.
- **💸 Intuitive Lending & Repayment**:
  - Record **Money Given** (*You're owed*) and **Payment Received** with one tap.
  - Tag payment methods: Cash, UPI, Bank Transfer, Cheque, or Other.
  - Add optional reference notes and dates.
- **👥 Contact-Linked People Directory**:
  - Filter ledger instantly: *Active*, *Settled*, *Archived*, or *All Directory*.
  - Import borrower names and phone numbers directly from your device contacts.
  - Visual color-coded repayment progress bars.
- **📊 Reports & Financial Analytics**:
  - Overview tabs breaking down total given, total received, and net differences.
  - Time filters: *All Time*, *This Month*, *Last Month*, and *This Year*.
  - Per-person debt breakdown.
- **📤 Easy Sharing & Reminders**:
  - One-tap formatted WhatsApp / SMS friendly reminder messages.
  - Export complete statements as structured CSV files.
- **🎨 Modern Human-Centric UI**:
  - Warm Material 3 palette (Indigo `#4F46E5`, Amber `#F59E0B`, Emerald, and Rose).
  - Clean typography featuring Google Fonts (DM Sans and Inter).
  - Smooth scale/fade page transitions, Hero avatar animations, and animated counter switchers.
  - Full system Dark & Light mode support.
  - Multi-currency support (₹ INR, $ USD, € EUR, £ GBP, AED, S$, A$, C$).

---

## 🏗️ Architecture & Optimizations

DueMate is structured using a clean, layered architecture separating domain logic, data persistence, and presentation:

```
lib/
├── core/
│   ├── constants/       # App metadata, currency options, default tokens
│   ├── navigation/      # GoRouter configuration with custom animations
│   ├── theme/           # Material 3 light/dark themes & typography
│   ├── utils/           # Cached currency & date formatters, permissions
│   └── widgets/         # Shared UI (AvatarWidget, TransactionTile, etc.)
├── data/
│   ├── database/        # Drift SQLite schema, migrations & WAL tuning
│   ├── providers/       # Riverpod providers & SharedPreferences
│   └── repositories/   # SQLite concrete repository implementations
├── domain/
│   ├── entities/        # Pure immutable business models (Person, Transaction)
│   └── repositories/   # Abstract repository contracts
└── features/
    ├── dashboard/       # Balance summary, top debtors, quick actions
    ├── people/          # Directory, person details, repayment progress
    ├── reports/         # Overview cards, activity logs, date filtering
    ├── settings/        # Preferences, theme selector, currency picker
    ├── transactions/    # Transaction details modal & edit flow
    └── welcome/         # Onboarding & permission introduction
```

### Performance Enhancements
- **SQLite WAL Mode**: Configured `PRAGMA journal_mode = WAL` and `PRAGMA synchronous = NORMAL` for non-blocking concurrent reads and fast commits.
- **Composite Indexing**: Added database indexes (`idx_transactions_person_id`, `idx_transactions_date`) to ensure fast aggregations over large transaction histories.
- **Zero-Allocation Formatting**: Static singleton caching for `NumberFormat` and `DateFormat` instances, eliminating runtime garbage-collection overhead during rapid list scrolling.
- **Preferences Caching**: Instant startup with persistent local preferences using `shared_preferences`.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.13.0 or higher)
- Android Studio / VS Code with Flutter extension
- An Android device or emulator (Android 7.0+ / API 24+)

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/smarava.git
   cd smarava
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

Run the test suite to verify unit calculations and UI widgets:

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
