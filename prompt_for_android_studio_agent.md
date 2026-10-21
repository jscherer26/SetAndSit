# Developer Handoff Prompt: Implementing the 16-Segment Clinical Meditation Taxonomy, Archetype Engine & Dynamic Scheduling in SetAndSit

## Executive Context & Scope

You are working on **SetAndSit**, a professional-grade, trauma-informed meditation and somatic regulation mobile app built with **Flutter and Dart** (supporting Android and iOS).

We are executing a structural migration: **transitioning from the initial 7-segment proof-of-concept (PoC) to the full production 16-segment clinical taxonomy (**$S1$ **through** $S16$**) and dynamic timeline scaling engine.**

### Critical Migration Directives

1. **Deprecate Legacy PoC Logic & Audio:**
   * Remove or replace the legacy 7-segment sequencer, old mock segment models, and earlier test audio files.
   * **Exception:** Retain the acoustic bell assets (`assets/audio/bells/*.ogg`).

2. **Local Production Manifest & Clean Asset Map:**
   * Consume the master manifest located at `assets/raw/session_manifest.json`.
   * Audio guidance files are organized into dedicated folders by voice persona:
     * `assets/audio/kia/` (Kia — Male voice persona)
     * `assets/audio/grace/` (Grace — Female voice persona)
   * Asset naming format: `[Voice]/[Segment]_[Variant].mp3` (e.g., `assets/audio/kia/S01_v01.mp3`, `assets/audio/grace/S13_v04.mp3`).

3. **Four Clinical Practice Archetypes:**
   * Replace any temporary practice categories with the four official clinical Archetypes:
     1. **Focused Calm**
     2. **Trauma-Informed Regulation**
     3. **Open Awareness / Insight**
     4. **Metta / Compassion**

4. **Core Value Proposition — The Exact End-Time Dynamic Engine:**
   * Meditators select a target finish time (e.g., concluding precisely at 9:42:00 AM) or a duration from 3 to 90 minutes.
   * The app dynamically selects variant scripts and calculates spoken guidance durations, inter-segment micro-pauses, and variable integration silence ($S13$).
   * **Session Conclusion Sequence ($S16$):** The closing boundary is marked by:
     $$\text{Final Bell (`bell.ogg`)} \longrightarrow 1.0\text{s Pause} \longrightarrow \text{Closing Vocal Cue (`S16_vXX.mp3`)}$$
     The end of `S16_vXX.mp3` concludes **down to the exact second** of the target finish time.

---

## 1. Clinical Taxonomy & Segment Pipeline ($S1$–$S16$)

Sessions adhere to a 5-phase somatic arc. Every segment has defined clinical rules:

| Code | Operational Segment | Default Role | Clinical Phase & Rules |
| :--- | :--- | :--- | :--- |
| **S01** | External Arrival | Fixed (Always required) | Phase 1 (Arrival & Agency): Sensory orientation to room, light, and sounds. Never demand immediate eye closure. |
| **S02** | Permission and Choice | Fixed (Always required) | Phase 1: Explicit autonomy; posture choice (sit, lie down, move), eyes open/closed. Zero authoritarian cues. |
| **S03** | Breath Orientation | Fixed / Archetype-Specific | Phase 1: Natural breath awareness without forced pacing or counts (bypassed in high-trauma configurations). |
| **S04** | Somatic Grounding | Fixed (Always required) | Phase 1: Proprioceptive contact points with chair, floor, cushion; downward gravitational support. |
| **S05** | Safety / Resource Priming | Conditional | Phase 1: Establishes a somatic refuge or safe anchor (hands, feet, neutral zone) for distress tolerance. |
| **S06** | Attentional Anchor | Fixed | Phase 2 (Attentional Anchoring): Concentrative focal selection (belly, nostrils, ambient sound). |
| **S07** | Core Method Loop | Scalable | Phase 2: Rhythmic, spacious guidance cues delivering the main practice technique. Duration driver. |
| **S08** | Wandering-and-Return | Cyclical | Phase 2: Normalizes cognitive drift; metacognitive return cue with zero performance shame. |
| **S09** | Expansion / Open Awareness | Scalable / Conditional | Phase 3 (State Cultivation): Panoramic observation of thoughts, sounds, and sensations (Vipassana/Zazen style). |
| **S10** | Affective Cultivation | Conditional | Phase 3: Benevolent intentions, loving-kindness, heart-space softening (Metta). |
| **S11** | Cognitive Inquiry | Conditional | Phase 3: De-reifying questions regarding impermanence, observer identity, and cognitive defusion. |
| **S12** | Imagery Sequence | Conditional | Phase 3: Somatic visual-spatial relaxation (warm light, body elements, Yoga Nidra/NSDR). |
| **S13** | Integration Silence | Scalable | Phase 4 (Deep Silence): Unguided silence window. **Dynamic buffer driver** ensuring exact end-time alignment. |
| **S14** | Meaning Transfer | Conditional | Phase 5 (Re-Orientation & Close): State-to-trait learning transfer; bridging stillness into daily life. |
| **S15** | External Reorientation | Fixed (Always required) | Phase 5: Extremity wiggles, gentle movement, sensory opening to light to prevent orthostatic dizziness. |
| **S16** | Bell & Closing Marker | Fixed at close | Phase 5: Closing chime (`bell.ogg`), 1s pause, then spoken closing guidance (`S16_vXX.mp3`). |

