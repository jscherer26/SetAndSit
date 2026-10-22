# Set&Sit - Project Snapshot

- Generated: 2026-10-22 13:45 EDT
- Branch: main
- Snapshot commit: 33d385e
- Version: 1.0.0+1

## 1. What Changed Since Last Snapshot
Implemented a configurable "Practice Delay" countdown (0–20s, default 10s) giving practitioners time to set down their phone and settle into posture before vocal guidance begins. The session queue and duration logic now calculate dynamically at the exact moment the delay finishes (or when "Begin Now" is tapped), ensuring sessions finish precisely at the scheduled clock time regardless of delay length. Resolved an audio focus collision and premature teardown bug between the S16 outro and acoustic bell decay. Merged Practice Duration, Practice Delay, and density sliders into a single unified "Defaults" bubble on the Settings screen, and updated the Session Debugger to reflect live session queue timing.

- **Added:**
  - `preparationDelaySeconds` (0–20s, default 10s) persisted in `PreferencesService` / `SavedState`.
  - Live preparation countdown ring, pulsing animation, and "Begin Now" skip button on `PracticeScreen`.
  - Dynamic, exact-start queue generation via `onBuildQueue` callback triggered at end of preparation delay.
  - Widget test verifying preparation countdown and practice transition (`test/widget_test.dart`).
- **Changed:**
  - Settings UI: Top bubble titled "Defaults", consolidating Practice Duration (`min`), Practice Delay (`sec`), Instructions Density, and Mind-Wandering Checks into a single container.
  - S16 and acoustic bell playback: Set `AudioContextAndroid` audio focus to `none` with iOS `mixWithOthers` so vocal sign-off and bell resonance play concurrently without ducking or cancellation.
  - Isolated `_isVoiceSegmentPlaying` flag in `PracticeScreen` so looping background silence stop events cannot trigger premature session completion.
  - `PracticeScreen` debug button updated to pass live `_activeQueue` and `_targetDurationSeconds` to `SessionDebugScreen`.
- **Metrics:**
  - Automated tests increased from 49 to 50 passing tests.
  - Dart codebase expanded from 9,698 lines to 10,243 lines across 23 files.

## 2. Snapshot History
| Date | Commit | Summary |
|---|---|---|
| 2026-10-22 | 33d385e | Added Practice Delay countdown, calibrated exact-start timing, fixed S16/bell overlap, unified Settings Defaults bubble |
| 2026-10-22 | 7e2a201 | Initial project architectural baseline snapshot |

## 3. Overview
Set&Sit is a clinical meditation and mindfulness application built with Flutter. It provides structured, time-bound meditation sessions ranging from 1 to 90 minutes with high-resolution acoustic bells, dynamically balanced silence intervals, and voice guidance personas. Sessions are structured around a 16-Segment Clinical Meditation Taxonomy ($S01$–$S16$) across four clinical archetypes (Focused Calm, Trauma-Informed Regulation, Open Awareness / Insight, and Metta / Compassion), along with custom practice configuration. The application operates entirely offline on-device without telemetry, user accounts, or external network dependencies.

## 4. Tech Stack & Dependencies

### Core Framework & Toolchain
- **Framework:** Flutter (Channel stable, 3.47.7)
- **Language:** Dart SDK `^3.13.5`
- **Target Platforms:** Android, iOS, Linux Desktop, macOS, Windows, Web (actively developed and verified on Android and Linux Desktop)

### Runtime Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter` | SDK | Core UI framework and material design widgets |
| `audioplayers` | `^6.8.1` | Audio playback engine for meditation bells and spoken voice segments |
| `shared_preferences` | `^2.5.6` | Persistent key-value storage for settings, custom practices, and voice selections |
| `intl` | `^0.20.3` | Date, clock time, and duration formatting utilities |
| `wakelock_plus` | `^1.8.1` | Keeps the screen active during ongoing meditation sessions |
| `cupertino_icons` | `^1.0.8` | iOS-styled iconography |

### Development & Test Dependencies
| Package | Version | Purpose |
|---|---|---|
| `flutter_test` | SDK | Unit, widget, and component test harness |
| `flutter_lints` | `^6.0.0` | Recommended static analysis and style lint rules |
| `audioplayers_platform_interface` | `^7.2.0` | Platform interface mocks and type contracts for testing audio player flows |

## 5. Architecture & Project Structure

