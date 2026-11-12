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

- `domain/` — pure entities (`Person`, `LedgerTransaction`, `CreditCardEmi`, `PersonalExpense`, summaries), abstract repository interfaces, and pure logic with unit tests: `EmiCalculator` (split-a-total vs known-EMI plans, interest, GST, implied rate) and `PersonMatcher` (duplicate-contact detection; phone numbers decide when both sides have one).
- `data/database/` — Drift schema (`tables.dart`) and `AppDatabase` (`app_database.dart`, with generated `app_database.g.dart`).
- `data/repositories/` — `*RepositoryImpl` classes that map Drift row classes ↔ domain entities (`_toDomain` / companion builders). Drift generates row classes with the same names as domain entities (`Person`, `CreditCardEmi`, `Transaction`), so imports use `hide` or `as db` aliases to disambiguate — follow the existing pattern.
- `data/providers/` — Riverpod (v3, `Notifier`/`StreamProvider`) wiring, one file per area: `database_providers` (database → repositories), `ledger_providers`, `people_providers` (filter/sort/search), `dashboard_providers` (derived totals), `emi_providers`, `expense_providers` (incl. monthly budget), `settings_providers` (currency, theme). `app_providers.dart` re-exports them all, so import that one file. UI reads data almost exclusively via these providers; most screens react to Drift `watch*` streams rather than imperatively refreshing.
- `features/<feature>/presentation/{screens,widgets}` — UI per feature (dashboard, people, emis, expenses, reports, settings, transactions). Large screens are decomposed into feature-local widgets; shared widgets live in `core/widgets/`. Reuse these before building new ones: `LedgerEntrySheet` (give/receive; `QuickGiveSheet`/`QuickReceiveSheet` are its entry points), `showConfirmDialog` / `showAlreadyInLedgerDialog`, `ChoiceTileGroup` (pick-one tiles with subtitles), `SuggestTextField` (text field with quick-pick chips and live matches), `PersonSelectField`, `AvatarWidget`, `EmptyStateWidget`. Style with theme tokens (`AppSpace`, `AppRadius`, `LedgerColors`, `colorScheme`) rather than literal colours.
- `core/` — router, theme, constants, `NotificationService`, `EmiProcessorService`, and helpers (CSV/PDF export, backup, WhatsApp, contacts, formatters).

### Key cross-cutting behaviors

- **Schema migrations**: `AppDatabase.schemaVersion` is bumped for every schema change with a matching `if (from < N)` step in `onUpgrade`. `beforeOpen` enables foreign keys/WAL, creates indexes, and inserts the "self" person row.
- **Self person**: `AppConstants.selfPersonId` (`'self_person_me'`) is a real row in `persons` representing the user ("Myself (Personal)"). Self EMIs/expenses reference it to satisfy FKs; UI code filters it out of people lists/top dues. Tests using an in-memory DB must seed this row (see `test/e2e/e2e_ledger_flow_test.dart`).
- **EMIs post installments as ledger transactions**: `EmiProcessorService.processDueInstallments` (run via `emiAutoProcessorProvider`) walks each active EMI's schedule and inserts a `LedgerTransaction` per due installment, tagged with `emiId` + `installmentNumber`, then updates `installmentsPaid`/`status`. Balances therefore derive from transactions, not from EMI rows. Per-installment amounts come from `CreditCardEmi.getMonthlyInstallmentFor(k)`, which honors an optional `customScheduleJson` override map; due dates from `getDueDateForInstallment(k)`. Since schema v7 an EMI also stores `kind` (`card`/`loan`), `planMode` (`split`: a total divided over months, charges inside the EMI; `emi`: the EMI typed in, charges billed separately), `principal` and `charges`. The form computes plans with `EmiCalculator` and never derives the type from names or notes. Open question: the posting direction for shared *loans* is not settled yet (see TODO).
- **Navigation**: GoRouter (`core/navigation/app_router.dart`) uses a `ShellRoute` for the tabbed pages (`/`, `/people`, `/expenses`, `/reports`) with a Material `NavigationBar`; detail/create/edit routes (`/people/:id`, `/add-person`, `/add-emi`, `/settings`, …) use `parentNavigatorKey: _rootNavigatorKey` so they cover the tabs. Modal sheets and forms opened via `Navigator.push` are likewise on the root navigator. The shell handles Android back with `PopScope` (back on a non-Home tab goes Home); don't use a `BackButtonListener` there — it fires before routes pushed on top and swallows their back press (`test/navigation_back_test.dart`).
- **Money** is stored as `REAL` (double); dates are stored by Drift as epoch seconds.
- **Erasing data** goes through `AppDatabase.eraseAllData()` (one transaction; keeps the self row). Don't delete tables piecemeal from UI code.
- **App Lock**: `AppLockController` (`app_lock_provider.dart`) owns `locked`/`obscured`; `DueMateApp` feeds it lifecycle changes and draws `AppLockScreen` or `AppPrivacyCover` over the router in `MaterialApp.builder`. Keep that `Stack` shape fixed (switching it rebuilds the router and loses page state). Settings that must be right on the first frame read `sharedPreferencesProvider`, which `main()` loads before `runApp`; tests override it. Lifecycle changes while the controller's own prompt is showing are ignored (the PIN screen pauses the app). `local_auth` 3.x throws `LocalAuthException`, mapped to `AppLockAuthResult` in `AppLockService`; tests use `test/helpers/fake_app_lock_service.dart`. `MainActivity` must stay a `FlutterFragmentActivity` and serves the `duemate/app_lock` channel (hide from recents).
- **Notifications**: `NotificationService` handles permission and test notifications. `scheduleEmiDueReminder` exists but is not called yet (see TODO).

