# DueMate screens

A reference for every main screen, sheet and form, in light and dark. The data shown is the
sample ledger seeded by the screenshot harness (four people, two EMIs, five expenses).

The images are generated, not hand-made. After a UI change, regenerate them with:

```bash
flutter test test_screens/screens_test.dart --update-goldens --dart-define=DOCS=true
```

Design rules behind these screens are in [`CLAUDE.md`](../CLAUDE.md#design-system). The short version:
green is money coming to you, red is money you owe, everything else is neutral; each screen
leads with its one important number; destructive actions live in detail views and confirm first.

---

## Tabs

### Home

<p>
  <img src="screenshots/01_home.png" width="260" alt="Home, light" />
  <img src="screenshots/01_home_dark.png" width="260" alt="Home, dark" />
</p>

Where you stand overall (owed to you / you owe, and the two sides), then the three things you do
most: **Give**, **Receive**, **Expense**.

- **EMIs & cards**: active count and what goes out each month (tap for all EMIs), the next
  installments due (tap for the schedule), and **Add** for a new EMI or loan.
- **Spending in &lt;month&gt;**: spent so far against the monthly budget.
- **Balances**: the largest open balances; **Recent**: the last five entries.
- With no data yet, Home shows a short welcome with *Add a person* and *Add an expense*.

### People

<p>
  <img src="screenshots/02_people.png" width="260" alt="People, light" />
  <img src="screenshots/02_people_dark.png" width="260" alt="People, dark" />
</p>

Everyone you deal with, one row each: last activity and the balance in words (*owes you*,
*you owe*, *settled*). Search by name, phone or notes; filter by open balance, settled or
archived; sort from the top bar; add from contacts.

- **Tap** a person to open their ledger.
- **Long-press** for shortcuts: give, receive, WhatsApp reminder.

### Expenses

<p>
  <img src="screenshots/04_expenses.png" width="260" alt="Expenses, light" />
  <img src="screenshots/04_expenses_dark.png" width="260" alt="Expenses, dark" />
</p>

This month's spending against the budget (*left*, *only … left* from 85%, *over* in red), then
expenses grouped by day with a daily total. Tap an expense to edit or delete it.
*Earlier months* and the chart icon open **Spending trends**.

<p>
  <img src="screenshots/10_expenses_emis.png" width="260" alt="Expenses, EMIs view, light" />
  <img src="screenshots/10_expenses_emis_dark.png" width="260" alt="Expenses, EMIs view, dark" />
</p>

**EMIs & loans** view: filter mine / shared / all, the monthly outgo on active EMIs, and each
EMI with progress and the next due date. Tap one for its schedule.

### Activity

<p>
  <img src="screenshots/05_activity.png" width="260" alt="Activity, light" />
  <img src="screenshots/05_activity_dark.png" width="260" alt="Activity, dark" />
</p>

Every ledger entry and expense in one timeline, grouped by day. Search, then narrow by type
(everything / lending / expenses), period (this month, last month, this year, custom dates) and
payment method. Totals for money in, money out and spent follow the filters. The share icon
exports the filtered entries as PDF or CSV.

---

## Pages

### Person ledger

<p>
  <img src="screenshots/03_person.png" width="260" alt="Person ledger, light" />
  <img src="screenshots/03_person_dark.png" width="260" alt="Person ledger, dark" />
</p>

Who owes whom and how much, what you gave and received, then **Give** / **Receive** for this
person. Their EMIs follow, then history by month. The top bar has a WhatsApp reminder (when they
owe you and have a number) and a menu: share statement, share balance as text, contact details,
edit, add EMI or loan, archive, delete.

### Spending trends

<p>
  <img src="screenshots/11_charts.png" width="260" alt="Spending trends, light" />
  <img src="screenshots/11_charts_dark.png" width="260" alt="Spending trends, dark" />
</p>

Monthly totals for a year (pick the year top right; tap a month). For the chosen month: the
total, daily average and share of budget, **where it went** by category, and every expense that
month, each editable.

### Settings

<p>
  <img src="screenshots/06_settings.png" width="260" alt="Settings, light" />
  <img src="screenshots/06_settings_dark.png" width="260" alt="Settings, dark" />
</p>

Theme and currency; monthly budget; notifications (permission and a test notification);
backup, CSV export, and erase all data (asks first). About at the bottom.

---

## Sheets and forms

### Give / Receive

<p>
  <img src="screenshots/08_give_sheet.png" width="260" alt="Give sheet, light" />
  <img src="screenshots/08_give_sheet_dark.png" width="260" alt="Give sheet, dark" />
</p>

Choose a person (their balance shows, with a one-tap *settle full balance* / *pay back all* when
it applies), the amount with quick adds, payment method, date and note.

### Add expense

<p>
  <img src="screenshots/09_expense_sheet.png" width="260" alt="Add expense, light" />
  <img src="screenshots/09_expense_sheet_dark.png" width="260" alt="Add expense, dark" />
</p>

Amount first, then category. The description is optional (the category is used if empty).
When editing, the sheet also has *Delete expense*.

### Add EMI or loan

<p>
  <img src="screenshots/07_add_emi.png" width="260" alt="Add EMI, light" />
  <img src="screenshots/07_add_emi_dark.png" width="260" alt="Add EMI, dark" />
</p>

For yourself or with someone, card EMI or loan, what it was for and the card or lender. Then the
amount, entered either way:

- **Split a total**: amount, months, optional interest (reducing or flat) and charges.
- **I know the EMI**: the monthly EMI from the bank; the original amount (optional) shows the
  extra you pay and the effective yearly rate.

A live summary shows the EMI, totals and last installment; *Make some months different* sets
uneven months. Finally the first due date and installments already paid.

### EMI schedule

<p>
  <img src="screenshots/13_emi_details.png" width="260" alt="EMI schedule, light" />
  <img src="screenshots/13_emi_details_dark.png" width="260" alt="EMI schedule, dark" />
</p>

Monthly amount, paid and left, progress, then every installment. Tap a month to change its
amount; **Record now** posts the next one to the ledger early. Edit and delete at the bottom
(and a WhatsApp reminder for shared EMIs).

### Entry details

<p>
  <img src="screenshots/14_tx_details.png" width="260" alt="Entry details, light" />
  <img src="screenshots/14_tx_details_dark.png" width="260" alt="Entry details, dark" />
</p>

One ledger entry: amount, person, date, time, method and note, with edit and delete.

### Add person

<p>
  <img src="screenshots/12_add_person.png" width="260" alt="Add person, light" />
  <img src="screenshots/12_add_person_dark.png" width="260" alt="Add person, dark" />
</p>

Pick from contacts or type a name; phone (needed for WhatsApp reminders), email and notes are
optional. Adding someone who's already in the ledger offers to open their ledger instead.
