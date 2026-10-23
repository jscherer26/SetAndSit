# Set&Sit - Project Snapshot

- Generated: 2026-10-22 23:30 EDT
- Branch: main
- Snapshot commit: c5cfc3f
- Version: 1.0.0+1

## 1. What Changed Since Last Snapshot
Resolved cold restart persistence bugs and fixed physical device startup launch issues. Migrated `PreferencesService` from fragile monolithic JSON serialization to direct, awaited native primitive key persistence. Hardened `build.gradle.kts` release build configurations and `AndroidManifest.xml` auto-backup flags, and decoupled asynchronous manifest initialization from UI rendering.

- **Added:**
  - Dedicated persistent primitive keys in `PreferencesService`: `pref_duration`, `pref_instruction_density`, `pref_redirection_density`, `pref_prep_delay`, `pref_practice_mode`, `pref_selected_bell_id`, `pref_selected_practice_id`, `pref_selected_practice_name`, `pref_selected_voice_id`, `pref_selected_voice_idx`, `pref_clock_hour`, `pref_clock_minute`, `pref_clock_is_am`.
  - ProGuard rules file `android/app/proguard-rules.pro` keeping Flutter platform channels and SharedPreferences classes.
  - Visual default duration indicator inside Home Screen finish clock dial (`Practice Ends At (Default: 20m)`).
- **Changed:**
  - `lib/main.dart`: Fail-safe startup initialization where `PreferencesService` reads are executed safely before `runApp()`, while `AudioManifestService.initialize()` is fired non-blocking to prevent release-build freezes. Synchronized state assignments in `initState()`.
  - `lib/services/preferences_service.dart`: Replaced monolithic JSON blob with direct `await prefs.setInt`, `await prefs.setDouble`, `await prefs.setString`, and `await prefs.setBool` calls.
  - `lib/screens/settings_screen.dart`: Text input controllers validate immediately on every valid keystroke and hook slider disk writes to `onChangeEnd`.
  - `android/app/build.gradle.kts`: Release build configuration explicitly applies `proguard-rules.pro` with `isMinifyEnabled = false` and `isShrinkResources = false`.
  - `android/app/src/main/AndroidManifest.xml`: Configured `android:allowBackup="false"` and `android:fullBackupOnly="false"` to prevent stale cloud backup overwrites on app reinstall/reboot.
- **Removed:**
  - Monolithic single-blob JSON serialization of primitive settings that caused cascading resets when complex objects failed schema validation.
- **Metrics:**
  - Test suite: 55 unit and widget tests passing (100% pass rate).
  - Static analyzer (`flutter analyze`): 0 issues found.

## 2. Snapshot History
| Date | Commit | Summary |
|---|---|---|
| 2026-10-22 | c5cfc3f | Hardened direct primitive key persistence, release ProGuard config, disabled auto-backup |
| 2026-10-22 | d57f660 | Integrated Voice Management screen, VoiceConfig persistence, test suites, and Gradle memory tuning |
| 2026-10-22 | 33d385e | Added Practice Delay countdown, calibrated exact-start timing, fixed S16/bell overlap, unified Settings Defaults bubble |
| 2026-10-22 | 7e2a201 | Initial project architectural baseline snapshot |

## 3. Overview
Set&Sit is a clinical meditation and mindfulness application built with Flutter. It provides structured, time-bound meditation sessions ranging from 1 to 90 minutes with high-resolution acoustic bells, dynamically balanced silence intervals, and voice guidance personas. Sessions are structured around a 16-Segment Clinical Meditation Taxonomy ($S01$–$S16$) across four clinical archetypes (Focused Calm, Trauma-Informed Regulation, Open Awareness / Insight, and Metta / Compassion), along with custom practice configuration. The application operates entirely offline on-device without telemetry, user accounts, or external network dependencies.

## 4. Tech Stack & Dependencies

### Core Framework & Toolchain
- **Framework:** Flutter (Channel stable, 3.47.7)
- **Language:** Dart SDK `^3.13.5`
- **Target Platforms:** Android (minSdk 21, targetSdk 36), iOS, Linux Desktop, macOS, Windows, Web

### Runtime Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter` | SDK | Core UI framework and Material 3 design widgets |
| `audioplayers` | `^6.8.1` | Audio playback engine for meditation bells and spoken voice segments |
| `shared_preferences` | `^2.5.6` | Persistent key-value storage for settings, custom practices, and voice selections |
| `intl` | `^0.20.3` | Date, clock time, and duration formatting utilities |
| `wakelock_plus` | `^1.8.1` | Keeps the screen active during ongoing meditation sessions |
| `cupertino_icons` | `^1.0.8` | iOS-styled iconography |

### Dev Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | SDK | Unit and widget test framework |
| `audioplayers_platform_interface` | `^7.2.0` | Mock platform interface for audio player testing |
| `flutter_lints` | `^6.0.0` | Recommended code analysis rules and lints |

## 5. Architecture & Project Structure

### High-Level Architectural Pattern
State is centrally lifted into `RootControllerScreen` (`lib/main.dart`) using vanilla Flutter state management (`StatefulWidget`). Navigation between views is managed via an in-memory stack enum (`AppScreen`) and system-level back gesture handling via `PopScope`.

