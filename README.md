
# Power House Billing — Real Flutter UI

This package contains a **working Flutter project** (web/desktop/mobile) with:
- Inventory (add/edit, stock adjust)
- Billing/POS (add by SKU, complete sale, auto stock decrement)
- PDF printing (works on web/desktop/mobile)
- Reports (today + month totals)
- Drift database with web (IndexedDB) and desktop/mobile (SQLite)

## Setup
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d chrome   # web
flutter run -d windows  # desktop (or macos/linux)
flutter run -d android  # android
```
