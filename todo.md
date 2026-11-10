Absolutely. What you are describing is essentially a **personal lending/receivables tracker**—but simpler than a traditional expense app.

The key problem isn't "expense tracking." It is:

> **"I lend money to people, they repay me in different ways and at different times, and I need a reliable ledger showing exactly how much each person owes me, what they have paid, and what is still outstanding."**

For Antigravity IDE, I would give it a proper product specification rather than just a prompt. Below is a specification you can directly use as the foundation.

# Product Specification — Personal Lending Tracker

## 1. Problem Statement

I frequently give money to friends, family members, colleagues, or other people. Over time, I lose track of:

- How much I originally gave someone
- When I gave the money
- Whether it was one payment or multiple payments
- How much they have repaid
- Whether repayments were daily, weekly, monthly, lump-sum, or adhoc
- How much is still outstanding
- Which people currently owe me money
- When the last payment was made
- How much I have given out in total
- How much I have recovered
- How much is still receivable

Existing expense-management applications are not ideal because this isn't really an expense.

This application should act as a **simple personal money ledger for money given to people and money received back from them.**

---

# 2. Product Vision

Build a **mobile-first Android application using Flutter** that makes it extremely easy to record money given to someone and subsequently track every repayment.

The application should answer these questions immediately:

> **Who owes me money?**

> **How much does each person owe me?**

> **How much have they already paid?**

> **When did they last pay?**

> **What transactions happened between us?**

The application should remain extremely simple and fast.

Adding a transaction should take **less than 10 seconds**.

---

# 3. Suggested Product Name

Working name:

**DueMate**

Other possibilities:

- LendLog
- DueTrack
- PayBack
- MyDues
- LendLedger
- DueBook
- MoneyDue
- HisDue
- OweTrack
- PocketLedger

The name should not imply banking or formal accounting.

---

# 4. Core Concept

The application revolves around three entities:

```text
Person
   │
   ├── Money Given
   │
   ├── Money Received
   │
   └── Outstanding Balance
```

For example:

### Rahul

Money given:

```text
₹10,000
```

Payments:

```text
₹1,000 — 01 Nov
₹500   — 03 Nov
₹1,000 — 05 Nov
₹2,500 — 10 Nov
```

Total received:

```text
₹5,000
```

Outstanding:

```text
₹5,000
```

The application should calculate this automatically.

---

# 5. Important Design Principle

**Do not model repayments as a fixed schedule.**

A person may say:

> "I'll pay ₹500 every day."

But in reality they might:

```text
Day 1 → ₹500
Day 2 → ₹500
Day 3 → Nothing
Day 4 → ₹1,500
Day 5 → ₹200
```

The application must support this naturally.

Therefore:

### A repayment is always a transaction.

There should be no requirement to create a payment schedule.

Schedules can be added later as an optional feature.

---

# 6. Core Features

## 6.1 Dashboard

The home screen should immediately show:

```text
Good morning 👋

Total Given
₹1,25,000

Total Received
₹82,500

Outstanding
₹42,500
```

Then:

```text
People owing you

Rahul
₹15,000

Suresh
₹12,500

Kiran
₹10,000

Anil
₹5,000
```

And:

```text
Recent activity

Rahul paid ₹1,000
Today

Suresh paid ₹500
Yesterday

Kiran received ₹5,000
Nov 7
```

---

# 7. Person Management

Users should be able to create a person.

### Person fields

```text
Name
Phone Number (optional)
Email (optional)
Profile Photo (optional)
Notes
Created Date
```

Example:

```text
Rahul Kumar
+91 XXXXX XXXXX

Notes:
Office friend
```

Phone number should be optional.

Do not force users to provide contacts permission.

---

# 8. Add Money Given

Primary action:

**+ Give Money**

Flow:

```text
Select Person
       ↓
Enter Amount
       ↓
Date
       ↓
Payment Method
       ↓
Optional Note
       ↓
Save
```

Example:

```text
Give Money

Person
Rahul

Amount
₹10,000

Date
10 Nov 2026

Payment Method
UPI

Note
Emergency loan
```

