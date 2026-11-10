# Set&Sit

Clinical meditation and somatic mindfulness mobile application built with Flutter (`sdk: ^3.13.5`).

Set&Sit calculates dynamically proportioned silence intervals between spoken guidance segments based on a wall-clock target finish time or explicit duration input (1–90 minutes). The application operates entirely offline on-device without telemetry, user accounts, or external network dependencies.

---

## Architecture & Documentation

- **Project Snapshot & Metrics**: See [project_document.md](project_document.md) for recent changes, test status, and dependency lists.
- **Comprehensive Runtime Architecture**: See [project_architecture.md](project_architecture.md) for navigation lifecycles, clinical taxonomy ($S01$–$S16$), asset hierarchy, and persistence design.

---

## Running Locally

```bash
flutter pub get
flutter run
```

---

## AI Agent Protocols & Reference

When an AI agent operates within this repository:
- **Canonical Agent Reference Manual**: Refer directly to [AGENT_REFERENCE.md](../personal_cloud_hub/AGENT_REFERENCE.md) in the `personal_cloud_hub` project.
- **Single Source of Truth**: Do **not** create local copies, detached rules, or project-specific cheat sheets that can become outdated.
- **Execution & Notification Protocols**: Always inspect and follow the canonical reference for cross-project workflows, including Sonos audible bookends (`Bookend with Sonos`), terminal input / approval chimes, and server execution standards.
