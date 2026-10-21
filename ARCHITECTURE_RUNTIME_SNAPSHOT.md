# Set&Sit: Comprehensive Architecture & Runtime Snapshot

**Document Version:** 1.0.0  
**Snapshot Date:** October 2026  
**Target Audience:** Clinical Reviewers, Somatic Flow Auditors, Lead Audio Engineers  
**Project Base:** `/home/jscherer26/AndroidStudioProjects/setandsit`  
**Purpose:** Technical specification of the exact live implementation in Dart/Flutter, covering pacing, acoustic scheduling, clinical pipelines, timeline math, and runtime state management.

---

## 1. High-Level Engine Overview

### 1.1 App Architecture & State Management
* **Framework:** Flutter (Dart SDK `^3.13.5`, Flutter SDK 3.x).
* **State Management Pattern:** Vanilla Flutter `StatefulWidget` with centralized state lifting.
  * `RootControllerScreen` (in [`lib/main.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/main.dart)) acts as the single source of truth for runtime navigation, user preferences, and state orchestration.
  * Screen transitions are managed via an enum `AppScreen` (`configuration`, `settings`, `bellSettings`, `practice`, `sessionDebug`) rendered within a `switch` block in `RootControllerScreen.build()`.
  * Persistence is handled via `PreferencesService` ([`lib/services/preferences_service.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/services/preferences_service.dart)), serializing a `SavedState` JSON payload to `SharedPreferences` (`set_and_sit_settings`).
  * *Note:* No external state management libraries (such as Riverpod, Bloc, or Provider) are currently installed or utilized.

### 1.2 Master Asset Hierarchy & Storage Locations
All session audio, script banks, acoustic bells, and timing tables reside in the root `assets/` directory:

| Asset Category | Project Relative Path | File Count | Description / Role |
| :--- | :--- | :--- | :--- |
| **Clinical Master Manifest** | `assets/raw/session_manifest.json` | 1 file (3,709 lines) | Schema `3.5.0`. Contains full script text, word counts, active flags, and variant metadata for all 16 segments. |
| **Precise Audio Durations** | `assets/raw/audio_durations.json` | 1 file (550 lines) | High-precision durations (seconds, two-decimal precision) for every voice clip across all variants. |
| **Voice Persona (Grace)** | `assets/audio/Grace/` (and alias `grace/`) | 240 MP3s | Female voice persona clips named `${segmentCode}_${variantId}.mp3` (`S01_v01.mp3` through `S16_v15.mp3`). |
| **Voice Persona (Kia)** | `assets/audio/Kia/` (and alias `kia/`) | 240 MP3s | Male voice persona clips named `${segmentCode}_${variantId}.mp3` (`S01_v01.mp3` through `S16_v15.mp3`). |
| **Acoustic Meditation Bells** | `assets/bells/` | 10 OGGs | High-resolution acoustic bell and gong recordings (5s to 15s durations). |

*Asset Resolution:* Managed by `AudioManifestService` ([`lib/services/audio_manifest_service.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/services/audio_manifest_service.dart)) initialized at app boot (`AudioManifestService.initialize()`).

### 1.3 Audio Player Lifecycle & Background Configuration
* **Active Player Library:** `audioplayers: ^6.8.1`.
* **Instance Management:** A single `AudioPlayer` instance is instantiated in `_PracticeScreenState` ([`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart)) and disposed in `dispose()`.
* **Queue Driver:** 
  * Spoken audio items (`PlayAudioItem`) are played via `_audioPlayer.play(AssetSource(rawPath))`, and queue progression is driven by the `_audioPlayer.onPlayerComplete` stream listener.
  * Silence intervals (`PauseSilenceItem`) are driven by an asynchronous 1-second interval timer `Timer.periodic(const Duration(seconds: 1))`.
  * A safety fallback timer (`_fallbackTimer`) triggers progression if an audio file fails to load or complete.
* **Background Audio Status:** 
  * Current implementation executes primarily in the foreground.
  * `just_audio` and `audio_session` are **not** currently integrated.
  * Platform-level background modes (e.g., iOS `UIBackgroundModes: audio` or Android foreground service with media session) are not yet configured in `Info.plist` or `AndroidManifest.xml`.