Buttons:

**Save Transaction**

---

# 9. Add Repayment

Primary action:

**+ Payment Received**

Flow:

```text
Select Person
       ↓
Enter Amount
       ↓
Date
       ↓
Payment Method
       ↓
Optional Note
       ↓
Save
```

Example:

```text
Payment Received

Rahul

Amount
₹500

Date
10 Nov 2026

Payment Method
UPI

Note
Daily payment
```

After saving:

```text
Rahul owes you

₹9,500
```

---

# 10. Transaction Types

The application should initially support only two transaction types.

### MONEY_GIVEN

Money moved from me → person.

### PAYMENT_RECEIVED

Money moved from person → me.

Internally:

```text
TransactionType.MONEY_GIVEN
TransactionType.PAYMENT_RECEIVED
```

Do not introduce unnecessary accounting terminology.

---

# 11. Balance Calculation

For every person:

```text
Outstanding =
Total Money Given
-
Total Payments Received
```

Example:

```text
Given:

₹10,000
₹5,000
₹2,000

Total Given = ₹17,000


Received:

₹1,000
₹2,000
₹500

Total Received = ₹3,500


Outstanding = ₹13,500
```

---

# 12. Person Details Screen

When opening a person:

```text
Rahul Kumar

Outstanding
₹13,500
```

Then summary:

```text
Given
₹17,000

Received
₹3,500
```

Then transaction timeline:

```text
10 Nov

↓ Received
₹500
UPI
"Daily payment"


08 Nov

↓ Received
₹2,000
Cash


05 Nov

↑ Given
₹5,000
UPI
"Additional amount"


01 Nov

↑ Given
₹10,000
UPI
```

Use clear visual differentiation between money given and money received.

---

# 13. Transaction History

Every transaction must be immutable by default.

Transaction:

```text
ID
Person ID
Type
Amount
Date
Payment Method
Note
Created At
Updated At
```

The user should be able to:

- Edit transaction
- Delete transaction
- View transaction details

When deleting:

```text
Are you sure?

Deleting this transaction will change
Rahul's outstanding balance.

Cancel
Delete
```

---

# 14. Payment Methods

Initially support:

```text
UPI
Cash
Bank Transfer
Card
Other
```

Allow the user to add custom payment methods later.

Payment method should be optional.

---

# 15. Dashboard Statistics

Dashboard should provide:

### Total Given

Sum of all `MONEY_GIVEN`.

### Total Received

Sum of all `PAYMENT_RECEIVED`.

### Total Outstanding

```text
Total Given - Total Received
```

### Active People

Number of people whose balance is greater than zero.

### Fully Settled

Number of people whose balance is zero.

---

# 16. Important Edge Cases

The application must handle:

### Partial repayment

```text
Given: ₹10,000
Received: ₹3,000

Outstanding: ₹7,000
```

### Multiple loans to same person

```text
₹10,000
+
₹5,000
+
₹2,000
```

All should belong to the same person.

### Multiple repayments

```text
₹500
₹500
₹1,000
₹2,000
```

### Full repayment

```text
Given: ₹10,000
Received: ₹10,000

Outstanding: ₹0
```

### Overpayment

Example:

```text
Given: ₹10,000
Received: ₹11,000
```

The application should **not silently show ₹0**.

Instead:

```text
Balance

₹1,000

Overpaid
```

The data model should support negative balances.

---

# 17. Transaction Timeline

The transaction history should feel like a conversation/ledger.

Example:

```text
                 Rahul

Outstanding
₹8,500

────────────────────────

Today

        Received
        ₹500
        UPI

────────────────────────

Yesterday

        Received
        ₹1,000
        UPI

────────────────────────

Nov 7

        Given
        ₹10,000
        Bank Transfer

────────────────────────
```

This makes it easy to understand the relationship financially.

---

# 18. Search

Global search should support:

```text
Person name
Phone number
Transaction notes
```

Example:

Searching:

```text
Rahul
```

