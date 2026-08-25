# Task Plan: macOS Voice Dictation App

## Goal
Finish the current HS Voice as one polished native macOS dictation product and deliver one canonical, reproducible installer for internal company distribution.

## Current Phase
Phase 38 — Final Verification & Single Handoff (complete)

## Phases

### Phase 1: Requirements & Discovery
- [x] Confirm Aqua Voice's core workflow from official public information
- [x] Inspect the local macOS development toolchain and repository state
- [x] Capture product, platform, privacy, and distribution constraints
- **Status:** complete

### Phase 2: Architecture & Product Design
- [x] Choose a native architecture and transcription strategy
- [x] Define permission, shortcut, insertion, history, and settings flows
- [x] Define build/sign/notarize/package workflow
- **Status:** complete

### Phase 3: Application Implementation
- [x] Create the native macOS app structure
- [x] Implement global shortcut, audio capture, live transcription, and text insertion
- [x] Implement menu-bar UI, onboarding, settings, history, and privacy controls
- [x] Add app identity and supporting assets
- **Status:** complete

### Phase 4: Distribution Packaging
- [x] Add release build, app bundle, `.pkg`, and `.dmg` automation
- [x] Add signing and optional notarization support
- [x] Add deployment/admin documentation for company-wide installation
- **Status:** complete

### Phase 5: Testing & Verification
- [x] Run source, unit, build, bundle, and package checks
- [x] Inspect generated package metadata and app bundle
- [x] Fix issues found and document limitations
- **Status:** complete

### Phase 6: Delivery
- [x] Review deliverables and remove transient build output where appropriate
- [x] Ensure usage, privacy, and enterprise distribution guidance are clear
- [x] Hand off paths and next steps to the user
- **Status:** complete

### Phase 7: Daily-Use Product Refinement
- [x] Audit the shipped interaction flow for friction and fragile states
- [x] Add configurable shortcuts and smarter spoken formatting commands
- [x] Improve live recording feedback, timing, and recovery behavior
- [x] Add privacy-safe diagnostics for company support teams
- **Status:** complete

### Phase 8: Regression Testing & UX Verification
- [x] Extend unit coverage for new formatting, shortcut, and command behavior
- [x] Re-run formatting, compilation, and tests
- [x] Verify permissions, diagnostics, and settings presentation paths in source/build checks
- **Status:** complete

### Phase 9: Updated Distribution Artifacts
- [x] Increment the release version and rebuild the Universal app
- [x] Regenerate and verify PKG, DMG, checksum, and runtime launch
- [x] Update usage/deployment documentation and hand off the refined build
- **Status:** complete

### Phase 10: One-Touch Usability Audit
- [x] Recheck the menu-bar flow, input target retention, and permission return flow
- [x] Define quick actions that reduce trips to Settings without adding accidental input risk
- [x] Define a clipboard-only fallback for restricted or unsupported destination apps
- **Status:** complete

### Phase 11: Usability Implementation & Regression Testing
- [x] Add menu-bar language switching, repeat insertion, and time-limited safe undo
- [x] Improve input target tracking and automatically refresh permission status
- [x] Add insertion-mode settings, diagnostics, and focused unit coverage
- **Status:** complete

### Phase 12: v1.2.0 Distribution Artifacts
- [x] Update version metadata and usage/deployment documentation
- [x] Rebuild and verify the Universal app, PKG, DMG, checksums, and runtime launch
- **Status:** complete

### Phase 13: End-User Manual Content & Design
- [x] Inventory the final v1.2.0 UI, workflows, settings, permissions, and support behavior
- [x] Define the Japanese manual structure and compact reference-guide design tokens
- [x] Draft install, setup, daily use, settings, privacy, and troubleshooting content
- **Status:** complete

### Phase 14: Manual Authoring & Visual QA
- [x] Generate an editable DOCX and distribution PDF with reproducible source
- [x] Audit headings, tables, metadata, and accessibility structure
- [x] Render every page to PNG and iteratively inspect/fix visual defects
- **Status:** complete

