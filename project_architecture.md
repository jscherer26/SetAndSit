# Set&Sit - Comprehensive Architecture & Runtime Specification

- **Last Updated:** 2026-10-22 13:00 EDT
- **Current Version:** 1.0.0+1
- **Repository State:** main | 86c2cf8
- **Target Audience:** Clinical Reviewers, Somatic Flow Auditors, Lead Mobile Audio Engineers

---

## 1. High-Level Engine Overview

### 1.1 App Architecture & State Management
* **Framework:** Flutter (Channel stable, 3.47.7, Dart SDK `^3.13.5`).
* **State Management Pattern:** Vanilla Flutter `StatefulWidget` hierarchy with centralized state lifting.
  * `RootControllerScreen` ([`lib/main.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/main.dart)) acts as the single source of truth for runtime navigation, session preferences, active practice archetype selection, and voice persona management.
  * Screen transitions are routed via an internal enumeration `AppScreen` (`configuration`, `settings`, `bellSettings`, `managePractices`, `manageVoices`, `practice`, `sessionDebug`) rendered within a `switch` block in `RootControllerScreen.build()`.
  * Predictive Android back navigation is handled using Flutter's `PopScope`.
  * *Note:* No external state management packages (such as Riverpod, Bloc, or Provider) are used.

### 1.2 Local Persistence Layer
* **Service:** `PreferencesService` ([`lib/services/preferences_service.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/services/preferences_service.dart)) utilizing `shared_preferences: ^2.5.6`.
* **Stored Payloads:**
  * `set_and_sit_settings`: Core app preferences, slider positions, selected bell ID, target finish time, and voice index.
  * `set_and_sit_practices`: Custom practice configurations and segment variant overrides serialized via `PracticeConfig.toJson()`.
  * `set_and_sit_voices`: Voice persona order and inclusion status serialized via `VoiceConfig.toJson()`.

### 1.3 Audio Engine & Queue Driver
* **Active Audio Library:** `audioplayers: ^6.8.1`.
* **Execution Mechanism:**
  * Dual-stage session execution is handled directly within `_PracticeScreenState` ([`lib/screens/practice_screen.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/screens/practice_screen.dart)).
  * **Spoken Audio Items (`PlayAudioItem`):** Played via `_audioPlayer.play(AssetSource(rawPath))`. Queue advancement is driven by the `_audioPlayer.onPlayerComplete` stream listener.
  * **Silence Intervals (`PauseSilenceItem`):** Driven by an asynchronous 1-second interval timer `Timer.periodic(const Duration(seconds: 1))` with second-by-second countdown updates.
  * **Fallback Watchdog:** A secondary fallback timer triggers queue progression if an audio file fails to load or the platform player stream hangs.
* **Screen Stay-Awake:** `wakelock_plus: ^1.8.1` engages screen wake-lock upon session start and releases it on dispose or completion.
* **Background Audio Status:**
  * Audio currently executes in the foreground.
  * Native background playback services (`audio_session` or Android MediaSession foreground services) are not yet integrated; the app relies on `WakelockPlus` to keep the CPU and display active during formal practice.

---

## 2. Master Asset Hierarchy & Storage Locations

All meditation audio, acoustic bells, duration manifests, and script banks are bundled locally in `assets/`:

| Asset Category | Project Path | Quantity | Description / Role |
| :--- | :--- | :--- | :--- |
| **Clinical Master Manifest** | `assets/raw/session_manifest.json` | 1 file (3,709 lines) | Clinical Schema `3.5.0`. Contains full script text, word counts, active flags, and clinical taxonomy across all 16 segments. |
| **Precise Audio Durations** | `assets/raw/audio_durations.json` | 1 file (550 lines) | High-precision durations (seconds, two-decimal precision) for every voice clip across all variants. |
| **Voice Persona (Grace)** | `assets/audio/grace/` | 240 MP3s | Female voice persona clips named `${segmentCode}_${variantId}.mp3` (`S01_v01.mp3` through `S16_v15.mp3`). |
| **Voice Persona (Kia)** | `assets/audio/kia/` | 240 MP3s | Male voice persona clips named `${segmentCode}_${variantId}.mp3` (`S01_v01.mp3` through `S16_v15.mp3`). |
| **Acoustic Meditation Bells** | `assets/bells/` | 10 OGGs | High-resolution acoustic bells and singing bowls (durations 5s to 15s). |
| **Silence Buffer** | `assets/audio/silence.mp3` | 1 MP3 | Headless audio track for platform initialization. |

*Asset Loading:* Managed by `AudioManifestService` ([`lib/services/audio_manifest_service.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/services/audio_manifest_service.dart)) initialized at app launch (`AudioManifestService.initialize()`).

