# DueMate — Feature Roadmap & TODO List

DueMate is a personal ledger, lending, expense, and credit card EMI tracking application.

---

## ✅ Completed Features

- [x] **Duplicate Contact Protection:** Phone number normalization (`_normalizePhone` matching last 10 digits) preventing duplicate contact creation or re-importing identical phone numbers/names with option to open existing ledger.
- [x] **Redesigned New Person / Edit Person Page:** Live real-time avatar preview (`AvatarWidget`), one-tap phone contacts import hero card (`ContactsHelper.pickContact()`), preset relationship quick chips (*Friend*, *Colleague*, *Family*, *Roommate*, *Business*), and grouped input cards.
- [x] **Redesigned Floating Dock Navbar:** Expanding pill capsules with inline active section labels, primary accent highlights, and smooth layout transitions (`_FloatingDockNavBar`).
- [x] **Direct App Startup:** Removed onboarding welcome screen completely; app launches directly into the interactive Dashboard.
- [x] **Intuitive Motion & Animations:**
  - **Animated Currency Rollup:** Smooth `AnimatedCurrencyText` counter rollups when financial balances update or load.
  - **Staggered Entrance Motion:** Lightweight `FadeSlideTransition` for list cards and dues items across Dashboard, Directory, and Transactions screens.
  - **Interactive Press/Scale Feedback:** Tactile `PressableScale` spring response on buttons and quick action tiles.
- [x] **Redesigned Core UI Pages:**
  - **Dashboard Page:** Time-aware greeting header, high-contrast Net Ledger Hero card, quick actions dock bar, and horizontal top dues carousel with instant WhatsApp reminders.
  - **Directory Page:** Active contacts summary metrics, status filter chips (*All*, *Owes You*, *Settled*, *Archived*), and `PersonDirectoryTile` cards with quick receive/pay actions.
  - **Transactions Page:** Total transaction volume summary, cashflow overview card (*Total Given*, *Total Received*, *Net Difference*), date range filter chips, activity timeline, and person breakdown.
  - **Modal Navigation:** Root-navigator modal sheets hiding the bottom dock navbar and inline "Post Early" installment UX.
- [x] **Codebase Modularization:** Decomposed large monolithic screens into clean, single-responsibility, reusable widget components.
- [x] **Ledger Management:** Record money given and payments received per person with balance calculation.
- [x] **Credit Card EMI & Monthly Loans:** Track multi-month installment schedules with automated background posting.
- [x] **Custom Tenure Input:** Flexible number-of-months entry (e.g. 1, 5, 14, 60 months) with live breakdown recalculation and quick preset chips.
- [x] **WhatsApp Integration:** Direct WhatsApp payment reminders with custom templates (`whatsapp://send` & `wa.me/` with Android API visibility queries).
- [x] **Native Vector WhatsApp Icon:** Custom SVG-based vector painter (`WhatsAppIcon`) for WhatsApp branding.
- [x] **Smart Notifications:** Automated local notifications for upcoming EMI due dates with Settings toggle and test alert trigger (`flutter_local_notifications`).
- [x] **Statements & Data Export:** PDF statement generation (`pdf`) and CSV ledger backup/restore (`csv`).
- [x] **Contact Information Sheet:** Dedicated user information sheet showing phone, email, notes, and join date.
- [x] **UI & Layout Optimizations:** Lifted floating dock navbar, bottom sheet safe area inset handling, and Material 3 design system.
- [x] **Dependencies:** Upgraded all package dependencies to latest stable versions.

---

## 📋 Immediate Next Phase: Personal Expenses, Bank Loans, EMIs & UPI Hub

### 🚀 Phase 1: Personal Expense & Loan Management Suite (Immediate Execution)

#### 1. 💸 Personal Expenses & Budgeting
- [ ] **Daily Personal Expense Logging:** Record personal outflows (_Groceries, Utilities, Rent, Fuel, Food, Shopping_) with amount, category, date, and payment mode (UPI, Cash, Card, Bank).
- [ ] **Preset Category Chips & Icons:** Quick category selector tags (`🛒 Groceries`, `⚡ Utilities`, `⛽ Fuel`, `🍔 Food`, `🛍️ Shopping`, `🎬 Entertainment`, `🏥 Health`).
- [ ] **Monthly Expense Budget Limit & Alert:** Set a monthly personal expense budget limit (e.g. ₹25,000) with a live visual progress indicator on Dashboard and warning alerts at 80% / 100%.

#### 2. 🧮 Personal Bank Loans & Credit Card Bill Hub
- [ ] **Bank & Personal Loans Tracker:** Track loans taken from banks, financial apps, or family (_Home Loan, Car Loan, Personal Bank Loan_) with interest rate (% p.a.), EMI due date, and tenure.
- [ ] **Credit Card Bill & Due Date Alerts:** Record credit card statement billing dates, total due, and minimum due with automated reminder notifications before penalty dates.
- [ ] **Loan Amortization & Early Prepayment:** Live breakdown of remaining principal vs. interest paid, with one-tap "Prepay / Early Settlement" calculator.

#### 3. ⚡ Dynamic UPI QR Code & Direct App Launch
- [ ] **On-Screen Dynamic UPI QR Code:** Display a real-time `qr_flutter` QR code on the *Receive Payment* sheet for instant scanning via PhonePe, Google Pay, Paytm, or CRED.
- [ ] **Direct UPI Deep-Linking:** One-tap button to launch installed UPI apps with pre-filled VPA, recipient name, amount, and note (`upi://pay?pa=...&am=...`).

#### 4. 🧾 Receipt & Payment Proof Attachments
- [ ] **Image Attachments:** Attach UPI payment screenshots, bank SMS alerts, or physical paper receipts to transactions, expenses, or EMIs using `image_picker`.
- [ ] **Full-Screen Proof Viewer:** Tap any transaction or expense details card to view attached receipt photos in full screen.

---

### 📊 Phase 2: Security, Analytics & Widgets

#### 5. 🔒 Biometric Security & Stealth Mode
- [ ] **Fingerprint / Face ID Lock:** Local biometric authentication (`local_auth`) on app launch and resume.
- [ ] **Stealth Mode (Blur Balances):** Header toggle on Dashboard to blur monetary values when using the app in public.

#### 6. 📊 Borrower Reliability Score & Monthly Charts
- [ ] **On-Time Repayment Score:** Calculate a reliability percentage (e.g. *95% On-Time*) for each person based on promptness.
- [ ] **Monthly Cashflow Charts:** Visual bar/line charts comparing total money lent, collected, and spent month-over-month.

#### 7. 📱 Home Screen Widgets
- [ ] **Android & iOS Home Screen Widgets:** Interactive home screen widget (`home_widget`) displaying total pending balance (*You'll Get* vs. *You Owe*) and next 3 upcoming EMIs due this week.

---

### ☁️ Phase 3: Cloud Backup & Advanced Sync

#### 8. ☁️ Automated Cloud Sync
- [ ] **Google Drive / iCloud Auto-Backup:** Daily/weekly background sync of encrypted database backup files to the user's personal Google Drive or iCloud account.

---

## 📌 Technical Notes
- **Target SDK:** 37
- **Min SDK:** 21
- **Architecture:** Clean Architecture with Riverpod & Drift (SQLite)
