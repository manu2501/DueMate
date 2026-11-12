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

**Hide amounts.** The eye icon in the top bar (also a switch in Settings) masks every balance and
total across the app, for using it in public. Labels, counts and dates stay readable; amounts you
type, exports and shared messages are never masked. The choice is remembered. Showing amounts again
asks for your fingerprint, face or screen lock, so someone you hand the phone to can't un-hide them.

<p>
  <img src="screenshots/15_home_hidden.png" width="260" alt="Home with amounts hidden, light" />
  <img src="screenshots/15_home_hidden_dark.png" width="260" alt="Home with amounts hidden, dark" />
</p>

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

Theme, hide amounts and currency; monthly budget and your UPI ID (₹ only); App Lock and how soon it locks after you leave
the app; notifications (permission and a test notification); backup, CSV export, and erase all data
(asks first). About at the bottom.

### App Lock

<p>
  <img src="screenshots/16_app_lock.png" width="260" alt="App Lock, light" />
  <img src="screenshots/16_app_lock_dark.png" width="260" alt="App Lock, dark" />
</p>

With **App Lock** on (Settings › Security), DueMate opens locked and asks for your fingerprint, face
or the phone's screen lock straight away; **Unlock** asks again if you dismissed it. It locks again
when you come back after being away for the chosen time (immediately, 30 seconds, 1 or 5 minutes).
Turning it on or off asks you to verify first. While locked, back leaves the app instead of
closing pages behind the lock, and balances are kept out of the recent-apps thumbnail. If the
phone's screen lock is removed, App Lock turns itself off rather than locking you out.

---

## Sheets and forms

### Give / Receive

<p>
  <img src="screenshots/08_give_sheet.png" width="260" alt="Give sheet, light" />
  <img src="screenshots/08_give_sheet_dark.png" width="260" alt="Give sheet, dark" />
</p>

Choose a person (their balance shows, with a one-tap *settle full balance* / *pay back all* when
it applies), the amount with quick adds, payment method, date and note.

**UPI** (only when the currency is ₹). Giving to someone whose UPI ID is saved shows **Pay with
UPI app**: it opens your UPI app with their ID and the amount filled in; once the payment goes
through, tap **Give** to record it. Receiving shows **Show UPI QR**: a QR with your UPI ID and the
amount that any UPI app can scan, which you can also **Share** as an image. The first time, it asks
for your UPI ID (also in Settings › Money). WhatsApp reminders include your UPI ID when it's set.

<p>
  <img src="screenshots/17_give_upi.png" width="260" alt="Give with Pay with UPI app, light" />
  <img src="screenshots/18_upi_qr.png" width="260" alt="UPI QR, light" />
  <img src="screenshots/18_upi_qr_dark.png" width="260" alt="UPI QR, dark" />
</p>

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

Pick from contacts or type a name; phone (needed for WhatsApp reminders), UPI ID (to pay them from
a UPI app), email and notes are optional. Adding someone who's already in the ledger offers to open their ledger instead.