---

## 3. Clinical Archetypes & Active Pipelines

The application implements a 16-Segment Clinical Meditation Taxonomy ($S01$–$S16$) grouped into 5 therapeutic phases:
1. **Phase 1: Arrival & Agency:** $S01$ (External Arrival), $S02$ (Permission and Choice), $S03$ (Breath Orientation), $S04$ (Somatic Grounding), $S05$ (Safety / Resource Priming).
2. **Phase 2: Attentional Anchoring:** $S06$ (Attentional Anchor), $S07$ (Core Method Loop), $S08$ (Wandering-and-Return).
3. **Phase 3: State Cultivation:** $S09$ (Expansion / Open Awareness), $S10$ (Affective Cultivation), $S11$ (Cognitive Inquiry), $S12$ (Imagery Sequence).
4. **Phase 4: Deep Silence:** $S13$ (Integration Silence).
5. **Phase 5: Re-Orientation & Close:** $S14$ (Meaning Transfer), $S15$ (External Reorientation), $S16$ (Closing Guidance + Bell).

### 3.1 The 4 Official System Archetypes

```
+----------------------------------------------------------------------------------------------------+
|                                    OFFICIAL CLINICAL PIPELINES                                     |
+--------------------------+-------------------------------------------------------------------------+
| Archetype                | Full Ordered Segment Pipeline                                           |
+--------------------------+-------------------------------------------------------------------------+
| Focused Calm             | S01 -> S02 -> S03 -> S04 -> S06 -> S07 -> S08 -> S12 -> S13 -> S15 ->  |
|                          | S16                                                                     |
+--------------------------+-------------------------------------------------------------------------+
| Trauma-Informed          | S01 -> S02 -> S04 -> S05 -> S07 -> S08 -> S10 -> S12 -> S13 -> S14 ->  |
| Regulation               | S15 -> S16                                                              |
+--------------------------+-------------------------------------------------------------------------+
| Open Awareness /         | S01 -> S02 -> S03 -> S04 -> S08 -> S09 -> S10 -> S12 -> S13 -> S15 ->  |
| Insight                  | S16                                                                     |
+--------------------------+-------------------------------------------------------------------------+
| Metta /                  | S01 -> S02 -> S03 -> S04 -> S07 -> S11 -> S12 -> S13 -> S14 -> S15 ->  |
| Compassion               | S16                                                                     |
+--------------------------+-------------------------------------------------------------------------+
```

#### Clinical Rationale & Safeguards:
1. **Focused Calm (`focused_calm`):**
   * *Target:* Parasympathetic deceleration, baseline attentional stability.
   * *Protected Signature Pair:* `['S03', 'S08']` (Breath Orientation + Wandering-and-Return).
2. **Trauma-Informed Regulation (`trauma_informed`):**
   * *Target:* Explicit somatic safe-harbor, panic avoidance, agency preservation.
   * *Clinical Safeguard:* **Explicitly omits $S03$ (Breath Orientation)**. Breathing cues can trigger hyperventilation or traumatic autonomic recall in sensitized individuals. Uses somatic grounding ($S04$) and safety priming ($S05$).
   * *Protected Signature Pair:* `['S04', 'S05']` (Somatic Grounding + Resource Priming).
3. **Open Awareness / Insight (`open_awareness`):**
   * *Target:* Panoramic mindfulness, metacognitive decentering.
   * *Protected Signature Pair:* `['S08', 'S09']` (Wandering-and-Return + Panoramic Awareness).
4. **Metta / Compassion (`metta_compassion`):**
   * *Target:* Ventral vagal engagement, pro-social affect, self-compassion.
   * *Protected Signature Pair:* `['S04', 'S11']` (Somatic Grounding + Cognitive Inquiry / Metta Phrases).

---

## 4. 3-Zone Dynamic Silence Distribution & Timeline Math