### Annotated Directory Tree
```
setandsit/
├── android/                   # Native Android host project (Kotlin, Gradle 9.3.1, Java 17)
├── assets/
│   ├── audio/
│   │   ├── grace/             # 240 spoken MP3 voice clips (Female persona, S01_v01–S16_v15)
│   │   ├── kia/               # 240 spoken MP3 voice clips (Male persona, S01_v01–S16_v15)
│   │   └── silence.mp3        # Silent audio buffer asset
│   ├── bells/                 # 10 acoustic meditation bells/gongs (OGG format)
│   ├── icon/                  # Application branding and launcher icons
│   └── raw/
│       ├── audio_durations.json # High-precision two-decimal voice clip duration manifest
│       └── session_manifest.json# Clinical schema 3.5.0 (script text, taxonomy, word counts)
├── ios/                       # Native iOS host project (Xcode, Runner)
├── lib/                       # Dart application source code (19 files, 8,093 lines)
│   ├── data/
│   │   └── bell_data.dart     # Acoustic bell definitions and default sound library
│   ├── engine/
│   │   └── session_queue_engine.dart # Clinical queue generation, 3-zone silence math, pruning
│   ├── models/
│   │   ├── audio_models.dart  # Clinical taxonomy, audio segment models, session queue items
│   │   ├── practice_config.dart # Practice archetype profiles and segment override configs
│   │   └── voice_config.dart  # Voice persona definitions (Kia, Grace)
│   ├── screens/
│   │   ├── bell_configuration_screen.dart # Bell selector, previewer, and customization UI
│   │   ├── clock_time_picker_dialog.dart # Custom wheel/clock dialog for target finish time
│   │   ├── configuration_screen.dart     # Primary home dashboard and session setup screen
│   │   ├── manage_practices_screen.dart  # Practice archetype manager, editor, and creator
│   │   ├── manage_voices_screen.dart     # Voice persona toggles and preview playback
│   │   ├── practice_screen.dart          # Live session player, countdown ring, settling buffer
│   │   ├── session_debug_screen.dart     # Session queue inspector and timeline validator
│   │   └── settings_screen.dart          # Defaults bubble (duration, delay, densities) & sub-menus
│   ├── services/
│   │   ├── audio_manifest_service.dart   # Asset loader for durations and clinical manifest
│   │   └── preferences_service.dart      # SharedPreferences serialization/deserialization
│   ├── theme/
│   │   └── app_theme.dart     # Color palette (dark olive, cream, sand) and text styles
│   ├── widgets/
│   │   ├── practice_stepper_card.dart    # Practice archetype card widget with stepper controls
│   │   └── voice_stepper_card.dart       # Voice persona card widget with preview button
│   └── main.dart              # App entry point, RootControllerScreen, screen enum router
└── test/                      # Test suite (4 files, 2,150 lines, 50 passing tests)
    ├── manage_practices_test.dart        # PracticeConfig serialization and queue tests
    ├── manage_voices_test.dart           # VoiceConfig selection and persistence tests
    ├── timeline_engine_test.dart         # 3-Zone silence math, pruning priority, and bypass tests
    └── widget_test.dart                  # App bootstrap, time picker, and settling countdown tests
```