returns:

```text
Rahul Kumar
₹8,500 outstanding
```

---

# 19. Filters

Transaction history should support:

```text
All
Money Given
Payments Received
```

And date filters:

```text
Today
This Week
This Month
Custom Range
```

---

# 20. Sorting

People list:

```text
Highest outstanding
Recently active
Alphabetical
Recently added
```

Default:

**Highest outstanding first.**

This makes the most important information immediately visible.

---

# 21. Reminders

This can be a **Phase 2 feature**.

The user should optionally be able to configure:

```text
Remind me to follow up with Rahul
Date: 15 Nov
Time: 10:00 AM
```

Important:

A reminder should not automatically mean that the person has promised to pay.

Keep:

**Reminder**

separate from:

**Payment Schedule**

---

# 22. Optional Payment Schedule

Phase 2.

A user could configure:

```text
Rahul

Expected payment

₹500
Every day
```

But actual payments should still be recorded independently.

For example:

```text
Expected
₹500/day

Actual:

Nov 1 → ₹500
Nov 2 → ₹500
Nov 3 → ₹0
Nov 4 → ₹1,000
```

This allows future analytics such as:

```text
Expected: ₹2,000
Received: ₹2,000
```

---

# 23. Notifications

Optional notifications:

```text
Payment reminder
Follow-up reminder
Daily summary
Weekly outstanding summary
```

Example:

> Rahul's outstanding balance is ₹8,500.

Avoid excessive notifications.

---

# 24. Reports

The application should eventually support:

### Overall report

```text
Total Given       ₹1,25,000
Total Received      ₹82,500
Outstanding         ₹42,500
```

### Person report

```text
Rahul

Total Given       ₹30,000
Total Received    ₹22,000
Outstanding        ₹8,000
```

### Date report

```text
November 2026

Given       ₹20,000
Received    ₹12,500
Net         ₹7,500
```

---

# 25. Export

Very useful feature.

Allow:

```text
Export CSV
Export PDF
Share report
```

Example:

```text
Rahul Kumar — Statement

Date        Type       Amount
--------------------------------
01 Nov      Given      ₹10,000
05 Nov      Received    ₹1,000
07 Nov      Received    ₹2,000
10 Nov      Received      ₹500

Total Given            ₹10,000
Total Received          ₹3,500
Outstanding             ₹6,500
```

---

# 26. Architecture

Since you specifically want Android + Flutter:

```text
Flutter
│
├── Presentation
│   ├── Screens
│   ├── Widgets
│   ├── Theme
│   └── Navigation
│
├── Domain
│   ├── Entities
│   ├── Use Cases
│   └── Repository Interfaces
│
├── Data
│   ├── Local Database
│   ├── Repository Implementations
│   └── Data Sources
│
└── Core
    ├── Utils
    ├── Constants
    ├── Extensions
    └── Error Handling
```

---

# 27. Recommended Flutter Stack

I would keep this **local-first**.

### Framework

**Flutter + Dart**

### State Management

**Riverpod**

### Navigation

**GoRouter**

### Database

**Drift + SQLite**

I would choose Drift over a simple key-value database because this application is fundamentally a relational ledger.

Relationships:

```text
Person
  ↓
Transactions
```

will become increasingly useful when reports, filtering, statistics and schedules are added.

### Local notifications

Flutter local notifications package.

### Serialization

Freezed + JSON serialization where appropriate.

### Architecture

```text
Feature-first Clean Architecture
```

---

# 28. Database Model

### Person

```text
Person
----------------
id
name
phone
email
notes
avatarPath
createdAt
updatedAt
archivedAt
```

### Transaction

```text
Transaction
----------------
id
personId
type
amount
transactionDate
paymentMethod
note
createdAt
updatedAt
```

### TransactionType

```text
MONEY_GIVEN
PAYMENT_RECEIVED
```

### PaymentMethod

```text
UPI
CASH
BANK_TRANSFER
CARD
OTHER
```

---

# 29. Currency

For the first version:

```text
INR ₹
```