The scheduling engine is implemented in `SessionQueueEngine` ([`lib/engine/session_queue_engine.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/engine/session_queue_engine.dart)).

### 4.1 Total Target Duration ($T_{\text{total}}$)
Resolved from user configuration (slider or target clock time) within bounds:
$$60\text{s} \le T_{\text{total}} \le 5400\text{s} \quad (1\text{ to }90\text{ minutes})$$

### 4.2 Opening Bell Removal
In adherence to clinical guidelines, **no opening bell is played**. The session opens immediately with quiet verbal guidance.

### 4.3 3-Zone Dynamic Allocation Architecture (Sessions $\ge 300\text{s}$)

$$\text{Dynamic Silence Pool} = T_{\text{total}} - T_{\text{audio}} - T_{\text{Zone1}}$$

Where:
* $T_{\text{audio}} = \sum \text{AudioDuration}(\text{segment}, \text{variant}) + 2.5\text{s (S16 overlap)}$
* $T_{\text{Zone1}} = \text{Fixed Zone 1 Bridges}$

#### Zone 1: Fixed Framing Bridges
Framing segments receive constant, fixed micro-silence intervals regardless of overall session duration:
* $S01, S02, S13, S14$: Fixed **$8.0\text{s}$** post-silence gap.
* $S15$: Fixed **$5.0\text{s}$** post-silence gap.
* $S16$: Fixed **$0.0\text{s}$** post-silence gap.

#### Zone 2: Dynamic Body Silence ($S03$–$S11$)
* **Allocation:** Receives **68%** of the dynamic silence pool:
  $$\text{Zone2 Pool} = \text{Dynamic Silence Pool} \times 0.68$$
* **Weighting:**
  * Settling Segments ($S03, S04, S05, S06, S07$): Weight = $1.0$
  * Core Practice Segments ($S08, S09, S10, S11$): Weight = $1.5$
* **Silence per segment:**
  $$\text{Silence}(\text{seg}) = \operatorname{round}\left(\text{Zone2 Pool} \times \frac{\text{Weight}(\text{seg})}{\sum \text{Weight}}\right)$$
* **Minimum Threshold:** Every active Zone 2 segment must receive **$\ge 45.0\text{s}$** of silence. If the calculated silence is $< 45\text{s}$, the Pruning Engine triggers.

#### Zone 3: Deep Silence Integration ($S12$)
* **Allocation:** Receives **32%** of the dynamic silence pool plus any integer remainder:
  $$\text{Silence}(S12) = \operatorname{round}(\text{Dynamic Silence Pool} \times 0.32) + \text{remainder}$$

---

## 5. Segment Pruning Engine & Test Mode Bypass

### 5.1 Pruning Rules (Sessions $\ge 300\text{s}$)
When total session duration is too short for all pipeline segments to maintain the $45\text{s}$ minimum silence threshold in Zone 2, segments are pruned iteratively.

1. **Protected Frame (Never Pruned):**
   $$\text{Protected Frame} = [S01, S02, S12, S13, S15, S16]$$
2. **Protected Signature Pair (Never Pruned):**
   The signature pair for the active archetype or custom practice is immune to pruning.
3. **Pruning Priority Order:**
   Segments are dropped one-by-one in this exact priority order until remaining Zone 2 segments satisfy the $\ge 45\text{s}$ threshold:
   $$\text{Prune Sequence} = [S14 \rightarrow S06 \rightarrow S04 \rightarrow S03 \rightarrow S07 \rightarrow S10 \rightarrow S08]$$

### 5.2 Test Mode Bypass for Ultra-Short Sessions ($< 300\text{s}$)

* **Sessions $\le 120\text{s}$ (Ultra-Short Mode):**
  Truncates pipeline to exactly 4 essential segments:
  $$\text{Pipeline}_{\le 120\text{s}} = [S01, \text{PrimarySignatureSegment}, S12, S16]$$
  * Primary Signature Segments: Focused Calm $\rightarrow S08$; Trauma-Informed $\rightarrow S04$; Open Awareness $\rightarrow S09$; Metta $\rightarrow S11$.
* **Sessions $121\text{s}$ to $299\text{s}$ (Abbreviated Frame Mode):**
  Constructed from the Protected Frame plus the Protected Signature Pair. Silence pool is weighted: $S12$ (weight 3.0), Signature Pair (weight 2.0), Framing segments (weight 1.0).

---

## 6. Closing Sequence & Dual-Player Acoustic Overlap

The closing sequence guarantees seamless transition without dead air or audio clipping:

```
+-------------------------------------------------------------------------------------+
|                              S16 DUAL-PLAYER OVERLAP TIMELINE                       |
+---------------------------------------------+---------------------------------------+
| Closing Bell Strike (e.g., 10.0s natural decay)                                     |
| [PlayAudioItem: Bell]                       |                                       |
+---------------------------------------------+---------------------------------------+
|  +0.0s Bell Strike  |  +2.5s Vocal Trigger  | S16 Spoken Outro (e.g., 6.5s)         |
|                     |                       | [PlayAudioItem: S16 Voice]            |
+---------------------------------------------+---------------------------------------+
```

1. **Exact Timestamp:** The closing bell strikes at $t = T_{\text{total}} - D_{\text{bell}}$.
2. **Dual-Player Overlap:** At $+2.5\text{s}$ after the bell strikes, the spoken outro ($S16\_vXX$) triggers while the bell's resonance continues decaying in the background.
3. **Post-Silence Gap:** Set to $0.0\text{s}$, guaranteeing the session completes on the exact target second.

---

## 7. Edge Cases, Interruption Handling & Screen Lifecycle

### 7.1 Early Finish & Truncation Shield
* **User Early Finish Modal:** If the user exits during practice, a confirmation dialog appears. If confirmed, the engine cancels timers and releases the wakelock.
* **Truncation Shield:** If the closing bell or $S16$ vocal outro is actively playing when an exit or cancel occurs, `_audioPlayer.stop()` is delayed to allow the bell decay and sign-off to conclude cleanly.

### 7.2 Silent Room / Mute Mode
* The mute toggle in `PracticeScreen`:
  * Mutes all spoken voice segments (`volume = 0.0`).
  * **Preserves the closing bell at soft volume (`volume = 0.35`)** so practitioners practicing in silence are alerted when the meditation period ends.

### 7.3 Lifecycle Interruption Recovery
* Handled via `WidgetsBindingObserver` in `_PracticeScreenState`.
* If app enters `paused` or `detached` states, timer states and current item indices are tracked.
* Re-engaging `resumed` state syncs remaining duration against the wall-clock target timestamp.

---

## 8. Clinical Script Bank & Audio Durations Matrix

### 8.1 Inventory
* **Total Clinical Segments:** 16 segments ($S01$–$S16$).
* **Script Variants per Segment:** Exactly 15 variants ($v01$–$v15$).
* **Total Script Variants:** 240 master script variants.
* **Active Voice Personas:** 2 (Kia - Male, Grace - Female).
* **Total Bundled Spoken Files:** 480 MP3s (240 Kia + 240 Grace).
* **Acoustic Bells:** 10 bells in `BellData` ([`lib/data/bell_data.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/data/bell_data.dart)).