```
lib/
├── data/
│   └── bell_data.dart                 # Pre-configured acoustic bells metadata
├── engine/
│   └── session_queue_engine.dart      # 3-Zone silence distribution & timeline math
├── models/
│   ├── audio_models.dart              # AudioSegment, SessionItem, ClinicalArchetype models
│   ├── practice_config.dart           # Custom & system practice configurations
│   └── voice_config.dart              # Voice persona configuration (Kia, Grace)
├── screens/
│   ├── bell_configuration_screen.dart # Acoustic bell selection and auditioning
│   ├── clock_time_picker_dialog.dart  # Interactive wall-clock finish time picker
│   ├── configuration_screen.dart      # Home screen: dial, practice/voice/bell steppers
│   ├── manage_practices_screen.dart   # Practice management (custom archetype creation)
│   ├── manage_voices_screen.dart      # Voice persona selection and auditioning
│   ├── practice_screen.dart           # Active meditation playback & timer screen
│   ├── session_debug_screen.dart      # Detailed queue timeline inspector
│   └── settings_screen.dart           # Global defaults (duration, delay, density sliders)
├── services/
│   ├── audio_manifest_service.dart    # Manifest reader & duration lookup cache
│   └── preferences_service.dart       # Dedicated native key persistence engine
└── theme/
    └── app_theme.dart                 # Botanical minimalist color palette & styles
```

## 6. Features & Status
| Feature | Status | Primary Files | Description |
|---|---|---|---|
| Wall-Clock Finish Time Dial | Complete | `configuration_screen.dart`, `clock_time_picker_dialog.dart` | Radial finish time picker calculating session duration from target time |
| 3-Zone Silence Timeline Engine | Complete | `session_queue_engine.dart` | Allocates proportional silence gaps across settling, core, and deep silence |
| Voice Guidance Selection | Complete | `manage_voices_screen.dart`, `voice_stepper_card.dart` | Switch between Kia (Male) and Grace (Female) voice personas |
| Practice Archetype Customizer | Complete | `manage_practices_screen.dart`, `practice_config.dart` | Create, duplicate, and toggle clinical meditation practices |
| Acoustic Bells Library | Complete | `bell_configuration_screen.dart`, `bell_data.dart` | Selection of 10 acoustic meditation bells with volume balancing |
| Settings Defaults & Delay | Complete | `settings_screen.dart` | Configurable preparation delay (0–20s) and instruction density sliders |
| Dedicated Primitive Persistence | Complete | `preferences_service.dart` | Atomic, non-corruptible disk persistence directly to native SharedPreferences |
| Dual-Player Closing Overlap | Complete | `practice_screen.dart`, `session_queue_engine.dart` | Overlaps final voice guidance over decaying acoustic bell at $+2.5\text{s}$ |

## 7. Data, Services & Integrations
- **Data Models:** `AudioSegment`, `SessionItem`, `PracticeConfig`, `VoiceConfig`, `SavedState`.
- **Local Storage:** `shared_preferences` storing primitive settings under atomic keys, plus JSON collections for custom practices (`set_and_sit_practices`) and voice inclusion settings (`set_and_sit_voices`).
- **External Network / APIs:** None. Fully offline architecture.
- **Audio Assets:** 480 voice MP3s across Kia and Grace personas; 10 acoustic bell OGG files.

## 8. Platform & Configuration Details
- **Android:**
  - `applicationId`: `com.example.setandsit`
  - `minSdk`: 21, `targetSdk`: 36, Java 17 compile target.
  - Permissions: `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
  - Auto-Backup disabled (`allowBackup="false"`, `fullBackupOnly="false"`).
  - ProGuard rules: `proguard-rules.pro` applied with `isMinifyEnabled = false`.
- **iOS:**
  - Deployment target: iOS 12.0+
  - Background audio & wakelock capabilities configured.

## 9. Build, Run & Release
```bash
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run test suite
flutter test

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## 10. Testing & Quality
- **Test Inventory:**
  - `test/timeline_engine_test.dart`: 3-Zone silence distribution math, test-mode bypass, and pruning validation.
  - `test/preferences_test.dart`: SharedPreferences direct primitive key read/write verification across restarts.
  - `test/manage_practices_test.dart`: Practice creation, segment editing, and selection persistence.
  - `test/manage_voices_test.dart`: Voice persona filtering, audition playback, and inclusion logic.
  - `test/widget_test.dart`: Root controller smoke test and navigation verification.
- **Coverage:** 55 tests passing across all critical business logic and UI integration paths.
- **Static Analysis:** `flutter analyze` reports 0 issues.

## 11. TODOs, Known Issues & Technical Debt
- **Background Media3 / AudioService Integration:** Audio playback currently relies on foreground wakelock (`wakelock_plus`); migrating to a native Android MediaSession / Foreground AudioService is recommended for lock-screen media controls.
- **Package ID Migration:** `applicationId` remains `com.example.setandsit` and should be updated prior to Google Play Store publishing.

## 12. Metrics
- **Dart Source Files:** 20 files in `lib/` (approx. 8,850 lines of code).
- **Test Files:** 5 files in `test/` (approx. 2,390 lines of code).
- **Total Test Count:** 55 passing tests.

## 13. Suggested Next Steps
1. Test cold launch persistence on physical hardware using the updated release APK build.
2. Implement native Android `MediaSession` background service to enable lock-screen playback controls.
3. Update `applicationId` from `com.example.setandsit` to official clinical production reverse domain.
4. Add user-facing session completion statistics tracking (sessions completed, total minutes meditated).
