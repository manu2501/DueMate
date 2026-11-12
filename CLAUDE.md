# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DueMate is an offline-first Flutter (Android-only target) app for tracking personal lending, credit card EMIs/loans, and personal expenses. All data lives in a local Drift/SQLite database; there is no backend. `TODO.md` holds the feature roadmap.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate app_database.g.dart after any change to tables.dart / app_database.dart
flutter analyze
flutter test                                    # all tests
flutter test test/unit/emi_test.dart            # single file
flutter test --plain-name "E2E Flow 1"          # single test by name
flutter run
flutter build apk --release
```

## Architecture

Clean-architecture layering under `lib/`:

- `domain/` — pure entities (`Person`, `LedgerTransaction`, `CreditCardEmi`, `PersonalExpense`, summaries) and abstract repository interfaces.
- `data/database/` — Drift schema (`tables.dart`) and `AppDatabase` (`app_database.dart`, with generated `app_database.g.dart`).
- `data/repositories/` — `*RepositoryImpl` classes that map Drift row classes ↔ domain entities (`_toDomain` / companion builders). Drift generates row classes with the same names as domain entities (`Person`, `CreditCardEmi`, `Transaction`), so imports use `hide` or `as db` aliases to disambiguate — follow the existing pattern.
- `data/providers/app_providers.dart` — the single Riverpod (v3, `Notifier`/`StreamProvider`) wiring file: database → repositories → stream providers → derived providers (dashboard totals, filtered/sorted people, etc.), plus SharedPreferences-backed settings notifiers (currency, theme, monthly budget). UI reads data almost exclusively via these providers; most screens react to Drift `watch*` streams rather than imperatively refreshing.
- `features/<feature>/presentation/{screens,widgets}` — UI per feature (dashboard, people, emis, expenses, reports, settings, transactions). Large screens are decomposed into feature-local widgets; shared widgets live in `core/widgets/`.
- `core/` — router, theme, constants, `NotificationService`, `EmiProcessorService`, and helpers (CSV/PDF export, backup, WhatsApp, contacts, formatters).

### Key cross-cutting behaviors

- **Schema migrations**: `AppDatabase.schemaVersion` is bumped for every schema change with a matching `if (from < N)` step in `onUpgrade`. `beforeOpen` enables foreign keys/WAL, creates indexes, and inserts the "self" person row.
- **Self person**: `AppConstants.selfPersonId` (`'self_person_me'`) is a real row in `persons` representing the user ("Myself (Personal)"). Self EMIs/expenses reference it to satisfy FKs; UI code filters it out of people lists/top dues. Tests using an in-memory DB must seed this row (see `test/e2e/e2e_ledger_flow_test.dart`).
- **EMIs post installments as ledger transactions**: `EmiProcessorService.processDueInstallments` (run via `emiAutoProcessorProvider`) walks each active EMI's schedule and inserts a `LedgerTransaction` per due installment, tagged with `emiId` + `installmentNumber`, then updates `installmentsPaid`/`status`. Balances therefore derive from transactions, not from EMI rows. Per-installment amounts come from `CreditCardEmi.getMonthlyInstallmentFor(k)`, which honors an optional `customScheduleJson` override map; due dates from `getDueDateForInstallment(k)`.
- **Navigation**: GoRouter (`core/navigation/app_router.dart`) uses a `ShellRoute` for the tabbed pages (`/`, `/people`, `/expenses`, `/reports`) with the floating dock navbar; detail/create/edit routes (`/people/:id`, `/add-person`, `/add-emi`, `/settings`, …) use `parentNavigatorKey: _rootNavigatorKey` so they cover the dock. Modal sheets are likewise opened on the root navigator.
- **Money** is stored as `REAL` (double); dates are stored by Drift as epoch seconds.

## Tests

- `test/unit/` — pure logic (balances, EMI math, expenses, formatters, permission manager).
- `test/e2e/` — repository-level flows against `AppDatabase(NativeDatabase.memory())`; `AppDatabase` accepts an optional `QueryExecutor` for this purpose.
