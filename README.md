# 💰 MyMoney

A modern, full-featured personal finance tracker built with **Flutter** and **Firebase**. Track your income, expenses, and account transfers seamlessly with real-time cloud synchronization.

---

## ✨ Key Features

- **📊 Comprehensive Financial Overview**: Monitor total income, total expenses, and current net balance at a glance.
- **💸 Transaction Logging**: Record Income, Expense, and Account Transfer transactions with custom dates and notes.
- **📂 Categories & Super Categories**:
  - Customize income and expense categories with custom icons or uploaded images.
  - Group multiple categories into **Super Categories** (Category Groups) for organized budget tracking.
- **🏦 Multi-Account Management**: Track balances across multiple accounts (Cash, Bank, E-Wallets) with automatic balance adjustments upon transaction entry/edits.
- **☁️ Real-time Firebase Sync**: Cloud Firestore real-time data sync with secure multi-device access.
- **🔒 Firebase Authentication**: Secure email authentication and session management.

---

## 🛠️ Tech Stack

- **Frontend**: [Flutter](https://flutter.dev) (Dart)
- **Backend & Database**: [Firebase Authentication](https://firebase.google.com/docs/auth), [Cloud Firestore](https://firebase.google.com/docs/firestore)
- **Packages**:
  - `cloud_firestore` — Database synchronization
  - `firebase_auth` — User authentication
  - `intl` — Date formatting & number parsing
  - `image_picker` — Custom category and account photo uploads

---

## 📂 Project Structure

```text
lib/
├── main.dart                  # App entry point & main bottom navigation layout
├── authentication.dart        # Login and registration screens
├── home.dart                  # Dashboard & financial summary
├── records.dart               # All transactions view & filtering
├── new_record.dart            # Add/edit Income, Expense, or Transfer record
├── accounts.dart              # Account management (Add, Edit, Delete)
├── category.dart              # Category management (Add, Edit, Delete)
├── super_category.dart        # Super Categories overview
├── create_super_category.dart # Create/Edit Super Category groups
└── firebase_options.dart      # FlutterFire configuration settings
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.0.0`)
- Android Studio / VS Code with Flutter extension
- Firebase project configured with Firestore & Authentication

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/MK-0406/MyMoney.git
   cd MyMoney
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**:
   - Ensure your `android/app/google-services.json` and `lib/firebase_options.dart` are connected to your Firebase project.

4. **Run the app**:
   ```bash
   flutter run
   ```

---

