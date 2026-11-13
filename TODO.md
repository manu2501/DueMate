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

- [x] **EMI reminders:** the day before each of the next three installments of every active EMI, re-planned automatically from the EMI table (`EmiReminderPlanner` + `emiReminderSyncProvider`).
- [x] **Restore from backup:** Settings › Restore from a backup; validated before anything changes, replaces all data in one transaction.
- [x] **Your EMIs and loans are expenses** (schema v11): each installment is posted to expenses (category *EMIs & loans*) in its own month, including ones marked already paid; installments on the old self ledger are moved over. **Pay** records months ahead on the day paid. Shared loans keep posting like card EMIs (decided). A person page always shows *EMIs and loans* with an Add action.

---

## 🔜 Next

### Money in and out
- [ ] **Floating Rate & Repo Rate Adjustment:** Mark floating rate bank loans linked to repo rate (RLLR / EBLR). When repo rate increases or decreases, auto-recalculate new monthly EMI or adjust remaining tenure across all linked loans seamlessly.
- [x] **UPI QR and deep links:** UPI QR on the Receive sheet (shareable as an image), "Pay with UPI app" on Give for people with a saved UPI ID (schema v8), your UPI ID in reminders.
- [x] **UPI payment confirmation:** after "Pay with UPI app", DueMate asks "Did the payment go through?" when you come back (after App Lock, if it's up); Yes records the Give as UPI.
- [ ] **Receipt attachments:** attach payment screenshots or receipts to entries, expenses and EMIs (`image_picker`), with a full-screen viewer.
- [ ] **Credit card bills:** statement date, total and minimum due, with reminders before the due date.
- [ ] **Loan prepayment:** remaining principal vs interest, and a close-early calculator.

### Spending
- [x] **Recurring expenses:** monthly repeats (schema v9), posted on open with catch-up, managed under Expenses › Repeats every month.
- [x] **Tap a reminder to open its EMI.**

### Insight
- [x] **Lending cashflow chart:** Lending trends (People › chart icon), lent vs collected per month.
- [x] **Due dates on money you lend:** "Return by" on Give (schema v10), due/overdue on People and Home, Overdue filter, reminder the day before.
- [x] **Repayment reliability:** on-time share of dated loans per person (`RepaymentRecord`, same oldest-first matching as `LoanDues`), on the person page once one has been repaid.
- [x] **EMI schedule shows what is actually paid:** gaps and missed months (`EmiInstallments`); mark any month paid or unpaid, change its amount; deleting an EMI posting releases it.

### Privacy and convenience
- [x] **App lock:** fingerprint / face / screen-lock unlock on launch and resume (`local_auth`), with a lock delay.
- [ ] **Home-screen widget:** net position and the next EMIs due (`home_widget`).
- [ ] **Automatic backups:** scheduled encrypted backups to the user's own Google Drive.

---

## 📌 Technical notes
- Android only. `compileSdk` 37; min / target SDK follow Flutter's defaults.
- Clean architecture with Riverpod 3 and Drift (SQLite, schema v10, WAL).
- Design rules and the screenshot workflow are documented in `CLAUDE.md`.