But don't hardcode currency throughout the application.

Use:

```text
Currency
---------
code
symbol
decimalDigits
```

This makes internationalization possible later.

---

# 30. Data Safety

This is a **financial record application**, so data safety is important.

The application should:

- Work offline
- Never lose transactions
- Use database transactions when modifying data
- Validate amounts
- Prevent accidental duplicate submissions
- Confirm destructive operations
- Maintain timestamps
- Support database migrations
- Provide backup/export

---

# 31. Backup Strategy

Phase 1:

```text
Local database
+
Manual export
```

Phase 2:

```text
Encrypted backup
Google Drive
```

Phase 3:

```text
Optional cloud sync
```

Do **not** introduce mandatory accounts or cloud infrastructure in the MVP.

The application should work without login.

---

# 32. UX Principles

The most important UX principle:

> **Recording money should be faster than remembering it.**

The user shouldn't have to navigate through five screens.

Home screen:

```text
        ₹42,500
      Outstanding

[ + Give Money ]

[ + Payment Received ]

──────────────────

People

Rahul              ₹15,000
Suresh             ₹12,500
Kiran              ₹10,000
```

Long press or swipe actions can provide:

```text
Record Payment
Edit
Archive
```

---

# 33. Quick Payment Entry

This is particularly important for your use case.

From Rahul's profile:

```text
Rahul

₹15,000 outstanding

[ + Receive Payment ]

```

Tap:

```text
Amount

₹
500
```

Then:

```text
[ Receive ₹500 ]
```

Done.

No unnecessary screens.

---

# 34. Home Screen FAB

Use a single FAB:

```text
+
```

On tap:

```text
What do you want to record?

💸 Money Given

💰 Payment Received

👤 Add Person
```

---

# 35. Empty State

When there are no people:

```text
No lending records yet

Start keeping track of money
you give to friends and family.

[ Add Person ]
```

Do not show meaningless statistics such as ₹0 everywhere.

---

# 36. Settlement

When balance reaches zero:

```text
Rahul

✓ Settled

Total Given
₹10,000

Total Received
₹10,000
```

Allow the user to see settled people through:

```text
Active
Settled
All
```

---

# 37. Archive

Do not delete people automatically.

A person can be:

```text
Active
Archived
```

Archiving removes them from the primary list but preserves their history.

---

# 38. Important Accounting Rule

**Never modify historical transactions just to make the current balance correct.**

For example:

```text
Given ₹10,000

Received ₹2,000
Received ₹3,000
```

Do not modify the original ₹10,000 to ₹5,000.

Keep:

```text
Given = ₹10,000
Received = ₹5,000
Outstanding = ₹5,000
```

This gives the user a reliable audit trail.

---

# 39. MVP Scope

Antigravity should build **only these features initially**:

### MVP

- [ ] Flutter Android application
- [ ] Local SQLite database
- [ ] Person management
- [ ] Add money given
- [ ] Add payment received
- [ ] Person balance
- [ ] Dashboard
- [ ] Transaction timeline
- [ ] Edit transaction
- [ ] Delete transaction
- [ ] Search people
- [ ] Transaction filters
- [ ] Payment methods
- [ ] Settled people
- [ ] Archive people
- [ ] Basic statistics
- [ ] CSV export
- [ ] Material 3 UI
- [ ] Dark/light mode
- [ ] Offline-first architecture

### Do NOT implement initially

- Login
- Cloud backend
- Social features
- Chat
- Payment gateway
- Bank integration
- Automatic UPI detection
- AI
- Complex accounting
- Recurring payment enforcement

These can come later.

---

# 40. Future Features

The architecture should leave room for:

```text
Recurring payment schedules
Payment reminders
Push notifications
Cloud backup
Google Drive backup
Multi-device sync
AI transaction entry
Voice entry

"Rahul paid me 500 today"

→ Automatically create transaction

WhatsApp sharing

"Rahul owes you ₹5,000"

PDF statements

Multiple currencies

Multiple wallets/accounts

Family/shared ledger
```