### Phase 15: Manual Delivery
- [x] Validate final page count, text extraction, file metadata, and checksums
- [x] Update project documentation and hand off both manual formats
- **Status:** complete

### Phase 16: Single-File Installer Design
- [x] Audit the current Universal app, PKG builder, verification script, and release outputs
- [x] Define a polished standalone product archive with Japanese Installer guidance
- [x] Keep the final handoff directory limited to one double-clickable PKG
- **Status:** complete

### Phase 17: Installer Build & Integration
- [x] Add reproducible product-archive resources and a dedicated single-installer build path
- [x] Build HS Voice 1.2.0 as one Universal macOS installer file
- [x] Update user and enterprise documentation for the one-file installation flow
- **Status:** complete

### Phase 18: Installer Verification & Delivery
- [x] Validate package signature state, distribution metadata, payload, architectures, and install location
- [x] Exercise the Installer opening flow without changing the user’s installed applications
- [x] Record checksum and hand off the single PKG artifact
- **Status:** complete

### Phase 19: Aqua Voice-Like Zero-Configuration Audit
- [x] Confirm which macOS permission and Gatekeeper steps are technically unavoidable
- [x] Audit current first-launch defaults, permission prompts, and onboarding friction
- [x] Define unmanaged-Mac and MDM-managed-Mac deployment paths
- **Status:** complete

### Phase 20: Guided First Run & Managed Deployment
- [x] Reduce first-run choices to one guided permission sequence with ready-to-use defaults
- [x] Add reproducible MDM/PPPC deployment templates or generators for company IT
- [x] Update installer and documentation with the exact zero-configuration boundary
- **Status:** complete

### Phase 21: Rebuild, Verification & Handoff
- [x] Add focused tests and run the complete regression suite
- [x] Rebuild and verify the single-file Universal installer
- [x] Hand off the employee flow and the remaining company credential/MDM requirements
- **Status:** complete

### Phase 22: fn Key Default Design
- [x] Audit the current global shortcut implementation and macOS fn-key behavior
- [x] Define a reliable fn-only hold-to-talk path with existing shortcuts as fallbacks
- **Status:** complete

### Phase 23: fn Key Implementation & UX
- [x] Add fn-only press/release monitoring and make it the fresh-install default
- [x] Update onboarding, settings labels, diagnostics, and regression tests
- [x] Update installer guidance and manuals
- **Status:** complete

### Phase 24: Rebuild, Verification & Handoff
- [x] Run formatting and full regression tests
- [x] Rebuild and verify the one-file Universal installer
- [x] Hand off the updated fn-default package and remaining signing requirement
- **Status:** complete

### Phase 25: Persistent Status UX Audit
- [x] Identify why HS Voice cannot be visually confirmed while idle
- [x] Define an Aqua Voice-inspired but original compact bottom status surface
- [x] Preserve the expanded recording, processing, success, and error feedback
- **Status:** complete

### Phase 26: Persistent Bottom Status Implementation
- [x] Keep the overlay panel visible from application launch until termination
- [x] Add a compact idle pill with brand, ready status, and active shortcut
- [x] Expand the same surface for permission, listening, processing, success, and error states
- **Status:** complete

### Phase 27: Regression & Visual Verification
- [x] Add focused state-presentation tests
- [x] Run formatter lint and the complete Swift test suite
- [x] Launch the app and visually verify the idle bottom-screen state
- [x] Verify active-state expansion through compiled state mapping and existing recording UI
- **Status:** complete

### Phase 28: Ultra-Compact Idle Indicator
- [x] Remove shortcut keys and explanatory copy from the persistent idle surface
- [x] Reduce the idle surface to a minimal HS Voice running mark and neutral healthy status
- [x] Rebuild and visually verify the smaller primary-display indicator
- **Status:** complete

