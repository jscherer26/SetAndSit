# Developer Action Prompt: Branding Updates to "Set&Sit", Store Display Names & GitHub Integration

## Executive Objective

Apply official brand identity updates (**Set&Sit**), configure App Store / Google Play display strings with correct XML/plist character escaping, align in-app UI headers, and ensure clean GitHub version control configuration via Android Studio.

---

## 1. Android Native String Escaping (`strings.xml`)

In Android XML resource files, raw ampersands (`&`) break AAPT/Gradle builds during compilation. 

Locate or update `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Launcher & Display Name (escaped for XML) -->
    <string name="app_name">Set&amp;Sit</string>
    <string name="app_subtitle">Adaptive Guided Meditation</string>
</resources>
```

*Note: If flavor-specific or debug string files exist (e.g., `values-night`, `values-es`), update them consistently.*

---

## 2. iOS Configuration (`Info.plist`)

Update `ios/Runner/Info.plist` to set the user-facing app icon label and bundle display name:

```xml
<key>CFBundleDisplayName</key>
<string>Set&amp;Sit</string>
<key>CFBundleName</key>
<string>Set&amp;Sit</string>
```

---

## 3. Flutter In-App App Bar, Splash & Metadata Alignment

1. **Root `MaterialApp` / `CupertinoApp` Title:**
   * In `lib/main.dart`, ensure `title` is set to `'Set&Sit'`:
     ```dart
     MaterialApp(
       title: 'Set&Sit',
       // ...
     );
     ```

2. **Top Navigation App Bar & Welcome Headers:**
   * Header title: `Set&Sit`
   * Subtitle / Feature descriptor tag: `Adaptive Guided Meditation`
   * Ensure store metadata copy alignment:
     * **Full Store Title:** `Set&Sit: Daily Meditation`
     * **Descriptor / Subtitle:** `Adaptive Guided Meditation`

3. **Identifier Consistency Rule:**
   * Keep internal package identifiers, Dart class names, and Git repository names clean without ampersands (e.g., `com.setandsit.app`, package imports, and repo name `SetAndSit`). Only user-visible display strings use `Set&Sit`.

---

## 4. Git & GitHub Integration Setup

Ensure local repository tracking is clean before pushing branch updates:

1. **Verify `.gitignore` Configuration:**
   Ensure `pubspec.lock` handling matches Flutter conventions and that temporary audio scratch directories or heavy test renders are excluded:
   ```gitignore
   # Flutter / Dart defaults
   .dart_tool/
   .flutter-plugins
   .flutter-plugins-dependencies
   .packages
   build/
   
   # Android Studio & Gradle
   .gradle/
   local.properties
   *.iml
   .idea/
   
   # Audio test renders & intermediate batch logs
   # Ensure production assets remain tracked:
   # Track: assets/raw/session_manifest.json
   # Track: assets/audio/kia/
   # Track: assets/audio/grace/
   # Track: assets/audio/bells/
   Generated_MP3s/
   *.wav
   ```

2. **Verify Remote & Commit:**
   * Stage the branding updates:
     ```bash
     git add android/app/src/main/res/values/strings.xml ios/Runner/Info.plist lib/
     git commit -m "feat(branding): update app display name to Set&Sit and escape XML entities"
     git push origin main
     ```

---

## 5. Verification Checklist

- [ ] Android project compiles without AAPT XML parsing errors.
- [ ] App launcher icon label shows `Set&Sit` on device home screen.
- [ ] iOS simulator displays `Set&Sit` under the app icon.
- [ ] Main app screen / splash header displays `Set&Sit` and `Adaptive Guided Meditation`.
- [ ] Production assets under `assets/audio/` and `assets/raw/session_manifest.json` are retained and tracked in Git.