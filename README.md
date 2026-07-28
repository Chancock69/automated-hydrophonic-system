# AHS - Automated Hydroponics System

Flutter mobile app for monitoring a hydroponics chamber. The app uses:

- Flutter for the mobile UI
- Firebase Realtime Database through REST HTTP calls
- SQLite through `sqflite` for local plant records and cached sensor logs

## Main Screens

There are current app flows:

1. `WelcomeScreen` in `lib/main.dart`
   - Splash screen only.
   - Automatically opens the dashboard.

2. `DashboardScreen` in `lib/features/dashboard/screen_dashboard.dart`
   - Shows chamber status.
   - Lets the user add plants.
   - Lets the user edit and delete plant records.
   - Captures planted quantity, up to 6 positions.
   - Captures plant harvest type: single harvest or multiple harvest.
   - Stores plant records locally in SQLite.
   - Lets one plant become the active chamber plant.
   - Shows harvest tracking and opens harvest history.
   - Opens the plant area monitor for active plants.

3. `StatusScreen` in `lib/features/status/screen_status.dart`
   - Fetches latest sensor data from Firebase every 10 seconds.
   - Shows live temperature, humidity, pH, TDS, and water level.
   - Saves fetched readings into local SQLite.
   - Opens the logs screen.

4. `LogsScreen` in `lib/features/logs/screen_logs.dart`
   - Shows historical sensor readings.
   - Gets available dates from local SQLite and Firebase.
   - Reads local SQLite logs first, then falls back to Firebase if local logs are empty.
   - Shows a daily sensor graph.
   - Can export logs as PDF.

5. `AnalyticsScreen` in `lib/features/analytics/screen_analytics.dart`
   - Reads locally cached SQLite sensor logs for a plant.
   - Filters analytics by date range.
   - Lets the user focus on temperature, humidity, pH, TDS, or water level.
   - Shows record count, anomaly count, anomaly rate, min/max/average values, and metric trends.
   - Shows harvest productivity when harvest records exist.

6. `HarvestHistoryScreen` in `lib/features/harvest/screen_harvest_history.dart`
   - Shows harvest event logs.
   - Tracks harvest weight, survival count, life rate, and completed batches.

7. `PlantAreaScreen` in `lib/features/plant_area/screen_plant_area.dart`
   - Shows 6 plant positions.
   - Lets the user mark each planted position as alive or dead.
   - Lets the user adjust planted quantity during growth.

## Data Flow

Dashboard plant data:

```text
User adds plant -> SQLite plants table -> Dashboard list
```

Live sensor data:

```text
ESP32/device -> Firebase Realtime Database -> Flutter REST fetch -> Status screen -> SQLite sensor_logs table
```

Log viewing:

```text
Firebase date list -> selected date -> SQLite local logs first -> Firebase fallback -> log table/PDF
```

## Firebase Format

The app expects Firebase Realtime Database data in this path shape:

```text
/{year}/{MM}/{DD}/{HH:mm}
```

Example:

```text
/2026/07/22/21:30
```

Expected fields:

```text
temperature
humidity
PhLevel
TDS
water_level
```

Firebase access is implemented in `lib/data/remote/firebase_http.dart`.
Firebase host/auth settings are read from `lib/data/remote/firebase_config.dart`.
The app includes the current Realtime Database host and database secret by
default, and those values can still be overridden through `--dart-define`.

## SQLite Tables

SQLite is managed in `lib/data/local/database_helper.dart`.

Tables:

- `plants`
- `sensor_logs`
- `battery_state`
- `plant_slots`
- `harvest_events`

During development, the SQLite database is stored inside the emulator/app data area. If you uninstall the app from the emulator, local SQLite data will be removed.

## Source Structure

```text
lib/
  main.dart
  app/
    app_theme.dart
  data/
    models/
      harvest_event.dart
      plant_model.dart
      plant_slot.dart
      sensor_snapshot.dart
      sensor_thresholds.dart
    local/
      database_helper.dart
    remote/
      firebase_config.dart
      firebase_http.dart
  features/
    dashboard/
      screen_dashboard.dart
      widgets/
        dashboard_widgets.dart
    analytics/
      screen_analytics.dart
    harvest/
      screen_harvest_history.dart
    plant_area/
      screen_plant_area.dart
    status/
      screen_status.dart
      widgets/
        status_widgets.dart
    logs/
      screen_logs.dart
      widgets/
        logs_widgets.dart
```

This structure keeps app-level styling, shared models, local/remote data access, and user-facing features separated. Screen state and loading logic stay in the screen files, while private UI widgets live in each feature's `widgets/` file.

## Common Development Commands

```powershell
flutter clean
flutter pub get
flutter run
```

For Firebase-authenticated testing with a different database or token, pass the
host and token:

```powershell
flutter run -d emulator-5554 `
  --dart-define=AHS_FIREBASE_HOST=your-project-default-rtdb.firebaseio.com `
  --dart-define=AHS_FIREBASE_AUTH=YOUR_FIREBASE_DATABASE_TOKEN
```

After deleting generated files, run:

```powershell
flutter pub get
```

## Notes For Future Cleanup

- `build/` and `.dart_tool/` are generated and should not be edited manually.
- `android/` is needed for Android emulator/app builds.
- `ios/`, `web/`, `windows/`, `linux/`, and `macos/` are Flutter platform folders. Keep them unless the project is officially Android-only.
- Before publishing the repository publicly, move the Firebase token into
  `--dart-define` or a secure build pipeline.