---

## 2. Clinical Archetypes & Active Pipelines

The application implements a 16-Segment Clinical Meditation Taxonomy ($S01$–$S16$) grouped into 5 therapeutic phases:
1. **Phase 1: Arrival & Agency** ($S01, S02, S03, S04, S05$)
2. **Phase 2: Attentional Anchoring** ($S06, S07, S08$)
3. **Phase 3: State Cultivation** ($S09, S10, S11, S12$)
4. **Phase 4: Deep Silence** ($S13$)
5. **Phase 5: Re-Orientation & Close** ($S14, S15, S16$)

### 2.1 The 4 Official Archetypes
Defined in [`lib/models/audio_models.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/audio_models.dart):

```
+-----------------------------------------------------------------------------------------+
|                                 CLINICAL ARCHETYPES                                     |
+--------------------------+--------------------------------------------------------------+
| Archetype                | Active Segment Pipeline                                      |
+--------------------------+--------------------------------------------------------------+
| Focused Calm             | S01 -> S02 -> S03 -> S04 -> S06 -> S07 -> S08 -> S13 ->     |
|                          | S15 -> S16                                                   |
+--------------------------+--------------------------------------------------------------+
| Trauma-Informed          | S01 -> S02 -> S04 -> S05 -> S06 -> S07 -> S08 -> S13 ->     |
| Regulation               | S14 -> S15 -> S16                                            |
+--------------------------+--------------------------------------------------------------+
| Open Awareness /         | S01 -> S02 -> S03 -> S04 -> S06 -> S09 -> S11 -> S13 ->     |
| Insight                  | S15 -> S16                                                   |
+--------------------------+--------------------------------------------------------------+
| Metta /                  | S01 -> S02 -> S04 -> S05 -> S06 -> S10 -> S12 -> S13 ->     |
| Compassion               | S14 -> S15 -> S16                                            |
+--------------------------+--------------------------------------------------------------+
```

#### Detailed Clinical Rationale:
1. **Focused Calm (`focused_calm`):**
   * *Target:* Attentional stability, parasympathetic deceleration, baseline concentration.
   * *Pipeline:* `[S01, S02, S03, S04, S06, S07, S08, S13, S15, S16]` (10 segments).
   * *Mechanism:* Moves from external sensory arrival ($S01$) and agency ($S02$) into breath orientation ($S03$) and somatic weight ($S04$). Employs focal breath anchor ($S06$), breath cycle counting ($S07$), and wandering redirection ($S08$).

2. **Trauma-Informed Regulation (`trauma_informed`):**
   * *Target:* High agency, explicit somatic safe-harbor, panic avoidance.
   * *Pipeline:* `[S01, S02, S04, S05, S06, S07, S08, S13, S14, S15, S16]` (11 segments).
   * *Safeguard / Exclusion:* **Explicitly omits $S03$ (Breath Orientation)**. Breathing cues can trigger hyperventilation or trauma loops in trauma survivors; the pipeline shifts directly from agency ($S02$) to contact points ($S04$) and establishes safe-harbor anchoring via $S05$ (Safety / Resource Priming).

3. **Open Awareness / Insight (`open_awareness`):**
   * *Target:* Decentering, panoramic mindfulness, metacognitive non-reactivity.
   * *Pipeline:* `[S01, S02, S03, S04, S06, S09, S11, S13, S15, S16]` (10 segments).
   * *Mechanism:* Bypasses narrow counting ($S07, S08$) after anchoring ($S06$), moving directly into expanding auditory/panoramic field ($S09$) and cognitive inquiry/labeling ($S11$).

4. **Metta / Compassion (`metta_compassion`):**
   * *Target:* Ventral vagal activation, relational warmth, pro-social affective priming.
   * *Pipeline:* `[S01, S02, S04, S05, S06, S10, S12, S13, S14, S15, S16]` (11 segments).
   * *Safeguard / Exclusion:* Bypasses vulnerable breath focus ($S03$). Introduces $S10$ (Affective Cultivation / Loving-Kindness phrases), $S12$ (Benefactor Imagery Sequence), and $S14$ (Meaning Transfer).

### 2.2 Short-Duration Abbreviated Pipeline Override (< 180s)
* **Trigger Condition:** `targetDurationSeconds < 180` (sessions under 3 minutes).
* **Problem:** Standard 10- or 11-segment pipelines contain ~130–150 seconds of spoken voice clips and bell acoustics alone, creating negative silence budgets ($D(S13) < 0$).
* **Implemented Override:** The pipeline is automatically truncated to:
  $$\text{Pipeline}_{\text{short}} = [S01, S04, S13, S16]$$
  * $S01$ (External Arrival): Grounds the practitioner.
  * $S04$ (Somatic Grounding): Settles posture.
  * $S13$ (Integration Silence): Dynamic silence buffer.
  * $S16$ (Closing Bell + Outro): Clean termination.

---

## 3. Dynamic "Exact End-Time" Math & Timeline Calculation

The scheduling engine is implemented in `SessionQueueEngine` ([`lib/engine/session_queue_engine.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/engine/session_queue_engine.dart)).