### Architecture Pattern & State Management
- **Pattern:** Centralized state lifting with vanilla Flutter `StatefulWidget` hierarchy.
- **Root Coordinator:** `RootControllerScreen` ([`lib/main.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/main.dart)) holds the master runtime state (selected duration, target finish time, settling delay, density parameters, selected practice, active bell, and active voice persona).
- **Navigation Flow:** Enum-driven screen switching (`AppScreen` rendered in `_buildScreen` switch statement) wrapped with `PopScope` for native Android back button handling.
- **Persistence Flow:** State mutations trigger `_persistState()`, which delegates to `PreferencesService` to serialize configuration entities into JSON within `SharedPreferences`.

### App Startup Flow
1. `main()` calls `WidgetsFlutterBinding.ensureInitialized()` and mounts `SetAndSitApp`.
2. `RootControllerScreen.initState()` triggers asynchronous initialization:
   - `PreferencesService.loadState()` retrieves user settings, settling delay, and custom configurations.
   - `AudioManifestService.initialize()` parses `assets/raw/audio_durations.json` into memory.
3. Once initialized, the home `ConfigurationScreen` displays configured durations and active practice archetype.

## 6. Features & Status

| Feature / Module | Description | Primary Files | Status |
|---|---|---|---|
| **Session Configuration** | Target duration selection (1–90 min slider or finish-at clock time picker), practice archetype dropdown, and bell selector. | [`lib/screens/configuration_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/configuration_screen.dart), [`lib/screens/clock_time_picker_dialog.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/clock_time_picker_dialog.dart) | Complete |
| **Practice Delay Buffer** | Configurable 0–20s settling countdown with breathing circle indicator, giving users time to put their phone down before guidance starts. Includes "Begin Now" bypass. | [`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart), [`lib/screens/settings_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/settings_screen.dart) | Complete |
| **Practice Runtime Player** | Dual-stage session execution: spoken voice playback triggered via `AudioPlayer` complete listener and silence countdowns driven by periodic interval timers. Includes pause, resume, progress ring, and early exit modal. | [`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart) | Complete |
| **Exact-Moment Queue Generation** | Recalculates exact target duration against wall clock at the conclusion of the settling delay so the session concludes precisely at the desired finish time. | [`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart), [`lib/main.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/main.dart) | Complete |
| **3-Zone Timeline Engine** | Mathematical silence allocation across Zone 1 (fixed arrival/exit bridges), Zone 2 (instruction intervals), and Zone 3 (deep silence), with deterministic segment pruning and test mode bypass (< 300s). | [`lib/engine/session_queue_engine.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/engine/session_queue_engine.dart) | Complete |
| **Dual-Player S16 Overlap** | S16 vocal outro triggers with +2.5s delay over the acoustic closing bell without ducking or cancellation on both Android and iOS. | [`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart) | Complete |
| **Clinical Archetypes** | Implementation of 4 clinical meditation archetypes (Focused Calm, Trauma-Informed Regulation, Open Awareness / Insight, Metta / Compassion) with defined segment sequencing. | [`lib/models/audio_models.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/audio_models.dart), [`lib/models/practice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/practice_config.dart) | Complete |
| **Practice Management** | Full CRUD for meditation practices: inclusion toggling, reordering, cloning, custom archetype creation, and segment-level variant overrides. | [`lib/screens/manage_practices_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/manage_practices_screen.dart), [`lib/widgets/practice_stepper_card.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/widgets/practice_stepper_card.dart) | Complete |
| **Voice Management** | Selection and audio sampling of dual voice guidance personas (Kia and Grace) with preference persistence. | [`lib/screens/manage_voices_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/manage_voices_screen.dart), [`lib/models/voice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/voice_config.dart) | Complete |
| **Bell Customization** | Preview, test play, and select default meditation acoustic bell from library of 10 acoustic bells/gongs. | [`lib/screens/bell_configuration_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/bell_configuration_screen.dart), [`lib/data/bell_data.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/data/bell_data.dart) | Complete |
| **Diagnostics & Debug** | Live visual inspector reflecting live session queues, segment duration verification, and silence distribution breakdown. | [`lib/screens/session_debug_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/session_debug_screen.dart) | Complete |
| **Background Audio Playback** | Background execution and platform lock screen media controls. Currently handled via foreground wake-lock (`wakelock_plus`); background services and OS media session controls are not yet integrated. | [`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart) | In progress / Planned |

## 7. Data, Services & Integrations

### Data Models
- **`AudioSegment`** ([`lib/models/audio_models.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/audio_models.dart)): Represents individual sound files (id, name, assetPath, durationSeconds, isIncluded).
- **`SessionItem`** (`PlayAudioItem`, `PauseSilenceItem`): Queue execution unit representing either voice/bell playback or a timed silence gap.
- **`PracticeConfig`** ([`lib/models/practice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/practice_config.dart)): Configurable practice archetype containing archetype ID, display name, description, active inclusion flag, and map of segment variant overrides.
- **`VoiceConfig`** ([`lib/models/voice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/voice_config.dart)): Voice persona model containing ID, name, gender, sample audio path, and inclusion flag.
- **`SavedState`** ([`lib/services/preferences_service.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/services/preferences_service.dart)): JSON-serializable model storing user preferences, selected bells, durations, settling delay (0–20s), density sliders, and clock targets.

### Local Storage & Persistence
- **Engine:** `shared_preferences`
- **Keys:**
  - `set_and_sit_settings`: Core user preferences, settling delay, and UI state.
  - `set_and_sit_practices`: Custom practice archetypes and segment override mappings.
  - `set_and_sit_voices`: Voice persona order and inclusion status.

### Clinical Audio & Metadata Assets
- `assets/raw/session_manifest.json`: Clinical schema 3.5.0 containing text, word count, active flags, and variant metadata for all 16 meditation segments ($S01$–$S16$).
- `assets/raw/audio_durations.json`: Precision audio durations for 480 MP3 recordings across both personas.
- `assets/bells/`: 10 acoustic meditation bells/gongs in OGG format.

### Backend, APIs & Analytics
- **Backend / Cloud Services:** None. Application is 100% on-device and local.
- **Third-Party Telemetry / SDKs:** None. Privacy-first architecture with zero tracking, crashlytics, or analytics SDKs.

## 8. Platform & Configuration Details

### Android Configuration
- **Package / Namespace:** `com.example.setandsit`
- **Build Toolchain:** Gradle 9.3.1, Android Gradle Plugin, Java 17 / JVM 17 target.
- **SDK Constraints:** `minSdk = flutter.minSdkVersion` (API 21), `targetSdk = flutter.targetSdkVersion` (API 36).
- **Permissions Declared (`AndroidManifest.xml`):**
  - `android.permission.WAKE_LOCK`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`

### iOS Configuration
- **Bundle Display Name:** `Set&Sit`
- **Bundle Identifier:** `$(PRODUCT_BUNDLE_IDENTIFIER)`
- **Orientation:** Supports Portrait and Landscape modes.

### Linux Desktop Configuration
- Native GTK/CMake runner compiled via Clang 19 and Ninja.

## 9. Build, Run & Release

### Common Developer Commands
- **Install dependencies:** `flutter pub get`
- **Run static analyzer:** `flutter analyze`
- **Run test suite:** `flutter test`
- **Run application on desktop:** `flutter run -d linux`
- **Run application on connected device:** `flutter run`
- **Build Android debug APK:** `flutter build apk --debug`
- **Build Android release APK:** `flutter build apk --release`

### CI/CD
- Currently no automated remote CI/CD workflows configured. Build verification and tests are executed locally.

## 10. Testing & Quality

### Test Suite Inventory
- **Total Passing Tests:** 50
- **Test Modules:**
  - `test/timeline_engine_test.dart` (349 lines): Verifies 3-zone silence distribution math across 5m, 12m, 15m, and 30m sessions; test mode bypass (< 120s and 121s–299s); and segment pruning priority rules.
  - `test/manage_practices_test.dart` (810 lines): Tests `PracticeConfig` JSON serialization, custom archetype creation, segment override routing, and integration with `SessionQueueEngine`.
  - `test/manage_voices_test.dart` (551 lines): Tests `VoiceConfig` persistence, fallback selection logic, and voice persona toggles.
  - `test/widget_test.dart` (170 lines): Tests initial application bootstrapping, theme verification, time adjustment dialog, and settling delay countdown / transition.

### Code Quality & Static Analysis
- **Linter:** `flutter_lints: ^6.0.0` activated via `analysis_options.yaml`.
- **Status:** `flutter analyze` reports **0 issues**.

## 11. TODOs, Known Issues & Technical Debt

### Source Code Comments
- Zero `TODO`, `FIXME`, or `HACK` tags exist in Dart source files (`lib/`).
- Standard boilerplate comments exist in `android/app/build.gradle.kts` regarding custom Application ID and release signing configuration.

### Known Technical Debt & Risky Areas
1. **Background Audio & MediaSession Integration:**
   - Active sessions currently keep the device awake using `WakelockPlus`. If the user minimizes the app or screen lock is engaged without an active audio stream playing (e.g. during a long Zone 3 silence gap), the OS may throttle background Dart timers. Migrating to an OS-level MediaSession foreground service will improve reliability.
2. **Default Application ID:**
   - Android Application ID is currently set to `com.example.setandsit`. This should be replaced with a production reverse-domain package name before production deployment.
3. **Release Signing:**
   - The Gradle release build type currently points to the debug keystore. Production signing credentials and keystores need to be configured.

## 12. Metrics
- **Dart Source Files (`lib/`):** 19 files, 8,093 lines of code
- **Dart Test Files (`test/`):** 4 files, 2,150 lines of code
- **Total Dart Codebase:** 23 files, 10,243 lines of code
- **Primary Screens:** 7 screens (`Configuration`, `Practice`, `Settings`, `BellConfiguration`, `ManagePractices`, `ManageVoices`, `SessionDebug`) + 1 custom dialog (`ClockTimePickerDialog`)
- **Unit / Widget Tests:** 50 tests (100% passing)
- **Audio Assets:** 480 voice MP3s, 10 acoustic bell OGGs, 1 silence MP3
- **Data Manifests:** 2 clinical JSON datasets (`session_manifest.json` at 3,709 lines, `audio_durations.json` at 550 lines)

## 13. Suggested Next Steps
1. **Implement Android & iOS Background Media Service:** Integrate `audio_session` or configure native foreground service notifications with playback controls so silence timers continue uninterrupted when the screen turns off.
2. **Configure Production App ID & Release Keystore:** Update `com.example.setandsit` to the final bundle identifier and configure secure signing for release APK/AAB generation.
3. **Add Continuous Integration (CI):** Add a GitHub Actions workflow to run `flutter analyze` and `flutter test` automatically on push and pull requests.
4. **End-to-End Practice Session Integration Test:** Add an integration test simulating a full session lifecycle from configuration through practice completion and dismissal.