---

## 2. Practice Archetypes & Segment Sequencing

When a user selects an Archetype, the engine constructs the session pipeline by filtering and sequencing segments according to these clinical pipelines:

```text
1. Focused Calm:
   S01 -> S02 -> S03 -> S04 -> S06 -> S07 -> S08 -> S13 -> S15 -> S16
   (Focus: Attentional stability, interoceptive baseline, parasympathetic deceleration)

2. Trauma-Informed Regulation:
   S01 -> S02 -> S04 -> S05 -> S06 -> S07 -> S08 -> S13 -> S14 -> S15 -> S16
   (Focus: High agency, explicit somatic safe-harbor S05, bypasses vulnerable breath focus S03)

3. Open Awareness / Insight:
   S01 -> S02 -> S03 -> S04 -> S06 -> S09 -> S11 -> S13 -> S15 -> S16
   (Focus: Decentering, panoramic awareness, non-reactive metacognitive inquiry)

4. Metta / Compassion:
   S01 -> S02 -> S04 -> S05 -> S06 -> S10 -> S12 -> S13 -> S14 -> S15 -> S16
   (Focus: Ventral vagal activation, relational warmth, pro-social imagery, meaning transfer)
```

---

## 3. Dynamic "Exact End-Time" Scheduling & Silence Math

### Time Budget Allocation Formula

Given:
* Target end timestamp $T_{target}$ (or user-chosen total duration $T_{total}$ in seconds, where $180 \le T_{total} \le 5400$).
* Voice selection $V \in \{\text{kia}, \text{grace}\}$.
* Selected Archetype pipeline: an ordered list of segments $[S_1, S_2, \dots, S_n]$.

The engine calculates segment execution as follows:

1. **Variant Selection & Spoken Guidance Time ($T_{spoken}$):**
   * For each segment in the pipeline, select an active script variant $v$ from the 15 available options.
   * **Smart Duration Selection:** For short sessions ($T_{total} \le 300\text{s}$), filter for variants with lowest word counts to preserve silence budgets. For standard/long sessions, pick randomly among active variants.
   * Spoken guidance duration of a segment variant is denoted as $D(S_i, v)$.
   * Guidance duration for all pre-closing segments:
     $$T_{guidance} = \sum_{i \notin \{S13, S16\}} D(S_i, v)$$

2. **Closing Unit Duration ($D_{close}$):**
   * The final closing segment ($S16$) contains three sequential components:
     $$D_{close} = D(\text{bell.ogg}) + 1.0\text{s} + D(S16\_vXX.\text{mp3})$$
   * Where $D(\text{bell.ogg})$ is the exact duration of the selected bell chime asset.

3. **Total Silence & Transition Budget ($T_{rest}$):**
   $$T_{rest} = T_{total} - (T_{guidance} + D_{close})$$
   *Constraint check:* If $T_{rest} < 15\text{s}$, fall back to compact variant scripts or minimum micro-pauses.

4. **Micro-Pause vs. Deep Silence Partitioning ($S13$):**
   * Calculate per-transition micro-pause $P_{segment}$ based on $T_{total}$:
     * $T_{total} \le 300\text{s}$ (3–5 min): $P_{segment} = 3\text{–}6\text{s}$
     * $300\text{s} < T_{total} \le 900\text{s}$ (5–15 min): $P_{segment} = 8\text{–}12\text{s}$
     * $T_{total} > 900\text{s}$ ($>15$ min): $P_{segment} = 15\text{–}25\text{s}$
   * Let $N_{transitions}$ be the number of inter-segment transitions between guidance segments:
     $$P_{total} = N_{transitions} \times P_{segment}$$
   * The unguided deep integration silence duration $D(S13)$ receives the exact remainder:
     $$D(S13) = T_{rest} - P_{total}$$
   * **Protected Silence Guarantee:** $D(S13)$ must never drop below 15 seconds. If $D(S13) > 120\text{s}$ in long sessions, the engine may insert an additional $S08$ (Wandering-and-Return) grounding cue midpoint before resuming $S13$.