### 3.1 Total Target Duration ($T_{\text{total}}$)
Resolved in `_RootControllerScreenState._startPractice`:
* Calculated from the target clock time:
  $$T_{\text{total}} = \text{TargetDateTime} - \text{StartDateTime} \quad (\text{in seconds})$$
* Validated bounds: $60\text{s} \le T_{\text{total}} \le 5400\text{s}$ (1 to 90 minutes).

### 3.2 Post-Tap Settling Buffer ($P_{\text{settle}}$)
* **Duration:** Exact $4.0\text{s}$ silent pause (`const settlePauseSec = 4;`).
* **Placement:** Positioned as Item 0 in the queue (`PauseSilenceItem(4, displayTitle: 'Settling into Practice')`).
* **Purpose:** Allows the user to lower the phone, settle their posture, and release visual attention before $S01$ vocal guidance begins.
* **Opening Bell Elimination:** In adherence to contemporary clinical guidelines, **no opening bell is played**. The session opens in silence followed by gentle verbal entry.

### 3.3 Spoken Guidance Duration ($T_{\text{guidance}}$)
* Each active segment in the pipeline (excluding $S13$ and $S16$) selects one of its 15 variants at random:
  $$\text{variant} = \text{variants}[\text{Random}().\text{nextInt}(15)]$$
* Durations are looked up from `audio_durations.json`:
  $$T_{\text{guidance}} = \sum_{\text{seg} \in \text{Pipeline} \setminus \{S13, S16\}} D(\text{seg}, \text{variant})$$

### 3.4 Inter-Segment Micro-Pauses ($P_{\text{segment}}$)
To preserve somatic spaciousness between guidance cues, micro-pauses are inserted between every pre-closing guidance segment ($N_{\text{transitions}} = N_{\text{preClosing}} - 1$). The duration is stepped dynamically based on the session duration bracket:

$$P_{\text{segment}} = \begin{cases} 
2\text{ seconds} & \text{if } T_{\text{total}} \le 300\text{s } (\le 5\text{ min}) \\ 
6\text{ seconds} & \text{if } 300\text{s} < T_{\text{total}} \le 900\text{s } (5\text{--}15\text{ min}) \\ 
14\text{ seconds} & \text{if } T_{\text{total}} > 900\text{s } (> 15\text{ min}) 
\end{cases}$$

### 3.5 The Closing Boundary Sequence ($S16$) & $D_{\text{close}}$
The close is structured as an indivisible, highly buffered unit:

```
+-----------------------------------------------------------------------------------------------+
|                                    S16 CLOSING UNIT TIMELINE                                  |
+--------------------+---------------------+--------------------+---------------+---------------+
| 4.0s Pre-Bell      | Closing Bell        | 2.0s Post-Bell     | S16 Spoken    | 3.0s Trailing |
| Stillness          | (e.g., 15.0s)       | Stillness          | Outro (vXX)   | Stillness     |
| [PauseSilenceItem] | [PlayAudioItem]     | [PauseSilenceItem] | [PlayAudioItem| [PauseSilence] |
+--------------------+---------------------+--------------------+---------------+---------------+
```

