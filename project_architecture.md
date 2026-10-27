# Set&Sit - Comprehensive Architecture & Runtime Specification

- **Last Updated:** 2026-10-23 00:45 EDT
- **Current Version:** 1.0.0+1
- **Repository State:** main | c12189a

---

## 1. High-Level Engine Overview
Set&Sit is an offline clinical meditation and somatic guidance mobile application written in Flutter/Dart (`sdk: ^3.13.5`). It calculates dynamically proportioned silence intervals between spoken audio segments based on a wall-clock target finish time or explicit duration input (1–90 minutes).

### State Management & Navigation
- State is centrally lifted into `RootControllerScreen` (`lib/main.dart`) using vanilla Flutter `StatefulWidget`.
- Screen transitions are coordinated via an internal navigation stack enum (`AppScreen`):
  `configuration`, `settings`, `bellSettings`, `managePractices`, `manageVoices`, `practice`, `sessionDebug`.
- Android system predictive back gestures and hardware back navigation are intercepted by `PopScope` to preserve in-memory and disk states before screen unmounting.

### Persistence Engine
- Handled by `PreferencesService` (`lib/services/preferences_service.dart`) using `shared_preferences`.
- Primitive settings are written directly to native disk storage using atomic keys (`pref_duration`, `pref_prep_delay`, `pref_instruction_density`, `pref_redirection_density`, `pref_practice_mode`, `pref_selected_bell_id`, `pref_selected_practice_id`, `pref_selected_voice_id`, `pref_clock_hour`, `pref_clock_minute`, `pref_clock_is_am`).
- Multi-object collections (`PracticeConfig` list and `VoiceConfig` list) are stored as isolated JSON strings.

---

## 2. Master Asset Hierarchy & Storage Locations
All session audio cues and metadata are stored bundled locally within the app:
- **Clinical Script Bank:** `assets/raw/session_manifest.json` (Manifest Schema 3.5.0, 16 segments, 15 variants each = 240 scripts).
- **High-Precision Audio Durations:** `assets/raw/audio_durations.json` (Pre-calculated exact segment durations in seconds).
- **Spoken Voice Guidance Files:**
  - `assets/audio/kia/`: 240 MP3 files for Kia (Warm & Grounded Male persona).
  - `assets/audio/grace/`: 240 MP3 files for Grace (Clear & Serene Female persona).
- **Acoustic Meditation Bells:**
  - `assets/bells/`: 10 acoustic meditation bells/singing bowls in OGG format.
- **Silent Buffer:**
  - `assets/audio/silence.mp3`: 100ms silent audio track for hardware platform audio warming.

---

## 3. Clinical Archetypes & Active Pipelines
The clinical guidance is structured across a **16-Segment Clinical Meditation Taxonomy ($S01$–$S16$)**:

### Phase Breakdown
1. **Phase 1: Arrival & Agency ($S01$–$S05$):** Posture, gentle transition, breath awareness, body grounding, somatic agency.
2. **Phase 2: Attentional Anchoring ($S06$–$S08$):** Progressive muscle softening, diaphragmatic cadence, cognitive stabilization.
3. **Phase 3: State Cultivation ($S09$–$S12$):** Open awareness, emotional regulation, loving-kindness (metta), deep meditative silence.
4. **Phase 4: Deep Silence ($S13$):** Returning agency bridge.
5. **Phase 5: Re-Orientation & Close ($S14$–$S16$):** Sensory awakening, appreciation & closure, closing acoustic resonance bell.

### Official System Archetypes
- **Focused Calm (`focused_calm`):** Standard attentional stability archetype ($S01, S02, S03, S04, S06, S07, S08, S12, S13, S15, S16$).
- **Trauma-Informed Regulation (`trauma_informed`):** Omits breath orientation ($S03$) to prevent hyperventilation loops, utilizing grounded anchors ($S01, S02, S04, S05, S07, S08, S10, S12, S13, S14, S15, S16$).
- **Open Awareness / Insight (`open_awareness`):** Receptive non-judgmental observation ($S01, S02, S03, S04, S08, S09, S10, S12, S13, S15, S16$).
- **Metta / Compassion (`metta_compassion`):** Benevolent self and relational compassion ($S01, S02, S03, S04, S07, S11, S12, S13, S14, S15, S16$).

---

## 4. The Progressive Settling Funnel & Dynamic Silence Math
Implemented in `SessionQueueEngine.generateGuidedSessionQueue`:

Rather than using a static silent pause between every opening segment, the runtime engine implements a Progressive Settling Funnel across Phase 1 and Phase 2, paired with a Progressive Re-Awakening Taper in Phase 5:

$$\text{Silence Window Duration } (S12) = T_{\text{total}} - D_{\text{audio}} - \sum D_{\text{pacing\_gaps}}$$

Where:
- $T_{\text{total}}$: Target duration in seconds ($60\text{s} \le T_{\text{total}} \le 5400\text{s}$).
- $D_{\text{audio}}$: Sum of exact audio durations for all selected script variants (plus $S16$ bell overlap offset of $2.5\text{s}$).
- $\sum D_{\text{pacing\_gaps}}$: Calibrated physiological inter-segment pacing gaps derived from duration tier (Quick Reset, Standard Sit, Deep Practice).

