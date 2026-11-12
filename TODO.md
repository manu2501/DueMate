# DueMate — Roadmap

What's done, what's known to be missing, and what's next.

---

## ✅ Done

### Ledger and people
- [x] Record money given / received per person, with payment method, date and note; balances derived from transactions.
- [x] Person ledger: balance headline, Give / Receive, EMIs, history grouped by month, statement export (PDF / CSV), WhatsApp reminder, archive, delete with confirmation.
- [x] Add people by hand or from contacts; duplicate detection by phone (last 10 digits), name only when a number is missing (`PersonMatcher`, unit-tested).
- [x] Give / Receive sheet with "settle full balance" / "pay back all" shortcut.

### EMIs and loans
- [x] Card EMIs and loans, for yourself or shared with someone; type stored explicitly (schema v7).
- [x] Two ways to enter a plan: split a total (interest reducing / flat, charges) or type the known EMI (implied yearly rate shown) — `EmiCalculator`, unit-tested.
- [x] Charges and fees with an 18% GST helper (fee + interest only).
- [x] Per-month custom amounts; cleared automatically if the plan changes.
- [x] Installments auto-posted to the ledger on due dates; "Record now" posts the next one early.
- [x] Editing an EMI keeps its amounts (fixed: edit used to re-add interest on every save).

### Spending
- [x] Expense logging by category with Material icons; amount first, description optional; edit and delete from the expense sheet.
- [x] Monthly budget with "left / over" status on Home and Expenses.
- [x] Spending trends: monthly bars per year, category breakdown (validated colour palette), every expense of past months.

### App
- [x] Redesign: consistent money colours, number-first screens, grouped lists, one motion system (respects reduce-motion), new adaptive-icon logo and splash.
- [x] Activity timeline grouped by day with search, type / period / method filters, PDF / CSV export.
- [x] Settings: theme, currency, monthly budget, notifications permission, backup, CSV export, erase all data (now also removes expenses and EMIs).
- [x] Android back button closes forms and sheets opened over a tab instead of jumping Home.
- [x] Hide amounts: eye toggle on Home and a Settings switch mask every on-screen balance and total (remembered; typing, exports and shared messages unaffected).
- [x] EMIs & cards shortcut on Home.
- [x] MIT license; screen-by-screen docs with generated screenshots (`docs/SCREENS.md`).
- [x] Tests: unit, repository, widget and navigation tests (30 s timeout, no hangs); screenshot harness in `test_screens/`.

---

## ⚠️ Known gaps

- [ ] **Scheduled EMI reminders aren't wired up.** `NotificationService.scheduleEmiDueReminder` exists but nothing calls it; Settings only manages the permission and sends a test notification. Schedule (and cancel/reschedule) reminders when EMIs are created, edited, deleted or posted.
- [ ] **No restore from backup in the UI.** `BackupHelper.restoreBackup` exists but there is no way to pick a backup file (needs a file picker).
- [ ] **Shared loan direction needs a decision.** For loans you lend or borrow in installments, each installment is posted as money *given* (lent) or *received* (borrowed), so balances move the opposite way to a typical repayment loan, and the principal is never posted up front. Card EMIs paid on someone's behalf are correct. Decide the intended model, then change `EmiProcessorService` with a migration for existing loans.

---

## 🔜 Next

### Money in and out
- [ ] **Floating Rate & Repo Rate Adjustment:** Mark floating rate bank loans linked to repo rate (RLLR / EBLR). When repo rate increases or decreases, auto-recalculate new monthly EMI or adjust remaining tenure across all linked loans seamlessly.
- [ ] **UPI QR and deep links:** show a UPI QR on the Receive sheet (`qr_flutter`), and open UPI apps pre-filled (`upi://pay?...`).
- [ ] **Receipt attachments:** attach payment screenshots or receipts to entries, expenses and EMIs (`image_picker`), with a full-screen viewer.
- [ ] **Credit card bills:** statement date, total and minimum due, with reminders before the due date.
- [ ] **Loan prepayment:** remaining principal vs interest, and a close-early calculator.

### Insight
- [ ] **Lending cashflow chart:** money lent vs collected month by month (spending trends already exist).
- [ ] **Repayment reliability:** an on-time percentage per person.

### Privacy and convenience
- [ ] **App lock:** fingerprint / face unlock on launch and resume (`local_auth`).
- [ ] **Home-screen widget:** net position and the next EMIs due (`home_widget`).
- [ ] **Automatic backups:** scheduled encrypted backups to the user's own Google Drive.

---

## 📌 Technical notes
- Android only. `compileSdk` 37; min / target SDK follow Flutter's defaults.
- Clean architecture with Riverpod 3 and Drift (SQLite, schema v7, WAL).
- Design rules and the screenshot workflow are documented in `CLAUDE.md`.
