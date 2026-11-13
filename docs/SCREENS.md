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

Then, most important first, and each only once it has something to show:

- **Balances**: the largest open balances (who owes you, whom you owe).
- **Spent in &lt;month&gt;**: spent so far against the monthly budget.
- **EMIs & loans**: one row with the next installment due, how many are active and what goes
  out each month; *See all* opens the EMI list.
- **Recent**: the last five entries.
- With no data yet, Home shows a short welcome with *Add a person* and *Add an expense*.

Amounts on screens are whole rupees; detail sheets, confirmations and exports keep paise.

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

Everyone you deal with, one row each: last activity (or when money is due back), and the balance
in words (*owes you*, *you owe*, *settled*). While someone is part way through paying back, the row
adds a **repayment bar**, e.g. *Paid ₹2,500 of ₹15,000 · 16%* (green when it's money coming back
to you; *You paid back …* in neutral ink when you owe them); at 0% or fully paid there's no bar.
Search by name, phone or notes; chips for **All · Owes you · You owe · Overdue**. The ⋮ menu has
*Sort by*, **Lending trends** and *Archived people*. Adding from contacts is in the Add person form.

**Due back.** When you give money with a *Return by* date, the row says when it's due
(*₹800 due back by 18 Nov*, *tomorrow*, *today*) in place of last activity. Once the date passes
it turns to *₹12,500 overdue since 7 Nov* in amber with a warning icon (overdue money is owed to you,
so it's never red). Repayments pay off the oldest loans first, so only the unpaid part counts. The
**Overdue** filter lists everyone who's late; Home's Balances show the same line.

- **Tap** a person to open their ledger.
- **Long-press** for shortcuts: give, receive, WhatsApp reminder.

### Expenses

<p>
  <img src="screenshots/04_expenses.png" width="260" alt="Expenses, light" />
  <img src="screenshots/04_expenses_dark.png" width="260" alt="Expenses, dark" />
</p>

This month's spending against the budget (*left*, *only … left* from 85%, *over* in red), then
**This month's expenses** grouped by day with a daily total; ones added automatically say so
(*Monthly* for repeats, *Installment 3* for your EMIs). Tap an expense to edit or delete it.
*Earlier months* and the chart icon open **Spending trends**.

**Repeats every month** sits above them as one collapsed card, a plan rather than spending: how
many bills, their monthly total and how many are already added this month. Open it to see each
bill with its amount *a month* (no minus sign) and *Added 4 Nov · next 4 Dec* or the day it posts.
They're added as ordinary expenses on that day each month (the 31st posts on the last day of
shorter months), catching up on any months missed while the app wasn't opened. Tap one to **change the amount** (from now on; past months keep theirs) or **stop repeating** (asks first;
expenses it already added stay).

<p>
  <img src="screenshots/21_recurring.png" width="260" alt="Recurring expense, light" />
  <img src="screenshots/21_recurring_dark.png" width="260" alt="Recurring expense, dark" />
</p>

<p>
  <img src="screenshots/10_expenses_emis.png" width="260" alt="Expenses, EMIs view, light" />
  <img src="screenshots/10_expenses_emis_dark.png" width="260" alt="Expenses, EMIs view, dark" />
</p>

**EMIs & loans** view: the monthly outgo on active EMIs, then each EMI with progress and the next
due date, in two sections: **Yours** and **With people**. Tap one for its schedule.

### Activity

<p>
  <img src="screenshots/05_activity.png" width="260" alt="Activity, light" />
  <img src="screenshots/05_activity_dark.png" width="260" alt="Activity, dark" />
</p>

Every ledger entry and expense in one timeline, grouped by day, for **this month** by default.
The period chip (this month, last month, this year, all time, custom dates) stays in view, since
the totals for money in, money out and spent follow it. **Filters** holds the rest: what to show
(everything / lending / expenses) and payment method; it shows a count while any are on. The
share icon exports the filtered entries as PDF or CSV.

---

## Pages

### Person ledger

<p>
  <img src="screenshots/03_person.png" width="260" alt="Person ledger, light" />
  <img src="screenshots/03_person_dark.png" width="260" alt="Person ledger, dark" />
</p>

Who owes whom and how much, a larger repayment bar (*Paid ₹2,500 of ₹15,000 · 16%*), when money
is due back (or overdue), how reliably they repay (*Repaid on time: 3 of 4 loans (75%)*, once a
loan with a "return by" date has been paid back; an unpaid one past its date counts against it), then **Give** / **Receive** for this
person. *EMIs and loans* follows (always shown: add a card EMI or loan for them; each installment
is added to their ledger on its due date), then history by month. The top bar has a WhatsApp reminder (when they
owe you and have a number) and a menu: share statement, share balance as text, contact details,
edit, archive, delete.

### Spending trends

<p>
  <img src="screenshots/11_charts.png" width="260" alt="Spending trends, light" />
  <img src="screenshots/11_charts_dark.png" width="260" alt="Spending trends, dark" />
</p>

Monthly totals for a year (pick the year top right; tap a month). For the chosen month: the
total, daily average and share of budget, **where it went** by category, and every expense that
month, each editable.

### Lending trends

<p>
  <img src="screenshots/20_lending_trends.png" width="260" alt="Lending trends, light" />
  <img src="screenshots/20_lending_trends_dark.png" width="260" alt="Lending trends, dark" />
</p>

From the chart icon on **People**: money you lent and collected each month of a year, side by side
(lent in neutral ink, collected in green, with a legend). Tap a month for its numbers; it leads with
the net (+ when more came back), then lent, collected and net for the month and the whole year.
Your own EMIs are spending, not lending, so they're left out.