5. **Exact Timestamp Precision:**
   * Calculate scheduled start timestamps for each segment relative to session start:
     $$\text{Start}(S_{k+1}) = \text{Start}(S_k) + D(S_k) + P_k$$
   * The closing sequence ($S16$) triggers at:
     $$\text{Start}(S16) = T_{target} - D_{close}$$
   * Playback steps for $S16$:
     1. Play `bell.ogg` at $\text{Start}(S16)$.
     2. Wait exactly $1.0\text{s}$ after `bell.ogg` finishes.
     3. Play `S16_vXX.mp3`.
     4. Session completes cleanly at $T_{target}$.

---

## 4. Audio Playback Architecture (`just_audio` & `audio_session`)

Implement a robust, production-grade audio playback service:

1. **Audio Pipeline:**
   * Use `just_audio` to play individual audio assets from Flutter local assets (`assets/audio/kia/...`, `assets/audio/grace/...`, and `assets/audio/bells/...`).
   * Seamlessly handle silence windows ($S13$) and micro-pauses via precision drift-compensating countdown timers based on wall-clock time (`DateTime.now()`).

2. **Background Audio & Interruption Handling:**
   * Configure `audio_session` for spoken meditation:
     ```dart
     final session = await AudioSession.instance;
     await session.configure(const AudioSessionConfiguration.speech());
     ```
   * Ensure audio playback and timers continue unaffected when the device screen locks.
   * **Interruption Recovery Ladder (Phone Calls, Alarms, Audio Focus Loss):**
     1. **Pause & Track:** On interruption, immediately mute/pause audio and track elapsed interruption duration ($\Delta t_{\text{interrupted}}$).
     2. **Re-Budget Remaining Pipeline (End-Time Remains Invariable):**
        * Target end time $T_{target}$ **never shifts**.
        * Deduct $\Delta t_{\text{interrupted}}$ first from the unguided silence buffer ($S13$).
        * If $S13$ would be compressed below 15 seconds, dynamically drop non-essential Phase 3 segments (e.g., $S08$, $S11$, or $S12$).
        * **Safety Frame Protection:** Never drop arrival ($S01, S02$), grounding ($S04$), re-orientation ($S15$), or closing ($S16$).
     3. **Interruption Overrun:** If the interruption lasts through the scheduled end time $T_{target}$, abort remaining queued spoken segments, play a soft closing chime (`bell.ogg`), and present an in-app dialog: *"Your session completed at the scheduled end time."*

3. **Acoustic Bells & Cues:**
   * Ensure `AudioPlayer` instances for bells and spoken MP3 cues transition smoothly without clipping the audio tails.

---

## 5. UI & State Management Requirements

Changes to the existing UI should be minimal:

1. **Session Setup Screen:**
   * **Practice Selector:** 4 clean toggle cards for clinical archetypes (*Focused Calm*, *Trauma-Informed Regulation*, *Open Awareness / Insight*, *Metta / Compassion*).
   * **Voice Persona Selector:** Toggle between **Kia (Male)** and **Grace (Female)**.
   * **Exact End-Time Picker:** Time wheel / clock input setting the target completion timestamp.

2. **Active Practice Screen:**
   * Clean, distraction-free interface adhering to trauma-informed design principles.
   * Displays:
     * Target End Time display (e.g., *"Ending at 9:42:00 AM"*).
     * Subtle phase indicator reflecting the current arc: *Arrival & Settling*, *Attentional Anchoring*, *Core Practice*, *Deep Silence*, *Re-Orientation*.
     * Autonomy controls: Mute/Unmute, Gentle Exit (triggers safe exit / immediate soft bell), and Skip/Mute Segment.

---

## 6. Implementation Checklist for the Agent

* [ ] **Asset Configuration:** Verify in `pubspec.yaml` that `assets/raw/session_manifest.json`, `assets/audio/kia/`, `assets/audio/grace/`, and `assets/audio/bells/` are registered.
* [ ] **Data Model Parsing:** Create/update models for `SessionManifest`, `TaxonomySegment`, `ScriptVariant`, and `ArchetypeConfig`. Parse `session_manifest.json` on app startup.
* [ ] **Dynamic Scheduler Engine:** Build `SessionTimelineEngine` implementing the exact end-time duration, variant word-count filtering, and $S13$ silence budget math outlined in Section 3.
* [ ] **Playback Controller:** Refactor the playback manager using `just_audio` and `audio_session` to queue individual variant MP3s, timed silence intervals, and the $S16$ closing sequence (`bell.ogg` $\rightarrow$ 1s pause $\rightarrow$ `S16_vXX.mp3`).
* [ ] **Interruption Handler:** Implement the recovery ladder in Section 4.2 to handle phone calls and audio ducking without shifting $T_{target}$.
* [ ] **UI Integration:** Wire up the 4 Archetypes, Voice toggle (Kia vs. Grace), and Exact End-Time picker to initialize and run the session.
* [ ] **Clean Legacy Code:** Delete deprecated 7-segment PoC classes and unused mock audio references.