---

# 41. AI / Natural Language Entry — Future

This could eventually become a very powerful feature.

User types:

> Rahul gave me ₹500 today

App understands:

```text
Person: Rahul
Type: PAYMENT_RECEIVED
Amount: ₹500
Date: Today
```

Or:

> I gave Suresh 10,000 yesterday through UPI

Automatically:

```text
Person: Suresh
Type: MONEY_GIVEN
Amount: ₹10,000
Date: Yesterday
Payment Method: UPI
```

But this should **not** be part of the MVP.

---

# 42. Antigravity IDE Master Prompt

You can give Antigravity the following as the initial instruction:

# Build: Personal Lending Tracker

## Objective

Build a production-quality Android application using Flutter for tracking money that I give to friends, family members, colleagues, and other people and the payments I receive back from them.

This is NOT a traditional expense-management application.

The core problem is:

> I frequently give money to people and later lose track of how much I gave, how much they have repaid, and how much they still owe me.

People may repay through daily payments, weekly payments, monthly payments, lump-sum payments, or completely adhoc payments.

Every payment must therefore be represented as an independent transaction.

The application must provide a clear, reliable ledger for each person.

---

## Product Principles

1. Extremely simple.
2. Fast transaction entry.
3. Offline-first.
4. No login required for MVP.
5. Local data storage.
6. Never lose historical transactions.
7. Every money movement is a transaction.
8. Balance is calculated from transaction history.
9. Do not assume repayment schedules.
10. Material Design 3.
11. Android-first.
12. Architecture must allow future cloud synchronization.

---

# Core Entities

## Person

Fields:

- id
- name
- phone
- email
- notes
- avatarPath
- createdAt
- updatedAt
- archivedAt

Phone and email are optional.

---

## Transaction

Fields:

- id
- personId
- type
- amount
- transactionDate
- paymentMethod
- note
- createdAt
- updatedAt

Transaction types:

- MONEY_GIVEN
- PAYMENT_RECEIVED

Payment methods:

- UPI
- CASH
- BANK_TRANSFER
- CARD
- OTHER

---

# Balance Calculation

For each person:

totalGiven = SUM(MONEY_GIVEN)

totalReceived = SUM(PAYMENT_RECEIVED)

balance = totalGiven - totalReceived

A positive balance means the person owes me money.

A zero balance means the account is settled.

A negative balance means the person has overpaid.

Never hide negative balances.

---

# Required Screens

## 1. Dashboard

Display:

- Total Given
- Total Received
- Total Outstanding
- Active People
- Recent Transactions

Display people ordered by highest outstanding balance by default.

Provide prominent actions:

- Give Money
- Receive Payment
- Add Person

---

## 2. People Screen

Display:

- Active people
- Settled people
- Archived people

Each person card should show:

- Name
- Outstanding amount
- Last transaction date

Support:

- Search
- Sorting
- Filtering

---

## 3. Person Details

Display:

- Person name
- Outstanding balance
- Total given
- Total received
- Last payment
- Complete transaction timeline

Actions:

- Give Money
- Receive Payment
- Edit Person
- Archive Person

---

## 4. Add Money Given

Fields:

- Person
- Amount
- Date
- Payment method
- Note

The amount must be positive.

Save as MONEY_GIVEN.

---

## 5. Add Payment Received

Fields:

- Person
- Amount
- Date
- Payment method
- Note

Save as PAYMENT_RECEIVED.

---

## 6. Transaction Details

Display:

- Transaction type
- Amount
- Person
- Date
- Payment method
- Note
- Created timestamp

Actions:

- Edit
- Delete

Deleting must require confirmation.

---

# UX

The application should optimize for extremely fast entry.

From a person's screen:

Receive Payment → enter amount → save.

Do not force unnecessary fields.

The user should be able to record a payment in a few seconds.

Use Material 3 components.

Support:

- Light theme
- Dark theme
- Dynamic Material colors where available
- Proper typography
- Accessible touch targets
- Empty states
- Loading states
- Error states
- Confirmation dialogs