### Timing Matrix by Session Duration
| Transition Pair | Physiological Task | Quick Reset (3–5 Min) | Standard Sit (10–15 Min) | Deep Practice (20–30+ Min) |
|---|---|---|---|---|
| **Start → S01** | Phone set-down & physical arrival | User Default (5–10s) | User Default (10–20s) | User Default (15–30s) |
| **S01 → S02** | Exteroceptive room orientation | 3s | 4–5s | 5–6s |
| **S02 → S03** | Physical posture micro-adjustments | 4s | 6–8s | 8–10s |
| **S03 → S04** | 2 natural, unforced breath cycles | 6s | 10–12s | 12–15s |
| **S04 → S05 → S06** | Gravitational release & safety harbor | 6–8s | 12–15s | 15–20s |
| **S06 → S07 / S08 Loops** | Sustained focus & mind-wandering return | 10–15s | 20–35s | 40–75s |
| **S09 / S10 / S11** | State cultivation & open monitoring | Omitted or 10s | 20–30s | 35–60s |
| **S12 (Silence Window)** | Dynamic exact-timestamp budget solver | 15–30s | 60–180s | 3–12+ minutes |
| **S13 → S14 / S15** | Somatic re-awakening bridge | 4s | 8–10s | 10–12s |
| **S14 → S15** | Meaning bridge to somatic awakening | 4s | 8–10s | 10–12s |
| **S15 → Bell + S16** | Extremity movement & eye opening before bell | 4–5s | 6–8s | 8–10s |

---

## 5. Segment Pruning Engine & Test Mode Bypass
When session duration is short ($\le 300\text{s}$) or remaining open silence is constrained ($< 45\text{s}$), the engine automatically prunes lower-priority segments according to clinical priority:

### Standard Sessions ($\ge 300\text{s}$)
- **Protected Frame:** $S01, S02, S12, S13, S15, S16$ (never pruned).
- **Protected Signature Pairs:**
  - Focused Calm: `S03, S08`
  - Trauma-Informed: `S04, S05`
  - Open Awareness: `S08, S09`
  - Metta: `S04, S11`
- **Pruning Priority Order:** Dropped sequentially if silence window is constrained:
  `['S14', 'S06', 'S04', 'S03', 'S07', 'S10', 'S08']`.

### Test Mode Bypass ($< 300\text{s}$)
- $\le 120\text{s}$: Truncated to 4 essential segments (`S01`, primary signature segment, `S12`, `S16`).
- $121\text{s}$–$299\text{s}$: Preserves protected frame plus the archetype's protected signature pair.

---

## 6. Closing Sequence & Dual-Player Acoustic Overlap
To execute the $S16$ overlay cleanly:
1. Following $S15$, a $6$–$8\text{s}$ pause is scheduled allowing the practitioner to physically stretch, deepen their breath, and blink their eyes open to the room.
2. The closing singing bowl / chime strikes at $100\%$ target volume ($1.0$).
3. At $+2.5\text{s}$ after the initial strike (allowing the sharp metallic attack transient of the bell to pass and settle into its warm harmonic decay), the chosen $S16$ voice guidance variant triggers layered directly over the fading resonance using the secondary audio player.
4. Bell resonance duration ($14$–$18\text{s}$) naturally trails $2$–$4\text{s}$ past the last spoken word of $S16$, sealing the session container smoothly without an abrupt cutoff.

---

## 7. Edge Cases, Interruption Handling & Screen Lifecycle
- **Wakelock:** Managed by `wakelock_plus` to keep display on during practice.
- **Premature Termination:** Tapping the exit button displays a confirmation dialog that pauses session timers; confirming discards the active queue and safely resets audio players.
- **Silent Mode:** When "Silent" practice mode is toggled, voice segments are omitted and only starting and ending acoustic bells are scheduled.
- **Storage Protection:** `PreferencesService` utilizes direct native key commits to avoid app-restart data loss or schema corruptions.

---

## 8. Clinical Script Bank & Audio Durations Matrix
- Total Segments: 16
- Variants per Segment: 15
- Total Script Variants: 240
- Total Registered Audio Files: 480 MP3s (240 Kia + 240 Grace)
- Acoustic Bells: 10 selectable bells in `BellData`

---

## 9. Practice & Voice Customization Architecture
- `PracticeConfig` (`lib/models/practice_config.dart`): Allows users to duplicate existing archetypes, toggle active segment IDs, rename practices, and reorder active routines.
- `VoiceConfig` (`lib/models/voice_config.dart`): Supports selecting, auditioning, and disabling voice guidance personas with custom display names.

---

## 10. Automated Test Verification & Quality Audits
- Complete test suite: **55 passing tests** across 5 test suites.
- Static analyzer (`flutter analyze`): **0 issues found**.
- Verified zero native memory leaks and stable execution under Android 15 / 16 (API 35/36).
