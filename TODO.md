# DueMate — Feature Roadmap & TODO List

DueMate is a personal ledger, lending, and credit card EMI tracking application.

---

## ✅ Completed Features

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

## 📋 Planned Features Roadmap

### 🚀 Phase 1: Security & Quick Payments

#### 1. ⚡ Dynamic UPI QR Code & One-Tap Launch
- [ ] **On-Screen UPI QR Code:** Display a dynamic `qr_flutter` QR code on the *Receive Payment* sheet for instant scanning via PhonePe, Google Pay, or Paytm.
- [ ] **Direct UPI Deep-Linking:** One-tap button to launch installed UPI apps with pre-filled VPA, recipient name, amount, and note (`upi://pay?pa=...&am=...`).

#### 2. 🔒 Biometric Security & Stealth Mode
- [ ] **Fingerprint / Face ID Lock:** Local biometric authentication (`local_auth`) on app launch and resume.
- [ ] **Stealth Mode (Blur Balances):** Header toggle on Dashboard to blur monetary values when using the app in public.

#### 3. 🧾 Receipt & Proof Attachments
- [ ] **Image Attachments:** Attach UPI payment screenshots, bank SMS, or physical bill receipts to transactions or EMIs using `image_picker`.
- [ ] **Receipt Viewer & Gallery:** Tap transaction details to view attached proof images full-screen.

---

### 📊 Phase 2: Analytics, Widgets & Categories

#### 4. 📊 Borrower Reliability Score & Analytics
- [ ] **On-Time Repayment Score:** Calculate a reliability percentage (e.g. *95% On-Time*) for each person based on promptness.
- [ ] **Monthly Cashflow Charts:** Visual bar/line charts comparing total money lent vs. collected month-over-month.

#### 5. 📱 Home Screen Widgets
- [ ] **Android & iOS Home Screen Widgets:** Interactive home screen widget (`home_widget`) displaying total pending balance (*You'll Get* vs. *You Owe*) and next 3 upcoming EMIs due this week.

#### 6. 🏷️ Category Tagging & Custom Filters
- [ ] **Custom Category Tags:** Tag transactions and EMIs (e.g. `#Electronics`, `#Rent`, `#Medical`, `#Travel`, `#Business`).
- [ ] **Tag Filtering:** Filter dashboard, reports, and CSV exports by category tags.

---

### ☁️ Phase 3: Cloud Backup & Advanced Utilities

#### 7. ☁️ Automated Cloud Sync
- [ ] **Google Drive / iCloud Auto-Backup:** Daily/weekly background sync of encrypted database backup files to the user's personal Google Drive or iCloud account.

#### 8. 🧮 Interest-Bearing Loans & Amortization
- [ ] **Simple & Compound Interest:** Support interest rates (% per annum/month) for personal loans given/taken.
- [ ] **Amortization Schedule:** Display a monthly principal vs. interest breakdown schedule.

---

## 📌 Technical Notes
- **Target SDK:** 37
- **Min SDK:** 21
- **Architecture:** Clean Architecture with Riverpod & Drift (SQLite)