Mathematical breakdown of $D_{\text{close}}$:
$$D_{\text{close}} = P_{\text{pre\_bell}}\,(4\text{s}) + D_{\text{bell}}\,(5\text{--}15\text{s}) + P_{\text{bell\_voice}}\,(2\text{s}) + D(S16, v)\,(3.6\text{--}6.5\text{s}) + P_{\text{post\_S16}}\,(3\text{s})$$

* **$P_{\text{pre\_bell}}$ (4s):** Silence signaling the end of deep integration before the acoustic bell strikes.
* **$D_{\text{bell}}$:** Full natural decay of the selected acoustic bell (e.g., Singing Bowl = 15s).
* **$P_{\text{bell\_voice}}$ (2s):** Allows the resonance of the bell to decay into quiet before speaking resumes.
* **$D(S16, v)$:** The closing vocal sign-off (e.g., *"Remembering that the practice doesn't end simply because a bell rings"*).
* **$P_{\text{post\_S16}}$ (3s):** Trailing silence buffer ensuring the last syllable reverberates naturally without an abrupt audio engine shutdown.

### 3.6 Dynamic Integration Silence ($S13$) Derivation
The remaining time budget is allocated to $S13$ (Deep Integration Silence):

$$D_{\text{fixed}} = P_{\text{settle}} + T_{\text{guidance}} + (N_{\text{transitions}} \times P_{\text{segment}}) + D_{\text{close}}$$
$$D(S13) = \max\Big(0, \operatorname{round}\big(T_{\text{total}} - D_{\text{fixed}}\big)\Big)$$

If $D(S13) > 0$, a `PauseSilenceItem` is inserted at the $S13$ position in the queue.

---

## 4. Edge Cases & Interruption Recovery

### 4.1 Premature Session Termination & Exit Protection
In `_PracticeScreenState._finishSession`:
* **Closing Bell Guarantee:** If the user manually finishes or cancels the session before reaching the closing boundary, the engine scans the remaining queue. If an unplayed closing bell exists, the player **jumps directly to the closing bell index** rather than cutting off abruptly:
  ```dart
  final closingIdx = widget.sessionQueue.lastIndexWhere((it) => it is PlayAudioItem && it.isBell);
  if (closingIdx != -1) {
    _currentIndex = closingIdx;
    _playCurrentQueueItem();
    return;
  }
  ```
* **Vocal & Bell Truncation Shield:** If the closing bell or $S16$ outro is actively playing when the timer reaches 0 or an exit is triggered, `_audioPlayer.stop()` is inhibited:
  ```dart
  final isBellPlaying = item is PlayAudioItem && item.isBell;
  final isOutroPlaying = item is PlayAudioItem && item.segment == ClinicalSegment.S16;
  if (!isBellPlaying && !isOutroPlaying) {
    await _audioPlayer.stop();
  }
  ```

### 4.2 Mute & Silent Room Mode
* Toggling the mute button in `PracticeScreen`:
  * Mutes all vocal guidance segments (`volume = 0.0`).
  * **Maintains the closing bell at a soft, non-invasive volume (`volume = 0.35`)** so the practitioner is reliably notified when practice has concluded.
  * The visual breathing orb continues to animate smoothly at 4-second sinusoidal cycles.

### 4.3 Current vs. Aspirational Interruption Recovery
| Interruption Behavior | Live Dart Implementation Status | Documented Aspirational Design (`2026Oct20_SAS.md`) |
| :--- | :--- | :--- |
| **Phone Call / Ringing** | Handled natively by OS audio routing (pauses or ducks audioplayers). No custom app callback. | Desired: Pause timer, track elapsed time $\Delta t$, deduct from $S13$ upon return. |
| **Audio Focus Loss** | Relies on default `audioplayers` behavior without explicit `AudioContext` focus listeners. | Desired: Hook `AudioSession` listeners to drop Phase 3 cues if $\Delta t > 90\text{s}$. |
| **Interruption Outlasts End Time** | If resumed after target time, timer shows 00:00 and advances to finish state. | Desired: Trigger immediate gentle chime without playing stale guidance. |