## Design system

- **Theme** (`core/theme/app_theme.dart`): Roboto, tabular figures on numbers, tokens `AppSpace` / `AppRadius`. Never hardcode colours in widgets.
- **Money colours** (`LedgerColors`): green only for money coming to you, red only for money you owe; spending and lending are neutral ink with a +/− sign. Use `MoneyText` + `MoneyTone` instead of colouring amounts by hand.
- **Hide amounts** (`hideBalancesProvider`): toggle it through `setAmountsHidden` (`core/widgets/hide_amounts_toggle.dart`), never the notifier directly: showing amounts again goes through `AppLockController.revealAmounts` (verification). Any balance or total shown on screen must go through `MoneyText` or `ref.watch(displayMoneyProvider)` (`DisplayMoney`), which mask it while hidden. Use `CurrencyFormatter` directly only for amounts being typed, confirmations of what was just typed, exports/PDFs and shared messages; those always show the real number.
- **Layout**: tabs use `TabScaffold` (collapsing title); related rows go in one `GroupCard` of `ListTile`s, not a card per item. Lead each screen with its one important number. Destructive actions live in detail sheets behind `showConfirmDialog`, never as row icons.
- **Motion** (`core/theme/app_motion.dart`): fade-through between tabs, shared-axis slide for pushed pages, nothing decorative (no count-ups, staggered list entrances or press-scaling). Everything respects the system reduce-motion setting via `AppMotion.reduced`.
- **Charts**: category colours come only from `ExpenseCategoryX.chartColor` (validated categorical palette in fixed order; "Other" is grey). Labels and amounts stay in text colours, and every coloured mark has a text label.
- **Logo**: one vector source, `AppLogoPainter` (`core/widgets/app_logo.dart`), on Android's 108-unit adaptive-icon grid. `res/drawable/ic_launcher_foreground.xml` and `ic_launcher_monochrome.xml` repeat the same paths; keep them in sync. Legacy PNG icons and `assets/images/app_logo.png` are generated: `flutter test test_screens/logo_export_test.dart --update-goldens`.
- **Screenshots without a device**: `flutter test test_screens/screens_test.dart --update-goldens` seeds a realistic ledger and renders every main screen, sheet and form in light and dark to `test_screens/out/` (git-ignored). Text renders in real Roboto; shadows render as black outlines (a Flutter test artifact). Use it to check UI changes and keep it free of exceptions. Adding `--dart-define=DOCS=true` writes half-resolution images to `docs/screenshots/` instead; those are committed and used by `README.md` and `docs/SCREENS.md`, so regenerate them (and update `docs/SCREENS.md` text) whenever a screen changes visibly. New screens go in both the harness and `docs/SCREENS.md`.

## Tests

- `test/unit/` — pure logic: balances, EMI math and processor, `EmiCalculator`, `PersonMatcher`, expenses, formatters, permission manager.
- `test/e2e/` — repository-level flows against `AppDatabase(NativeDatabase.memory())` (`AppDatabase` accepts an optional `QueryExecutor`), including `eraseAllData`.
- `test/widget_test.dart`, `test/navigation_back_test.dart`, `test/emi_form_test.dart` — full-app and form widget tests.
- Widget tests with an in-memory DB: call `SharedPreferences.setMockInitialValues` (set `duemate_last_run_version` to `AppConstants.appVersionString` to skip the permission sheet), and tear down with `pumpWidget(SizedBox.shrink())`, `pump(1s)`, then `runAsync(db.close)`. Closing without pumping first hangs forever on Drift's stream-cleanup timers. Give each `testWidgets` an explicit `timeout:`, because `dart_test.yaml`'s 30 s limit doesn't apply to them.
- `test_screens/` is not part of `flutter test`; see *Design system* above.
