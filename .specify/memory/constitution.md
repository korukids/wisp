<!--
  Sync Impact Report
  ==================================================
  Version change: 1.0.0 → 2.0.0
  Bump rationale: MAJOR — Principle I redefined from
    "Privacy-First Local Processing" to "User-Controlled
    Processing", allowing cloud transcription when user
    explicitly configures an API key. ML Runtime constraint
    updated to reflect cloud-first backend. "No cloud sync"
    removed from Principle V.

  Modified principles:
    - I: Privacy-First Local Processing → User-Controlled Processing
    - V: Removed "no cloud sync" clause
  Modified constraints:
    - ML Runtime: local-only → cloud API primary, local optional

  Removed sections: None
  Added sections: None

  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ no updates needed
    - .specify/templates/spec-template.md ✅ no updates needed
    - .specify/templates/tasks-template.md ✅ no updates needed

  Follow-up TODOs: None
  ==================================================
-->

# Wisp Constitution

## Core Principles

### I. User-Controlled Processing

Audio transcription MAY use cloud-based speech-to-text services
when the user has explicitly configured an API key for that
service. The user's choice of transcription backend (local or
cloud) MUST be respected. No audio data or transcription results
are sent to any service without explicit user configuration.
No usage telemetry leaves the user's machine under any
circumstances.

**Rationale**: Wisp handles raw microphone input — sensitive
user data. The user must remain in full control of where their
audio is processed, but cloud transcription offers significantly
lower latency that justifies the tradeoff when the user opts in.

### II. Type Safety & Correctness

All code MUST use Swift's type system to eliminate runtime errors
at compile time. Force-unwraps (`!`) are prohibited outside of
IBOutlet declarations and test assertions. Optional chaining,
`guard let`, and `Result` types MUST be preferred over implicit
unwrapping. All public API boundaries MUST have explicit types
(no inferred return types on public functions).

**Rationale**: A background app that crashes silently is worse
than one that never launches — the user won't notice until they
need it. Compile-time safety prevents this.

### III. Test-First Development

Tests MUST be written before implementation (red-green-refactor).
Every user-facing behavior MUST have at least one XCTest covering
the happy path and one covering the primary failure mode. Audio
pipeline components MUST have unit tests using mock audio buffers.
Integration tests MUST verify the full record-transcribe pipeline
using fixture audio files.

**Rationale**: A dictation app has a tight feedback loop — bugs
in transcription or activation are immediately visible to users.
TDD ensures regressions are caught before they ship.

### IV. Performance-Conscious Design

Audio capture MUST operate on a dedicated high-priority thread
with zero allocations in the hot path. Transcription latency
MUST remain under 2x real-time on Apple Silicon (M1 baseline).
The app MUST consume less than 50 MB of resident memory when
idle (not recording). UI updates from transcription results
MUST be dispatched to the main thread without blocking audio
capture.

**Rationale**: As a background utility, Wisp competes for
resources with the user's primary applications. Excessive CPU
or memory usage undermines the "invisible helper" experience.

### V. Simplicity & YAGNI

Features MUST NOT be added speculatively. Each component MUST
have a single, clear responsibility. Abstractions are permitted
only when they eliminate duplication across three or more call
sites. Configuration options MUST be limited to what users
actually need (hotkey, microphone selection, model choice).
No plugin systems, no scripting APIs.

**Rationale**: Wisp is a focused utility, not a platform.
Complexity in a background app means more surface area for
bugs that go unnoticed.

## Platform & Technology Constraints

- **Language**: Swift 6.1+ with strict concurrency checking enabled
- **Platform**: macOS 26+, Apple Silicon and Intel
- **UI Framework**: AppKit for menu bar integration; SwiftUI
  permitted for settings/preferences panels only
- **Audio**: AVFoundation for capture; no third-party audio libs
  unless AVFoundation proves insufficient (document justification)
- **ML Runtime**: Cloud speech-to-text API (ElevenLabs) as
  primary transcription backend; local models permitted as
  alternative when configured
- **Text Cleanup**: Apple Foundation Models (on-device LLM) for
  filler word removal and formatting; falls back to raw Whisper
  output if unavailable
- **App Lifecycle**: LSUIElement (background-only); MUST NOT
  appear in Dock or Cmd+Tab switcher
- **Global Hotkey**: Default Option+Space, user-configurable;
  registered via CGEvent tap or equivalent system API
- **Distribution**: Notarized .dmg or Homebrew cask; no App Store
  dependency for initial release

## Development Workflow

- **Branching**: Feature branches off `main`; squash-merge on
  completion
- **Testing gate**: All tests MUST pass before merge. No
  `@available` or `#if DEBUG` test skips in CI
- **Code review**: All changes require at least one review pass
  (human or AI-assisted) verifying constitution compliance
- **Commit discipline**: Each commit MUST compile and pass tests.
  Work-in-progress commits MUST be squashed before merge

## Governance

This constitution is the highest-authority document for Wisp
development decisions. When a proposal conflicts with these
principles, the constitution wins unless formally amended.

**Amendment procedure**:

1. Propose the change with rationale in a dedicated PR
2. Update this file with the new or modified principle
3. Increment the version per semantic versioning rules below
4. Update `LAST_AMENDED_DATE`
5. Verify no dependent templates are invalidated

**Versioning policy**:

- MAJOR: Principle removed, redefined, or made incompatible
  with prior guidance
- MINOR: New principle added or existing guidance materially
  expanded
- PATCH: Wording clarifications, typo fixes, non-semantic
  refinements

**Compliance review**: Every spec and plan MUST include a
Constitution Check section verifying alignment with these
principles before implementation begins.

**Version**: 2.0.0 | **Ratified**: 2026-03-28 | **Last Amended**: 2026-04-10