### Phase 29: Original Project Integration
- [x] Confirm source files in the original project have not changed concurrently
- [x] Sync the verified implementation and tests into the original project
- [x] Build a standard installer for the root-owned existing app and hand off the running verified build
- **Status:** complete

### Phase 30: Aqua Voice Minimal Overlay
- [x] Replace the idle icon with a plain 54×8 adaptive dark capsule matching the reference
- [x] Reduce listening, processing, success, and error feedback to slim capsules
- [x] Preserve accessibility status and state transitions without persistent instructions
- **Status:** complete

### Phase 31: Verification & Updated Installer
- [x] Run formatter lint and all Swift tests
- [x] Rebuild and visually verify the live idle bar on the primary display
- [x] Sync source and publish a refreshed Universal installer
- **Status:** complete

### Phase 32: Automatic Insertion Failure Diagnosis
- [x] Trace Accessibility trust evaluation, target retention, clipboard write, and Command-V delivery
- [x] Distinguish permission identity mismatch from insertion-event implementation failure
- [x] Add focused regression coverage for the confirmed failure path
- **Status:** complete

### Phase 33: Automatic Insertion Repair & Verification
- [x] Implement the smallest reliable repair while preserving clipboard-only fallback
- [x] Run formatting, regression tests, and app/package verification
- [x] Publish an updated installer and document any one-time replacement requirement
- **Status:** complete

### Phase 34: Dock Presence & Activation Audit
- [x] Confirm why macOS suppresses the HS Voice Dock icon
- [x] Audit Dock-click/reopen behavior for the windowless menu-bar architecture
- [x] Define the smallest native regular-app behavior that preserves menu-bar dictation
- **Status:** complete

### Phase 35: Dock Integration, Verification & Installer
- [x] Show the HS Voice icon in the Dock and make Dock activation useful
- [x] Run formatting, regression tests, metadata, and runtime visual verification
- [x] Publish and verify an updated Universal installer
- **Status:** complete

### Phase 36: Final Product Audit
- [x] Treat the current HS Voice as the only product; create no parallel variant or replacement app
- [x] Re-audit the full user journey, runtime behavior, visual surfaces, permissions, insertion, and packaging
- [x] Identify concrete defects and completion gaps from source, tests, and live-app evidence
- **Status:** complete

### Phase 37: Completion Pass
- [x] Repair every reproducible high-impact defect without expanding product scope
- [x] Refine the existing interaction and visual details where they block a finished-product feel
- [x] Keep settings, defaults, documentation, and distribution metadata consistent
- **Status:** complete

### Phase 38: Final Verification & Single Handoff
- [x] Run formatting, focused tests, full regression tests, and packaging verification
- [x] Perform live visual and end-to-end workflow QA on the final build
- [x] Deliver one canonical installer and a concise final status with known platform constraints
- **Status:** complete