### Settings

<p>
  <img src="screenshots/06_settings.png" width="260" alt="Settings, light" />
  <img src="screenshots/06_settings_dark.png" width="260" alt="Settings, dark" />
</p>

Theme, hide amounts and currency; monthly budget and your UPI ID (₹ only); App Lock and how soon it locks after you leave
the app; notifications (EMI reminders and a test notification); backup, **restore from a backup**,
CSV export, and erase all data (asks first).

**EMI reminders.** With notifications on, DueMate reminds you at 9:00 the day before each EMI
installment is due (on the day, if that's already passed), for the next three installments of every
active EMI. They stay in step automatically when EMIs are added, edited, deleted or posted, and
after a restore. While amounts are hidden or App Lock is on, reminders leave the amount out, and
their content is hidden on the lock screen.

**Restore from a backup.** Pick a backup file; DueMate shows what's in it (people, entries, EMIs,
expenses, and when it was made) and asks before replacing everything on the phone. A file that
isn't a backup, or is damaged, is refused without changing anything. About at the bottom.

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
it applies), the amount with quick adds, payment method, date and note (quick adds and methods each sit on one
line that scrolls sideways). Giving also has **Add a return-by date**, a link that opens to 1 week,
2 weeks, 1 month or any date (✕ removes it). You get a reminder the
day before (tap it to open that person), and the person shows as overdue once it passes. An entry's
date can be changed or cleared later from its details (*Edit*).

**UPI** (only when the currency is ₹). Giving to someone whose UPI ID is saved shows **Pay with
UPI app**: it opens your UPI app with their ID and the amount filled in. UPI apps don't tell
DueMate whether you paid, so when you come back (after unlocking, if App Lock is on) it asks **Did
the payment go through?** — **Yes, record it** saves the Give as a UPI payment; **Not yet** leaves
the sheet as it was. Receiving shows **Show UPI QR**: a QR with your UPI ID and the
amount that any UPI app can scan, which you can also **Share** as an image. The first time, it asks
for your UPI ID (also in Settings › Money). WhatsApp reminders include your UPI ID when it's set.

<p>
  <img src="screenshots/17_give_upi.png" width="260" alt="Give with Pay with UPI app, light" />
  <img src="screenshots/19_upi_paid.png" width="260" alt="Did the payment go through?, light" />
  <img src="screenshots/18_upi_qr.png" width="260" alt="UPI QR, light" />
  <img src="screenshots/18_upi_qr_dark.png" width="260" alt="UPI QR, dark" />
</p>

### Add expense

<p>
  <img src="screenshots/09_expense_sheet.png" width="260" alt="Add expense, light" />
  <img src="screenshots/09_expense_sheet_dark.png" width="260" alt="Add expense, dark" />
</p>

Amount first, then category. The description is optional (the category is used if empty).
**Repeat every month** (new expenses) makes it recurring from that date: this one is added now,
and the same expense is added on that day every month after.
When editing, the sheet also has *Delete expense*.

### Add EMI or loan

<p>
  <img src="screenshots/07_add_emi.png" width="260" alt="Add EMI, light" />
  <img src="screenshots/07_add_emi_dark.png" width="260" alt="Add EMI, dark" />
</p>

For yourself or with someone, card EMI or loan, what it was for and the card or lender. Then the
amount, entered either way:

- **Split a total**: amount and months.
- **I know the EMI**: the monthly EMI from the bank and months.

**More options** (folded away; opens by itself when editing an EMI that uses any of them):
interest (reducing or flat) when splitting a total, or the original amount when you know the EMI
(shows the extra you pay and the effective yearly rate); charges with an 18% GST helper; notes.
One **Add EMI** / **Save changes** button stays at the bottom of the screen.

A live summary shows the EMI, totals and last installment; *Make some months different* sets
uneven months. Finally the first due date and installments already paid (for your own EMIs,
each paid installment is added to expenses in the month it was due).

### EMI schedule

<p>
  <img src="screenshots/13_emi_details.png" width="260" alt="EMI schedule, light" />
  <img src="screenshots/13_emi_details_dark.png" width="260" alt="EMI schedule, dark" />
</p>

Monthly amount, paid and left, progress, then every installment as it really stands: *Paid*,
*Paid before tracking* (shared EMIs), *Not paid* for a past month left unpaid (warning colour,
with a count under the progress bar), *Next* or *Upcoming*. **Pay** on the earliest unpaid month
records one or more installments on the day you choose, filling a gap first, so you can pay ahead
(they are not posted again on their due dates). Your own EMIs and loans go to expenses (category
*EMIs & loans*), shared ones to the person's ledger. Edit and delete at the bottom (and a WhatsApp
reminder for shared EMIs). The sheet stays open and updates as you record payments. **Delete**
asks first and says what goes: the EMI and every payment it recorded (*its 2 payments in Asha's
ledger (₹2,000)*, so their balance changes); nothing is left behind.

<p>
  <img src="screenshots/22_emi_installment.png" width="260" alt="One installment, light" />
  <img src="screenshots/22_emi_installment_dark.png" width="260" alt="One installment, dark" />
</p>

Tap a month for its actions: **Mark as paid** (pick the day you paid), **Mark as unpaid** (asks
first; removes its expense or ledger entry, and it is not added back on its own) and **Change
amount** (this month only; a recorded payment changes too). Deleting an EMI's expense or ledger
entry elsewhere also marks that month unpaid. Cards, Home and reminders follow the months
actually paid.

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
