# Developer Action Prompt: Generate Comprehensive Architecture & Runtime Snapshot (.md)

## Objective
Generate a complete, up-to-date architecture and technical specification document in markdown named `ARCHITECTURE_RUNTIME_SNAPSHOT.md` at the root of the project.

This snapshot will be handed off to an external clinical review and somatic flow audit agent to evaluate session pacing, acoustic flow, script transitions, and humanization. It must reflect the exact current implementation in Dart/Flutter, not aspirational designs.

---

## Instructions for the Agent

Please inspect the current codebase and compile `ARCHITECTURE_RUNTIME_SNAPSHOT.md` covering the following structured sections:

### 1. High-Level Engine Overview
* Current app structure and state management pattern (e.g., Riverpod, Provider, Bloc, or ChangeNotifier).
* Master asset locations: where `session_manifest.json`, audio files (`assets/audio/kia/`, `assets/audio/grace/`), and bell files (`assets/audio/bells/`) are stored and loaded from.
* Audio player lifecycle implementation (`just_audio`, `audio_session`) and background playback configuration.

### 2. Clinical Archetypes & Active Pipelines
* List the 4 clinical Archetypes currently wired into the UI and engine:
  * *Focused Calm*
  * *Trauma-Informed Regulation*
  * *Open Awareness / Insight*
  * *Metta / Compassion*
* Document the exact ordered segment sequences (e.g., $S01 \rightarrow S02 \dots$) currently executed for each archetype.
* Document any segment-skipping logic, conditional triggers, or trauma-safe safeguards currently in place.

### 3. Dynamic "Exact End-Time" Math & Timeline Calculation
Detail the exact formulas currently implemented in `SessionTimelineEngine` (or equivalent service):
* How total session duration ($T_{total}$) is resolved from user input (target finish time vs. duration slider).
* The post-tap settling buffer duration ($P_{settle}$, e.g., 4.0s) and when it fires.
* Spoken guidance calculation ($T_{guidance}$) and how script variants are selected (randomized vs. word-count filtering for short sessions).
* The closing boundary sequence ($S16$): exact duration formula ($D_{close}$), the delay between the bell (`bell.ogg`) and vocal guidance (`S16_vXX.mp3`), and how the final second is guaranteed.
* Transition micro-pauses ($P_{segment}$): current rules, lookup tables, or formulas used across different duration brackets ($<5\text{m}$, $5\text{–}15\text{m}$, $>15\text{m}$).
* Integration silence ($S13$): how the remaining dynamic buffer ($D(S13)$) is derived and what minimum floor (e.g., 15s) is enforced.

### 4. Edge Cases & Interruption Recovery
* How phone calls, alarm interruptions, and audio focus losses are currently detected and recovered.
* How elapsed interruption time ($\Delta t_{interrupted}$) is absorbed (e.g., deducted from $S13$, dropping Phase 3 cues, etc.) without shifting the target completion timestamp.
* Behavior when an interruption outlasts the target end time.

### 5. Script Variant Bank Summary
* Number of active segments and variants registered in the app.
* A summary table or schema breakdown showing how variant metadata (text, word count, file path, audio duration) is structured and parsed from `session_manifest.json`.

---

## Deliverable Format
* Create and save the file directly to `/ARCHITECTURE_RUNTIME_SNAPSHOT.md`.
* Ensure all code snippets or mathematical formulas in the markdown accurately match the live Dart code.