### 8.2 JSON Schema (`session_manifest.json`)
```json
{
  "app": "SetAndSit",
  "schema_version": "3.5.0",
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

---

## 9. Practice & Voice Customization Architecture

### 9.1 Practice Configuration (`PracticeConfig`)
* Located in [`lib/models/practice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/practice_config.dart).
* Supports system archetypes and fully user-defined custom practices.
* Allows toggling inclusion (`isIncluded`), reordering, custom naming, and segment-level variant overrides (`segmentVariantOverrides: Map<String, String>`).

### 9.2 Voice Configuration (`VoiceConfig`)
* Located in [`lib/models/voice_config.dart`](file:///home/jscherer26/AndroidStudioProjects/setandsit/lib/models/voice_config.dart).
* Controls persona availability (Kia, Grace), preview sample playback, and active persona selection.

---

## 10. Automated Test Verification & Quality Audits

The architecture, timing formulas, and state persistence are verified by 49 automated tests in `test/`:

1. **`test/timeline_engine_test.dart` (349 lines):**
   * Validates 3-zone silence distribution math across 5m, 12m, 15m, and 30m sessions.
   * Validates test mode bypass rules ($\le 120\text{s}$ and $121\text{s}$–$299\text{s}$).
   * Validates segment pruning priority order and signature pair protection.
   * Validates $S16$ dual-player overlap calculation.
2. **`test/manage_practices_test.dart` (810 lines):**
   * Validates `PracticeConfig` JSON serialization/deserialization.
   * Validates custom practice creation, cloning, segment reordering, and fallback logic.
   * Validates queue generation with custom segment variant overrides.
3. **`test/manage_voices_test.dart` (551 lines):**
   * Validates `VoiceConfig` persistence and fallback selection when voices are excluded.
4. **`test/widget_test.dart` (124 lines):**
   * Smoke tests app bootstrapping, theme consistency, and root screen navigation.

**Audit Status:**
* `flutter test`: **49/49 tests pass**.
* `flutter analyze`: **0 issues found**.