---

# Architecture

Use feature-first Clean Architecture.

Suggested structure:

lib/

core/
constants/
errors/
extensions/
utils/
theme/

features/
dashboard/
people/
transactions/
reports/
settings/

data/
database/
repositories/

domain/
entities/
repositories/
usecases/

Use Riverpod for state management.

Use GoRouter for navigation.

Use Drift + SQLite for local persistence.

Use Freezed where useful for immutable models/sealed states.

---

# Database

Use proper migrations.

Database must support:

Person 1 → many Transactions

Foreign key:

Transaction.personId → Person.id

Do not store calculated balances as the source of truth.

Balances must be derived from transactions.

Use database transactions when performing multi-step modifications.

---

# Important Accounting Rules

Never alter previous transactions merely to make the balance correct.

Example:

Given ₹10,000

Received ₹2,000

Received ₹3,000

The database must retain all three transactions.

Calculated result:

Total Given = ₹10,000
Total Received = ₹5,000
Outstanding = ₹5,000

Do not replace the original transaction with ₹5,000.

---

# Edge Cases

Handle:

- Multiple loans to the same person
- Multiple repayments
- Partial repayment
- Full repayment
- Overpayment
- Same-day multiple transactions
- Backdated transactions
- Edited transactions
- Deleted transactions
- Archived people with historical transactions
- Zero balance
- Negative balance
- Large amounts
- Decimal currency values if supported

---

# Search and Filtering

Global search:

- Person name
- Phone number
- Transaction note

Transaction filters:

- All
- Money Given
- Payment Received

Date filters:

- Today
- This Week
- This Month
- Custom Range

People sorting:

- Highest Outstanding
- Recently Active
- Alphabetical
- Recently Added

---

# Reports

Provide basic reports:

Overall:

- Total Given
- Total Received
- Outstanding

Per person:

- Total Given
- Total Received
- Outstanding

Date range:

- Given during period
- Received during period
- Net outstanding change

---

# Export

Implement CSV export in MVP.

Export should contain:

Date
Person
Type
Amount
Payment Method
Note

Also provide a person-specific statement export.

Design the export layer so PDF export can be added later.

---

# Data Safety

This is financial record data.

The application must:

- Work completely offline
- Persist every transaction locally
- Use database transactions
- Validate all amounts
- Prevent accidental duplicate submissions
- Confirm destructive operations
- Support database migrations
- Avoid silently deleting data
- Provide export functionality

Do not introduce mandatory cloud accounts in MVP.

---

# Future Compatibility

The architecture must allow future implementation of:

- Payment reminders
- Recurring expected payments
- Cloud backup
- Google Drive backup
- Multi-device synchronization
- Voice transaction entry
- Natural-language transaction entry
- PDF statements
- WhatsApp sharing
- Multiple currencies
- Multiple wallets
- Optional authentication

Do not implement these features yet.

---

# Development Requirements

Before writing code:

1. Create the project architecture.
2. Define domain entities.
3. Define database schema.
4. Define repository interfaces.
5. Define use cases.
6. Define navigation.
7. Define Material 3 design system.
8. Define application states.
9. Define error handling.
10. Define database migration strategy.

Then implement feature by feature.

After every major feature:

- Run Flutter analyzer.
- Run unit tests.
- Run widget tests where appropriate.
- Fix all warnings and errors.
- Ensure the app remains buildable.

Do not use placeholder functionality where real local persistence is required.

Do not create unnecessary backend infrastructure.

The first release must be a polished, offline-first Android application.

### One important product suggestion

I would **not call this a "loan app"** in the UI. That makes it feel formal and complicated.

Think of the mental model as:

**People → Money Given → Money Received → Balance**

That makes it useful for everything from ₹200 a friend owes you to ₹1 lakh you lent someone.

And the killer feature for your particular use case should be **"Quick Receive"**. If someone pays you ₹500 today, you should be able to open their entry, tap **Receive**, enter `500`, and be finished in ~3 seconds. That is what will make you actually use the app consistently.