---

## 5. Script Variant Bank Summary

### 5.1 Registration Matrix

* **Total Active Segments:** 16 segments ($S01$ through $S16$).
* **Variants per Segment:** Exactly 15 variants per segment.
* **Total Script Variants:** 240 master script variants.
* **Active Voice Personas:** 2 (Kia - Male, Grace - Female).
* **Total Spoken Audio Files:** 480 audio files (240 Kia + 240 Grace).
* **Acoustic Bells Registered:** 10 bells in `BellData` ([`lib/data/bell_data.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/data/bell_data.dart)).

### 5.2 Taxonomy Segment Reference Table

| Code | Clinical Segment Name | Therapeutic Phase | Active Variants | Is Silence? |
| :--- | :--- | :--- | :---: | :---: |
| **S01** | External Arrival | Phase 1: Arrival & Agency | 15 (v01–v15) | No |
| **S02** | Permission and Choice | Phase 1: Arrival & Agency | 15 (v01–v15) | No |
| **S03** | Breath Orientation | Phase 1: Arrival & Agency | 15 (v01–v15) | No |
| **S04** | Somatic Grounding | Phase 1: Arrival & Agency | 15 (v01–v15) | No |
| **S05** | Safety / Resource Priming | Phase 1: Arrival & Agency | 15 (v01–v15) | No |
| **S06** | Attentional Anchor | Phase 2: Attentional Anchoring | 15 (v01–v15) | No |
| **S07** | Core Method Loop | Phase 2: Attentional Anchoring | 15 (v01–v15) | No |
| **S08** | Wandering-and-Return | Phase 2: Attentional Anchoring | 15 (v01–v15) | No |
| **S09** | Expansion / Open Awareness | Phase 3: State Cultivation | 15 (v01–v15) | No |
| **S10** | Affective Cultivation | Phase 3: State Cultivation | 15 (v01–v15) | No |
| **S11** | Cognitive Inquiry | Phase 3: State Cultivation | 15 (v01–v15) | No |
| **S12** | Imagery Sequence | Phase 3: State Cultivation | 15 (v01–v15) | No |
| **S13** | Integration Silence | Phase 4: Deep Silence | 15 (v01–v15) | **Yes** |
| **S14** | Meaning Transfer | Phase 5: Re-Orientation & Close | 15 (v01–v15) | No |
| **S15** | External Reorientation | Phase 5: Re-Orientation & Close | 15 (v01–v15) | No |
| **S16** | Closing Guidance | Phase 5: Re-Orientation & Close | 15 (v01–v15) | No |

### 5.3 Schema Structure in `session_manifest.json`

```json
{
  "app": "SetAndSit",
  "schema_version": "3.5.0",
  "description": "Production session manifest with 16 segments, multi-variant script banks, and Flutter asset audio maps.",
  "script_bank": {
    "S01": [
      {
        "variant_id": "v01",
        "variant_name": "1. External Sensory",
        "active": true,
        "text": "Taking a moment to arrive in the space you are in.",
        "word_count": 10
      }
    ]
  }
}
```

Parsed at runtime into Dart strongly-typed models:
* `ScriptVariant`: `variantId`, `variantName`, `active`, `text`, `wordCount`.
* `AudioManifestService`: Caches the parsed bank in memory (`Map<String, List<ScriptVariant>>`) and durations in `Map<String, Map<String, Map<String, double>>>`.

---

## 6. Verification & Automated Test Coverage

The timeline engine and queue generation math are continuously validated via automated tests in [`test/`](file:///home/jscherer26/AndroidStudioProjects/setandsit/test/):

1. **`test/timeline_engine_test.dart`:**
   * Validates archetype pipeline integrity ($S16$ termination, $S13$ presence).
   * Validates that $S13$ silence duration expands and contracts dynamically with overall target session time.
   * Validates silent session queue structure.
2. **`test/widget_test.dart`:**
   * Validates home screen loading, branding title (`Set&Sit`), descriptor (`Adaptive Guided Meditation`).
   * Validates full circular dial tap targets and time picker adjustment dialog triggers.

*All test suites pass cleanly via `flutter test`.*