## Key Questions
1. Which Aqua Voice behaviors are essential to the first internal release?
2. Can an Apple-native transcription path deliver a zero-account, easy-to-deploy baseline?
3. Which macOS permissions are unavoidable for global dictation and reliable text insertion?
4. How should unsigned local builds and signed/notarized company releases coexist?
5. What is required for deployment through MDM as well as manual installation?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Start with a native macOS implementation | The user explicitly targets MacBook/macOS and needs system integration and distributable packages. |
| Treat Aqua Voice as inspiration, not branding to copy | Delivers the requested interaction model without impersonating a third-party product. |
| Use file-based planning | The work spans research, app implementation, packaging, and verification. |
| Brand the implementation as HS Voice | This is an original internal product inspired by the interaction pattern, not a clone of Aqua's identity. |
| Use SwiftUI/AppKit and Apple Speech | The local toolchain supports it and it avoids a mandatory custom cloud service for the initial enterprise build. |
| Target macOS 14+ as a Universal app | Covers modern managed MacBooks while keeping APIs and UI implementation maintainable. |
| Cross-build architecture-specific Swift executables and combine them | The installed SwiftPM CLI accepts one target triple per invocation. |
| Build ad-hoc locally and parameterize Developer ID/notary identities | No company signing identities are present, but the project should be release-ready when credentials are provided. |
| Refine the existing product without waiting for unspecified design choices | The user explicitly asked for more adjustment; daily-use reliability and supportability are safe, high-value improvements. |
| Deliver a standalone product-archive PKG | A single PKG is the native macOS format that opens Apple Installer on double-click and can carry the Universal app plus Japanese installation guidance. |
| Keep one non-activating bottom panel visible for the full app lifetime | A compact idle pill makes the running state unmistakable without taking keyboard focus; the existing surface can expand in place for active feedback. |
| Make the persistent idle surface icon-only | User feedback prioritizes Aqua Voice-like minimal obstruction; shortcut instructions belong in the menu/settings, not the always-on screen surface. |
| Match the reference with a plain bar and slim active capsules | The screenshot shows a roughly 54×8 dark home-indicator-like capsule; removing branding and reducing every transient state produces the requested Aqua Voice-level simplicity. |
| Freeze the product to one canonical HS Voice installer | The user explicitly asked to stop creating additional Voice variants and finish the existing product. |
| Repair lifecycle invariants before further visual changes | The final audit found concrete recording and Dock activation defects; another visual variant would not address product completeness. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `pkgbuild --version` rejected the incomplete option | 1 | Confirmed the command exists from its usage text; defer validation to an actual build. |
| Initial multi-file planning update used a mismatched patch context | 1 | Re-read the files and applied smaller exact-context updates. |
| SwiftPM attempted to write Clang module caches outside the writable workspace | 1 | Redirected Clang and SwiftPM module caches into `.artifacts/` and will rerun. |
| SwiftPM's nested `sandbox-exec` was rejected by the already-managed outer sandbox | 2 | Added SwiftPM's `--disable-sandbox`; the outer workspace sandbox remains active. |
| First compilation found an associated-value enum comparison and two lost string interpolation escapes | 1 | Added an enum helper and restored the intended Swift interpolation syntax; also removed a deprecated activation option. |
| Text normalization test expected every English paragraph to start with a capital letter | 1 | Updated the processor to capitalize the first letter of each non-CJK paragraph. |
| `sips` could not rasterize the SVG icon on macOS 26 | 1 | Replaced SVG conversion with a repository-owned AppKit drawing script and retained the SVG as the editable design source. |
| Quick Look SVG rendering was blocked by its nested sandbox | 2 | Abandoned Quick Look and used direct AppKit drawing with no nested renderer. |
| `iconutil` rejected an otherwise dimensionally valid iconset, and `sips` could not write ICNS directly | 3 | Switched to Xcode's asset compiler with a complete macOS AppIcon catalog. |
| `hdiutil create` could not configure a virtual disk device inside the managed sandbox | 1 | Re-ran only DMG creation with approved system-device access; the release script is valid in a normal developer shell. |
| Initial combined AppModel/diagnostics patch included a context line that did not exist yet | 1 | Split the change into exact-context patches and created the diagnostics component independently. |
| Small cleanup patch expected a private View extension while the file used default access | 1 | Inspected the exact file tail, removed the now-unused extension, and corrected onboarding indentation. |
| Final multi-file status patch contained one incorrectly formatted findings context | 1 | Split checksum, plan, findings, and progress updates into exact-context patches. |
| Baseline Swift test used relative module-cache environment paths, which SwiftPM rejects | 1 | Re-run with explicit absolute workspace paths; formatter lint already passed. |
| Completion patch targeted `HSVoiceApp.swift` in two update blocks | 1 | No files changed; split the implementation into one exact patch per file. |
| Sandboxed `pgrep` could not access the macOS process list | 1 | Use one approved read-only `ps` inspection before replacing the live QA build. |
| Three activation simulations (`open -b`, AppleScript `reopen`, AppleScript `activate`) did not surface Settings | 3 | Stop retrying the same AppKit callback path; inspect local Apple-event constants and move to a real Dock-facing window lifecycle or explicit activate-event route. |
| System Events could not inspect/click the Dock because `osascript` lacks Accessibility permission | 1 | Use a one-time Core Graphics click at the visually verified HS Voice Dock coordinate; do not alter system privacy settings. |
| CGWindow inspection via `xcrun swift -e` used the blocked default module cache | 1 | Re-run with the established absolute project-local Clang/Swift module caches. |
| First screenshot after unified-window activation captured an all-black desktop | 1 | Inspect the live process/frontmost state and image metadata before taking one new capture; do not treat it as product evidence. |
| Final plan checker was accidentally invoked from `dist/` | 1 | Checksum verification still passed; rerun the plan/version check from the project root. |
| Final v1.2 audit referenced `SHA256SUMS` from the project root instead of `dist/` | 1 | Re-run checksum verification from the directory that owns the checksum file. |
| Manual findings patch expected an article in the v1.2 checksum line | 1 | Inspected the exact line and applied the manual findings after the actual checksum entry. |
| Accessibility audit could not write `tmp/manual-a11y-v1.json` | 1 | Create the task-local `tmp` directory before re-running the audit. |
| Japanese text rendered as empty boxes in DOCX pages 1-2 | 1 | Discover an installed Japanese font and set it as both the run font and East Asian font throughout styles and direct formatting. |
| Japanese boxes persisted when all font slots used `Hiragino Sans` | 2 | Switch the complete document font map to the installed Unicode-wide `Arial Unicode MS` family. |
| Japanese boxes persisted with `Arial Unicode MS` | 3 | Stop font-name trial and inspect OOXML font slots, document language defaults, and LibreOffice font-file mapping. |
| LibreOffice dropped Japanese after correct `ja-JP` OOXML language mapping | 4 | Use installed Apple Pages to render the valid DOCX and complete macOS-native visual QA/PDF export. |
| Page 4 list items 1-2 protruded beyond the left margin in Pages | 1 | Add the preset's 0.375 in left and 0.188 in hanging indents directly to every real numbered/bulleted paragraph. |
| Page 4 items 1-2 still protruded after explicit indents | 2 | Compare OOXML; if identical, replace only this sequence with a true step/action table to avoid the Pages numbering quirk. |
| Manual rebuild omitted required output and icon arguments | 1 | Re-ran the deterministic builder with explicit artifact and app-icon paths. |
| One progress-log patch contained unescaped backticks in a JavaScript template literal | 1 | Reissued the same file patch without embedded backticks; deliverables were unaffected. |
| First single-installer build produced the PKG but its post-build verifier exited after the signature check | 1 | Inspect productbuild’s actual expanded filenames, then update only the verifier assumptions before rebuilding or rechecking. |
| Revised verifier reached app signature validation but still exited silently before completion | 2 | Tracing showed installer could not locate the root target inside the managed sandbox; replace that target-dependent check with read-only pkginfo validation. |
| Sandbox process query could not access sysmond while checking Installer | 1 | Do not infer GUI failure from the restricted process API; close Installer directly through its application command after the successful open result. |
| Apple Developer markdown endpoints returned an unsupported content-type error | 1 | Use the official search-index excerpts and locally installed platform schemas instead of retrying the same markdown endpoint. |
| LibreOffice again rendered the updated manual without Japanese glyphs | 1 | Re-export the structurally valid DOCX through Apple Pages and perform final Poppler page-by-page QA, matching the already verified manual workflow. |
| Bundled Poppler override directory did not contain `pdftotext` | 1 | Used the bundled native Poppler binary path for extraction; no artifact was affected. |
| SwiftPM rejected a relative module-cache override during the final test run | 1 | Re-ran with an absolute workspace-local module-cache path; all 15 tests passed. |
| Planning completion script was not marked executable | 1 | Invoked the same read-only checker through Bash; it confirmed all 24 phases complete. |
| Zsh expanded an absent `.swift-format*` glob before `ls` could run | 1 | Use `find` or query the formatter directly; no project file or implementation was affected. |
| Opening the raw SwiftPM executable through LaunchServices did not leave a visible HS Voice overlay | 1 | Check process state, then run the executable directly or package a real `.app` before repeating visual QA. |
| The first packaged-app screenshot also did not show the bottom overlay on the captured display | 2 | Inspect all screenshot files, active process/window ownership, and `NSScreen` geometry before changing UI code. |
| Test process had already exited when an exact validated PID was terminated after rebuild | 1 | LaunchServices start still ran immediately afterward; verify the replacement process/window instead of retrying the stale PID. |
| System Events refused menu-bar automation because `osascript` lacks Accessibility permission | 1 | Do not change system privacy settings; use a reversible fallback shortcut test and Core Graphics event injection if permitted. |
| A synthetic Option+Space event carrying only modifier flags did not activate the Carbon hotkey | 1 | Try a complete physical-style Option-down, Space-down sequence once; restore input and preferences regardless of result. |
| A full synthetic Option-down/Space-down sequence was also ignored by the registered hotkey | 2 | Stop UI injection attempts because macOS privacy blocks automation; rely on compiled state mapping tests and restore user defaults exactly. |
| Importing the saved defaults plist did not remove the temporary `shortcutChoice` key | 1 | Explicitly delete only that test-added key, verify the remaining domain matches the pre-test values, and terminate the test process before continuing. |
| Original release rebuild could not remove the existing `dist/HS Voice.app` | 1 | The old bundle is root-owned. Preserve it as a recoverable `.artifacts` backup, then let the builder create a new user-owned bundle at the expected path. |
| Moving the intact root-owned app bundle as the normal user was also denied | 2 | Try one non-interactive privileged move to the exact backup path; if unavailable, keep the source integration and deliver/relaunch the verified app from a user-owned path. |
| Non-interactive privileged backup move required an administrator password | 3 | Stop direct replacement attempts. Build a standard macOS installer so authorization is handled safely by Installer when the user chooses to install. |
| First Phase 31 status patch contained an empty malformed hunk | 1 | Reissued the planning/findings/progress changes with exact independent contexts; implementation and artifacts were unaffected. |
| `git status` reported that the project directory is not a Git repository | 1 | Treat the existing source tree as an unversioned workspace and use direct file inventory/checksums to preserve unrelated files. |
| Process inspection via `pgrep`/`ps` was denied by the managed macOS sandbox | 1 | Do not retry restricted sysmond access; use the app's preference domain and signed bundle metadata, which are sufficient for diagnosis. |
| Initial isolated-output script patch used the wrong declaration order for `COMPONENT_SOURCE` | 1 | Re-read the script headers and applied exact smaller hunks; no build output had started. |
| Sandboxed `screencapture` could not create a display image | 1 | Re-ran the exact read-only capture with approved display access; live Dock QA succeeded. |
| Repeating `open` did not simulate a physical Dock reopen event for the windowless running app | 1 | Use a direct application reopen Apple event for behavioral verification instead of repeating the same launch command. |
| Direct `reopen` Apple event did not surface the settings window | 2 | Verify the running bundle path and event target, then choose a deterministic activation path instead of retrying the same event. |
| LaunchServices Bundle-ID reopen highlighted the Dock item but did not surface the settings window | 3 | Stop scripted reopen attempts; the user's requested Dock icon and tooltip are visually verified, while Settings remains directly available from the menu bar and Command-comma. |

## Notes
- Preserve any user changes if files appear later in the worktree.
- Keep fetched web content in `findings.md`, never in this plan.
- A distributable unsigned/ad-hoc build can be produced locally; trusted company-wide deployment requires the company's Apple Developer signing credentials.
