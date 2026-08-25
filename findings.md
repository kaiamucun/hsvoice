# Findings & Decisions

## Requirements
- Create an application with an interaction model similar to Aqua Voice.
- Target company-wide internal distribution.
- Support MacBook hardware and macOS as the primary platform.
- Provide installation/distribution packages, not only source code.
- Make reasonable product decisions without blocking on unspecified branding or enterprise credentials.
- Refine the completed application further without a narrower user-specified target; prioritize changes that benefit broad company deployment and daily dictation use.
- Provide an end-user usage manual suitable for company-wide distribution in editable Word and ready-to-share PDF formats.
- Consolidate the current macOS release into one double-clickable installer file that launches Apple Installer and installs HS Voice into Applications.
- Make deployment feel like Aqua Voice: after installation, employees should not need to choose app-specific settings and should complete only the macOS permission steps that cannot be bypassed.

## Research Findings
- The repository was empty at the start of the task.
- Aqua Voice's official macOS page describes the core flow as holding a key, speaking, releasing, and receiving cleaned text in the previously focused app.
- Its highlighted features include live transcription/refinement, automatic punctuation/formatting, custom dictionary terms, history, multiple languages, background/menu-bar operation, and text insertion across apps.
- Aqua's own product uses cloud processing and requires microphone plus Accessibility permissions on macOS; the requested internal app can reduce data exposure by using Apple's native speech stack and keeping app-owned history local.
- Aqua currently distributes native builds for both Apple Silicon and Intel Macs, which sets a useful compatibility target for this project.
- Local host: Apple Silicon (`arm64`), macOS 26.5, Xcode 26.6, Swift 6.3.3. Native packaging tools are installed.
- Apple's current documentation confirms `SFSpeechRecognizer` supports streaming audio requests, per-locale recognizers, service-availability checks, and an explicit `supportsOnDeviceRecognition` capability check. Some languages require Internet connectivity.
- Apple's direct-distribution guidance requires Developer ID Application signing, hardened runtime, secure timestamps, notarization, and ticket stapling for a trusted external/enterprise release. Installer packages use a separate Developer ID Installer certificate.
- No Developer ID Application or Installer identities are installed in this workspace's keychain, so the local artifact must use ad-hoc app signing and an unsigned installer; the release automation will accept company identities when supplied.
- Current SwiftPM CLI accepts one target triple at a time. A Universal app can be produced deterministically by cross-building `arm64-apple-macosx14.0` and `x86_64-apple-macosx14.0`, then combining the executables with `lipo`.
- Final app bundle metadata: bundle ID `com.hsvoice.desktop`, version `1.0.0`, minimum macOS `14.0`; the executable contains both `arm64` and `x86_64` slices.
- Final local artifacts: 547 KB unsigned installer PKG and 856 KB DMG containing the ad-hoc signed app. The app itself passed strict deep code-signature verification.
- The packaged executable links only Apple/macOS system frameworks and Swift runtime libraries; no external SDK or analytics binary is present.
- LaunchServices successfully launched the packaged app and the HS Voice process remained running until the verification process intentionally terminated it.
- Refinement audit: the global shortcut is hard-coded to Option+Space in registration, menu, overlay, and settings, so conflicts cannot be resolved without rebuilding.
- Refinement audit: the post-stop fallback waits 2.2 seconds, which is perceptibly long for short dictation when Apple does not emit a final result quickly.
- Refinement audit: the UI has no recording duration or maximum-duration safeguard, making a forgotten toggle-mode recording difficult to notice or recover from.
- Refinement audit: version text is hard-coded in settings instead of reading the final packaged bundle metadata.
- Refinement audit: support teams have no privacy-safe way to collect OS, architecture, locale, permission, shortcut, and recognizer configuration without asking employees to inspect settings manually.
- Refinement audit: text cleanup currently handles whitespace and basic CJK punctuation but not natural spoken layout commands such as “改行”, “新しい段落”, “new line”, or “new paragraph”.
- Refinement implementation now offers Option+Space, Control+Space, Command+Shift+Space, and Control+Option+Space with repeat-event suppression and conflict reporting.
- Recording now displays elapsed time and automatically finalizes at 55 seconds, below the common practical limit for a single Apple Speech task.
- Recognition finalization fallback is adaptive: 1.1 seconds when partial text exists and 1.8 seconds when no partial text has arrived, instead of always waiting 2.2 seconds.
- Cross-app insertion now confirms the original target process is still alive and frontmost before posting Command+V, avoiding accidental paste into a different app if activation fails.
- Diagnostics are copied only on explicit user action and contain configuration/permission metadata plus a sanitized last error; dictated text, audio, vocabulary, user name, and device name are excluded.
- The final refinement source passes Swift formatting/lint, shell syntax, plist validation, compilation, and 11 unit tests with zero failures.
- Final refined bundle is v1.1.0 build 2 with `x86_64` and `arm64` slices. The ad-hoc signed app passed strict verification and LaunchServices runtime launch.
- Final refined artifacts: 578 KB PKG and 668 KB DMG. Both passed package/disk-image verification; v1.0.0 remains alongside v1.1.0 as a rollback artifact.
- v1.1.0 SHA-256: PKG `a0f6dbca1e9fc270692c5e279d5a584c5e028c69499a03ead00456ff47536b1b`; DMG `48685a95d89cc4263c717cbc2b3b701ae84f19b293aaa805dab36c6f9c857573`.
- The new `SKIP_DMG=1` release mode lets restricted CI produce the Universal app and PKG while leaving DMG creation to a macOS release host; it is explicitly incompatible with notarization to prevent a partial signed release.
- The v1.2 usability audit found that language changes required a Settings round trip, an Accessibility-denied user could not finish onboarding, and activating an HS Voice window could erase the intended external input target.
- The menu-bar surface now exposes language and insertion-mode controls plus repeat/copy actions for the latest transcript.
- Clipboard-only mode is a persistent first-class setting, allowing managed environments to use transcription without granting Accessibility control.
- Input targeting remembers the last eligible external application, while paste still requires that exact process to be alive and frontmost before Command+V is posted.
- Undo is intentionally narrow: it is offered only for eight seconds after a successful automatic paste and succeeds only while the same target remains frontmost.
- Permission state refreshes automatically when HS Voice becomes active again after visiting System Settings.
- The v1.2 source passes Swift formatting/lint, shell syntax, plist validation, compilation, and 13 unit tests with zero failures.
- Final usability-refined bundle is v1.2.0 build 3 with `x86_64` and `arm64` slices; its ad-hoc signature and LaunchServices runtime launch passed.
- Final v1.2 artifacts are a 628 KB PKG and 968 KB DMG. Both passed structural/integrity checks, and all six v1.0-v1.2 hashes verify together.
- v1.2.0 SHA-256: PKG `449bbe7a62a9328c38f44b3b92860e6a2771c8fcac49de6b442c16a17cab3595`; DMG `69d2023fe8ecc08e1c23e0a5612648de764f65eef19aea98ce3c12e55f756f13`.
- Manual audience and purpose are clear from the request and product context: Japanese-speaking employees need a self-contained daily-use guide, while company IT needs concise privacy and support handoff notes.
- Manual content must distinguish required transcription permissions (Microphone and Speech Recognition) from optional Accessibility permission, which is needed only for automatic insertion.
- The default workflow is hold `Option + Space`, speak, and release; users can instead choose toggle mode and three other shortcuts.
- The menu-bar window exposes the main action, current state, quick language and insertion-mode controls, last-transcript repeat/copy/undo actions, History, Settings, Permissions, and Quit.
- Automatic insertion restores the prior clipboard when safe; clipboard-only mode leaves recognized text on the clipboard and avoids synthetic paste.
- One recognition session stops at 55 seconds; the guarded undo is available for eight seconds and only succeeds while the same destination app remains frontmost.
- History is off by default, stores text only when enabled, keeps at most 100 items locally, and never stores audio.
- Diagnostics are explicitly user-copied and exclude dictated text, audio, custom vocabulary, user name, and device name.
- A verified 1024 px HS Voice app icon already exists at `.artifacts/icon-work/AppIcon-1024.png` and can anchor the manual cover without introducing new branding assets.
- First visual render showed clean cover geometry, callout width, table layout, and footer placement, but Japanese glyphs rendered as empty boxes because LibreOffice did not resolve the requested East Asian fallback font.
- Fontconfig confirms `Hiragino Sans` is installed. LibreOffice applied the Latin font to Japanese runs despite the East Asian hint, so the manual must use `Hiragino Sans` for ASCII, high-ANSI, and East Asian font slots consistently.
- A second render still showed missing Japanese glyphs with `Hiragino Sans`; the cross-renderer fallback is `Arial Unicode MS`, which fontconfig resolves directly and includes Japanese glyph coverage.
- The third render also missed Japanese with `Arial Unicode MS`, so the root cause is not merely the family name; investigate OOXML language/font slots and LibreOffice's actual font-file access before another regeneration.
- OOXML inspection found Japanese text intact and explicit Unicode font names present, but the document default language and East Asian language were `en-US`, while heading styles retained theme-font attributes. Correcting language defaults and removing theme overrides is the next deterministic fix.
- Apple Pages is installed and can serve as an independent rendering fallback if LibreOffice still fails after the OOXML correction.
- With Japanese language defaults corrected, LibreOffice dropped Japanese glyphs entirely while retaining Latin text. The DOCX text remains intact, so use Apple Pages as the macOS-native independent renderer for final visual QA and PDF export.
- Apple Pages exported the DOCX successfully as a 9-page, tagged, US Letter PDF; Poppler rendered all nine pages to PNG for page-by-page inspection.
- Pages 1-2 visual QA passed: Japanese text renders cleanly, the cover hierarchy/icon/footer are balanced, and the quick-start callout, permission table, and bullet/list wrapping are unclipped and readable.
- Page 3 visual QA passed. Page 4 showed list items 1-2 protruding beyond the left page edge under Pages even though the numbering definition was valid; add matching direct paragraph indents while preserving real numbering.
- Latest-render pages 1-2 passed after the list-indent fix: no content drift, Japanese remains crisp, and all cover/body/table/callout elements stay within margins.
- Latest page 3 passed. Page 4 still places step items 1-2 at the physical left edge despite explicit paragraph indents, while items 3-4 render correctly; inspect those four OOXML paragraphs and use a step table if their structures match.
- OOXML comparison confirmed all four page-4 step paragraphs are structurally identical; replace only that sequence with a genuine three-column step/action/detail table, which better represents the repeated ordered fields and avoids the Pages list quirk.
- Latest candidate pages 1-2 passed after the scoped step-table change, confirming no upstream reflow or visual regression.
- Latest pages 3-4 passed: installation/setup numbering is stable, the security warning is readable, and the new four-row basic-operation table eliminates all left-edge overflow without crowding the spoken-command table.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Product name `HS Voice` with a neutral original identity | The repository name suggests this identity; it avoids copying Aqua's trademark and UI. |
| Native SwiftUI + AppKit implementation | Provides menu-bar, permissions, global shortcut, audio, Accessibility, and packaging integration without third-party runtime dependencies. |
| Apple Speech framework for the first release | Works without a separately operated backend or per-employee API credentials and supports partial results plus automatic punctuation. Some locales/devices may still use Apple network services; the app must state this accurately. |
| Universal `arm64` + `x86_64` release target | Covers current Apple Silicon and supported Intel MacBooks with one package. |
| Local-only app history with history disabled by default | Minimizes company data retention while still offering an opt-in productivity feature. |
| Build both architecture triples and combine with `lipo` | SwiftPM does not expose a multi-architecture flag in the installed toolchain, while cross-compilation is locally available. |
| Support ad-hoc and Developer ID release modes in one script | Produces a testable package now while making the same workflow usable by the company's release engineer once credentials are available. |
| Use `notarytool` and `stapler` only when a keychain profile is supplied | Matches Apple's current supported custom notarization workflow without requiring secrets in the repository. |
| Offer a curated set of safe global shortcuts rather than arbitrary key capture | Resolves common conflicts while avoiding fragile custom key-event serialization and unsupported modifier combinations. |
| Add privacy-safe copied diagnostics rather than transcript logging | Helps company IT diagnose configuration issues without collecting dictated content. |
| Cap each recognition session at 55 seconds | Prevents an abandoned toggle-mode session and finalizes before long-session service behavior becomes unpredictable. |
| Verify frontmost PID before synthetic paste | A clipboard-only fallback is safer than typing into the wrong application when activation fails. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| No existing project or design system | Build a clean native project and document the chosen product identity. |
| `pkgbuild --version` is not a valid invocation and stopped the chained discovery command | Treat successful usage output as confirmation; use concrete package generation as the real verification later. |
| Initial combined planning patch had a context-order mismatch | Re-read current content and used exact contexts; no partial changes were written. |
| Initial `swift test` could not write `/Users/kaia_hunter/.cache/clang/ModuleCache` in the managed sandbox | Configure `CLANG_MODULE_CACHE_PATH` and `SWIFTPM_MODULECACHE_OVERRIDE` under the project `.artifacts/` directory. |
| After redirecting caches, SwiftPM's own nested `sandbox-exec` was not permitted inside the managed Codex sandbox | Pass `--disable-sandbox` to SwiftPM here; Codex's outer filesystem sandbox continues to enforce the workspace boundary. |
| macOS 26 `sips` reported that it could not extract an image from the SVG; `qlmanage` also failed to initialize its nested sandbox | Use a small AppKit-based icon renderer checked into `scripts/`, avoiding Homebrew/ImageMagick dependencies. |
| `hdiutil create` reported “device not configured” inside the managed sandbox | The APFS DMG was created with approved access to the host disk-image service, then validated with `hdiutil verify`. |
| README scope footer still named v1.0 after other release references moved to v1.1.0 | Updated the scope statement and re-searched versioned documentation. |
| Final status update used one malformed findings context after packaging | Split the updates and applied exact contexts; artifact files were unaffected. |

## Resources
- Project root: `/Users/kaia_hunter/Desktop/dev/hsvoice`
- Aqua Voice official macOS product page: https://aquavoice.com/mac
- Aqua Voice official FAQ: https://aquavoice.com/info/faq
- Aqua Voice official guide: https://app.aquavoice.com/guide/index
- Apple `SFSpeechRecognizer` documentation: https://developer.apple.com/documentation/speech/sfspeechrecognizer
- Apple notarization documentation: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple Developer ID guidance: https://developer.apple.com/developer-id/

## Visual/Browser Findings
- The official product page emphasizes a low-friction utility rather than a document editor: one shortcut, a compact listening surface, and insertion into the active application.
- Product-level differentiators that can be represented without Aqua's proprietary model are responsive partial text, automatic punctuation, custom vocabulary/context, multilingual locale selection, and privacy controls.
- Visual QA of the generated 1024px app icon passed: the transparent outside corners are clean, the teal-to-deep-blue rounded-square gradient is balanced, and the six-bar white waveform remains legible at the intended macOS icon silhouette.
- Xcode `actool` produced a valid 54 KB ICNS from the generated complete icon catalog. Its simulator-service warnings are environmental and did not affect macOS icon output.
- The app UI source compiles cleanly after Swift formatter normalization. Runtime launch was verified, while live microphone/Accessibility end-to-end interaction still requires a human response to macOS permission prompts on a test Mac.

## Persistent Bottom Status Findings
- `OverlayWindowController` currently creates the correct non-activating, all-Spaces floating panel, but it is only shown from `beginListeningIfPossible()`.
- Both `cancelListening()` and the delayed reset path call `hide()`, so the screen-bottom indicator necessarily disappears whenever the app returns to idle.
- The current 560×132 recording card is useful for listening and result feedback but too visually heavy as an always-on idle indicator.
- The safest interaction model is one transparent fixed-size panel whose SwiftUI content is a compact centered idle pill and an expanded state card for non-idle states; this avoids focus theft and window-resize jitter.
- The panel should appear immediately after services start, remain mouse-transparent, follow the main screen, and only close when the app terminates.
- Existing tests use `@testable import HSVoice` with focused XCTest cases, so overlay compact/expanded state mapping can be locked without constructing the singleton app model or opening real windows.
- No repository `.swift-format` configuration is present; use the installed formatter's existing default style, matching the current two-space Swift source.
- The installed toolchain exposes formatting as `swift format`, and the established project workflow uses an in-place format pass followed by lint.
- Release scripts already redirect both Clang and SwiftPM module caches into `.artifacts`, which should also be used for the sandboxed regression test run.
- The persistent overlay implementation compiles cleanly on macOS 14 target APIs, including panel accessibility labeling and screen-parameter observation.
- SwiftPM emitted only expected sandbox cache warnings for user Library locations; project-local caches were used and the build/test result was unaffected.
- The first desktop screenshot did not contain the idle pill or an onboarding window after `open -n` targeted the raw SwiftPM Mach-O executable. This is a launch-method issue until process inspection proves otherwise; raw executables are not equivalent to the packaged menu-bar `.app` under LaunchServices.
- Process inspection found both the previously built v1.2 app and the new working-copy debug executable alive, but Core Graphics reported no on-screen HS Voice windows. The new code is running as a raw process without a proper application bundle, so visual QA should use a packaged `.app` and avoid confusing it with the already-running old build.
- The repository release builder supports `SKIP_DMG=1`, allowing a real Universal `.app` and PKG to be produced without invoking disk-image services during UI verification.
- The working-copy release build completed successfully with a valid ad-hoc signature. Xcode emitted non-fatal simulator-service warnings while compiling the macOS icon; the app, signature check, and component package all completed.
- A screenshot after launching the real app bundle still omitted the bottom pill on the captured MacBook display. Before altering the implementation, verify whether the floating panel was positioned on another connected screen and whether `screencapture` produced per-display files.
- Host inspection confirmed two displays. The HS Voice panel existed on-screen at 580×154, but its Core Graphics Y coordinate was `-162`, matching placement on the vertically arranged secondary display rather than the captured primary display.
- `NSScreen.main` is not stable for this accessory app at startup because HS Voice owns no key document window; the persistent status should use `NSScreen.screens.first`, which tracks the menu-bar/primary display, and continue to reposition on screen-parameter changes.
- After switching to the first/menu-bar screen and rebuilding, the idle pill is visibly centered above the Dock on the primary display. It remains compact, readable over a busy browser background, and clearly communicates `HS Voice`, shortcut readiness, and `fn で話す`.
- The orange `キー設定を確認` status in visual QA is expected because the test build's ad-hoc identity does not currently have Accessibility trust; the indicator correctly exposes this degraded-but-running state.
- Menu-bar UI automation is unavailable because `osascript` has no assistive-access permission. The current user defaults do not persist a shortcut choice, so the app falls back to `functionKey`; a reversible temporary `optionSpace` default can exercise the Carbon hotkey without changing system privacy settings.
- With the reversible `optionSpace` preference, the compact pill correctly changed to a green `起動中` status and displayed `⌥ Space で話す`. A flag-only synthetic Space event did not open the recording state, so one complete modifier key sequence is the final safe automation attempt.
- The complete physical-style Option/Space injection was also ignored under the host's privacy policy. No more automation attempts are warranted: active-state expansion is covered by the new `VoiceState` mapping test and the expanded card is the previously compiled/used recording UI, while the new idle state has passed live visual QA.
- The user's System Settings screenshot clearly shows the HS Voice Accessibility toggle enabled for the original app entry. The contradictory test-copy warning is caused by the different executable path/ad-hoc code identity, not evidence that the user's original toggle is off.
- User feedback rejects shortcut/key copy in the always-on surface. The idle indicator should be reduced from a text pill to a tiny branded waveform mark with a subtle running dot; detailed state copy remains reserved for non-idle expansion.
- Live QA of the icon-only revision passed for placement and readability, but the 11-point shadow creates a larger perceived footprint than the 34-point control. A final reduction to roughly 28 points with a 5-point shadow better matches the “as unobtrusive as possible” requirement.
- Final live QA passed after reduction: the idle surface is approximately 28 points, has no copy or shortcut hint, uses a tiny branded waveform plus green running dot, and casts only a restrained 5-point shadow above the Dock.
- Original-project source sync matched byte-for-byte and all 17 tests passed there. Its existing `dist/HS Voice.app` is owned by `root:wheel`, so the normal user-owned release script cannot delete its contents; moving the intact bundle to a task-local backup is safer than changing ownership or forcing deletion.
- macOS also denied a normal-user rename of the root-owned bundle despite the user-owned parent directory. One exact, non-interactive privileged backup move is the last direct replacement attempt; a separately built user-owned app remains available as the safe fallback.
- The exact privileged move could not run without an administrator password, so direct replacement is closed after three safe attempts. The correct fallback is a macOS Installer package, which presents the system authorization UI rather than exposing or bypassing credentials.
- The final installer is 675 KB with SHA-256 `64cc3843064a6c11ebcf0c2a102b6f695a85b8bc7afdf8bb940327039a3dd1e9`. Verification passed for Japanese product resources, `/Applications` payload, ad-hoc app signature validity, and Universal `x86_64 arm64` executable slices.
- The verified working-copy app remains launched with the final 28-point idle indicator, and the macOS Installer for the deliverable PKG has been opened for the required administrator-authorized update.

## Aqua Voice Minimal Overlay Reference
- The supplied screenshot contains no branding, status dot, key label, or instructional copy in the persistent surface.
- The only persistent element is a dark horizontal capsule approximately 54 pixels wide by 8–9 pixels high, centered at the bottom edge (about a 6:1 aspect ratio).
- HS Voice's current 28-point branded square is still visually busier than the reference. Idle should be a plain adaptive dark capsule; active states should use one slim material capsule with only the minimum waveform/timer or result status.
- The implemented idle capsule is 54×8 points with adaptive `Color.primary`, no border, logo, dot, or copy, and only a 2-point restrained shadow.
- Active listening is reduced to a 38-point-high material capsule containing one state glyph, a 96-point level meter, and elapsed time. Other transient states use the same capsule with one short status line.
- Live primary-display QA passed: the waiting UI appears as a single centered dark bar just above the Dock, with the same visual proportions and near-edge placement as the supplied Aqua Voice reference.
- The bar remains visible over a busy spreadsheet/dialog background without drawing attention or obscuring content.
- The refreshed single-file installer is 663 KB with SHA-256 `6191cba8eaf5969fbb871aa890c46ef985825c325f60024d6250471238191ef1`.
- Installer verification passed for Japanese resources, `/Applications` payload, ad-hoc app signature integrity, and Universal `x86_64 arm64` slices.

## Automatic Insertion Failure — 2026-08-25
- The user reports that recognized text reaches the clipboard but is not pasted at the active mouse/text cursor.
- The supplied System Settings screenshot shows the HS Voice Accessibility toggle enabled, so the investigation must not assume the user simply forgot to grant permission.
- The earlier macOS alert still says the running HS Voice process requested Accessibility control. This combination strongly suggests either a TCC/code-identity mismatch after replacing an ad-hoc build or a false trust result/event-posting failure in the app.
- Clipboard success narrows the failure to the automatic-insertion branch after transcription, not audio capture, speech recognition, or text processing.
- `TextInsertionService.insert` always writes recognized text to the pasteboard first, then returns `.copiedOnly` whenever `AXIsProcessTrusted()` is false, the saved target is nil, target activation fails, or the synthetic Command-V event cannot be constructed.
- `SettingsStore.insertionMode` persists `.clipboardOnly`; granting Accessibility later does not currently promote that explicit/persisted mode back to `.automatic`.
- Automatic mode currently treats successful construction/posting of two `CGEvent`s as proof of paste success. Core Graphics provides no delivery acknowledgment here, so `.pasted` can be reported even when the destination ignores the event.
- The fn shortcut has a polling fallback, so successful dictation does not prove Accessibility trust: fn capture can still work while `AXIsProcessTrusted()` is false and insertion falls back to clipboard.
- Both the menu bar and Settings expose the persisted input-mode picker, but the permission screen does not show or repair a mismatch where Accessibility is on while the mode remains `clipboardOnly`.
- Onboarding's `コピーだけで使う` action persists `clipboardOnly` and closes onboarding. Returning later to grant Accessibility does not switch the mode, so this is a credible exact explanation for “permission is on but it still only copies.”
- The user-facing `.copiedOnly` outcome conflates several causes (intentional copy mode, untrusted process, missing target, activation failure, event construction failure), leaving neither the UI nor diagnostics able to identify which one occurred.
- Direct inspection of the live preference domain `com.hsvoice.desktop` found `completedOnboarding = 1` and `insertionMode = clipboardOnly`. This confirms the immediate cause on the user's Mac: the app deliberately passes a nil target and stays in clipboard-only mode even though System Settings shows Accessibility on.
- The current release app in `dist/HS Voice.app` is ad-hoc signed with a CDHash-only designated requirement. That remains a separate distribution concern for future binary replacements, but it is not necessary to explain this specific run because the persisted mode already forces clipboard behavior before paste is attempted.
- Process-list inspection was blocked by the managed sandbox (`sysmond service not found` / `operation not permitted`); preference and bundle inspection still yielded the decisive cause without retrying that restricted path.
- Build metadata is currently v1.2.0 build 6. Both release scripts default to this build number, and `Packaging/Info.plist` matches it.
- The release builder writes directly into the root-owned `dist/HS Voice.app`, which previous sessions already proved cannot be replaced as the normal user. The repaired installer should be built through an isolated/user-owned output path instead of retrying destructive replacement of that bundle.
- The repair adds a persisted “choice finalized” marker: a deliberate picker selection is never overridden, while onboarding's permission fallback and legacy clipboard-only installs remain eligible for one automatic restoration after Accessibility becomes trusted.
- Both input-method pickers now route deliberate user choices through the same setting API, so the migration cannot later override an explicit request to remain clipboard-only.
- Focused tests cover legacy recovery, no recovery before permission, permission-fallback recovery, and preservation of an explicit clipboard-only choice.
- Swift formatting lint passed and the complete suite now has 20 passing tests with 0 failures. The expected SwiftPM user-cache warnings are sandbox-only and do not affect the project-local build/test result.
- Installer builds now place intermediate app/component artifacts under `.artifacts/installer-work/release-output`, avoiding the immutable root-owned legacy `dist/HS Voice.app`. Shell syntax validation passed for all three packaging scripts.
- The prior build-6 installer is user-owned, 678,901 bytes, with SHA-256 `6191cba8eaf5969fbb871aa890c46ef985825c325f60024d6250471238191ef1`; preserve it under `.artifacts` before publishing build 7.
- The prior build-6 installer was preserved at `.artifacts/rollback/build-6/HSVoice-Installer-1.2.0-build-6.pkg` before replacement.
- The repaired single-file installer is v1.2.0 build 7, 685,192 bytes, Universal `x86_64 arm64`, with SHA-256 `d1fea7d34e0434a308e7d07e4164118d261f0f24990753d36764eeab75359e16`.
- Installer verification passed for Japanese resources, `/Applications` payload, app signature integrity, bundle metadata, package structure, and both CPU architectures.
- The user's live preference domain was changed only from `insertionMode = clipboardOnly` to `automatic`, then the existing trusted HS Voice build was restarted. A read-back confirmed `automatic`.
- The local build remains ad-hoc signed and the product package unsigned; future replacement builds can require renewed Accessibility approval unless the company supplies stable Developer ID signing/notarization.

## Dock Presence Request — 2026-08-25
- The user reports that the HS Voice icon is absent from the Mac application bar. Interpreting “application bar” as the bottom Dock, because the app already has a separate menu-bar surface.
- The planned behavior is a persistent Dock icon plus a useful response when the icon is clicked, while retaining menu-bar access, global dictation, and the bottom status capsule.
- Root cause confirmed in two independent places: `Packaging/Info.plist` sets `LSUIElement = true`, and `AppDelegate.applicationDidFinishLaunching` forces `.accessory` activation policy. Either suppresses normal Dock presence; both must change.
- The app has only a `MenuBarExtra`, SwiftUI Settings scene, and custom onboarding/history windows. A regular Dock app with no reopen handler would show an icon but do nothing useful when clicked after its windows close.
- The safest design is regular activation plus a dedicated settings window controller used by both the Dock reopen callback and the menu-bar Settings action. The existing self-process exclusion in `TextInsertionService` preserves the previously focused external target when HS Voice becomes active.
- Implementation now sets `LSUIElement = false`, requests `.regular` activation, handles Dock reopen explicitly, and opens one reusable native Settings window from the Dock, Command-comma, or the menu-bar Settings button.
- Dock reopen deliberately ignores AppKit's `hasVisibleWindows` flag because the always-visible bottom overlay is itself an NSPanel; relying on that flag would make Dock clicks appear inert.
- Local release metadata advanced to v1.2.0 build 8.
- Swift formatting/lint passed and all 20 regression tests succeeded with 0 failures after the Dock integration changes.
- The build-7 installer was preserved under `.artifacts/rollback/build-7` before publishing build 8.
- The build-8 Universal application and single-file installer completed successfully through the isolated packaging path; package resources, payload, signature integrity, metadata, and both architectures passed the automated verifier.
- Live desktop QA confirms the running build-8 HS Voice blue waveform icon is visible in the Dock near the right side, while the existing top menu-bar icon and bottom status capsule remain present.
- The first screenshot attempt was blocked inside the managed sandbox; the same exact non-mutating capture succeeded with approved display access.
- Calling `open` again on an already-running windowless app did not deliver a visible Dock-reopen result in this environment; the foreground app remained LINE. This is not equivalent proof of a physical Dock click, so use a direct reopen Apple event for the next check rather than changing the working Dock implementation.
- A direct `reopen` Apple event also produced no visible settings window and did not activate HS Voice. Before altering the handler, verify the exact running bundle/process and whether the event is being delivered to the build-8 copy rather than another LaunchServices registration.
- Process inspection confirmed PID 42861 is the exact build-8 executable under `.artifacts/installer-work/release-output`; the inert scripted reopen is not caused by an old HS Voice process.
- Final build-8 metadata check: v1.2.0 build 8, `LSUIElement = false`, Universal `x86_64 arm64`, valid ad-hoc app signature, and retained `automatic` input mode.
- Final build-8 installer is 688,193 bytes with SHA-256 `651eae94667c59162edf6d858942b8c46355e0613f362a8c03828fee539ed405`. The product package remains unsigned because no company Installer identity is available.
- Final Bundle-ID activation visually magnified the correct blue waveform Dock item and displayed the `HS Voice` tooltip, confirming both Dock registration and app identity. Scripted reopen did not surface Settings after three distinct attempts, so no further automation retries are warranted; Settings is still directly available from the menu-bar action and Command-comma.
- The user-requested outcome is complete: build 8 displays a persistent HS Voice icon in the Dock while running, with the top menu-bar icon and bottom idle capsule preserved.

### Final visual QA — pages 5–6
- Page 5 passed: menu-bar actions, prior-text reuse, safety callout, and input-method comparison tables are aligned, readable, and within margins.
- Page 6 passed: general settings, all four shortcut choices, and language/dictionary guidance render cleanly with no clipping, overflow, or Japanese glyph issues.

### Final visual QA — pages 7–8
- Page 7 needs one small correction: the “音声認識処理” value in the data-handling table is clipped at the right edge; shorten the wording and regenerate.
- Page 8 passed: troubleshooting table, IT escalation procedure, and diagnostic-data callout are readable and contained within the page.

### Final visual QA — page 9
- Page 9 passed: quick-reference callout, action table, and before/after checks are balanced, legible, and not clipped.
- Applied the page 7 correction by shortening the data-handling wording without changing its meaning.

### Regenerated final visual QA — pages 1–2
- Pages 1–2 passed after regeneration: cover, overview, environment, permissions, and document map are unchanged and fully legible.

### Regenerated final visual QA — pages 3–4
- Pages 3–4 passed after regeneration: installation, permissions, four-step basic operation table, recording modes, and voice-layout commands remain aligned and complete.

### Regenerated final visual QA — pages 5–6
- Pages 5–6 passed after regeneration: menu-bar controls, reuse/safety guidance, input methods, settings, shortcut choices, language, and dictionary sections remain intact.

### Regenerated final visual QA — pages 7–8
- Page 7 passed after correction: the shortened Apple speech-service wording now fits completely with clear table spacing.
- Page 8 passed after regeneration: all troubleshooting rows, support steps, and the closing callout remain complete and within margins.

### Regenerated final visual QA — page 9
- Page 9 passed after regeneration. All nine final PDF pages have now been visually inspected at original detail with no clipping, overlap, missing Japanese glyphs, or margin violations.

### Final structural and extraction checks
- Poppler independently split the PDF into pages 1–9, confirming nine valid pages; the macOS `file` page count is a false summary and not used for acceptance.
- PDF text extraction contains every key section and the corrected page 7 wording; the PDF is searchable/selectable rather than image-only.
- DOCX core metadata contains no personal name or device identifier, but the creator remains the python-docx default. Replace it with the product name and regenerate once more for a cleaner internal deliverable.

### Final DOCX audit results
- All 10 data tables have exact fixed DXA geometry: each table width, indent, grid sum, and every row’s cell widths agree at 9360 DXA.
- The document has one portrait Letter section with 1-inch margins and correctly independent headers/footers.
- Heading audit found 8 Heading 1 and 20 Heading 2 paragraphs. Numbering warnings apply to intentional real numbered/bulleted list items, not missing section headings.
- Style lint’s direct-format warnings are expected for the editorial cover, shaded callouts, and preset list formatting; the document uses a single Unicode font family consistently.
- The only image is the inline 1.25-inch HS Voice icon; its accessibility audit already passed.

## Single-File Installer Findings
- The existing v1.2.0 release already contains a Universal app and a flat component PKG, but the release script also emits an app bundle and DMG into the same distribution directory.
- A dedicated final handoff directory should contain only one clearly named PKG, while the existing rollback artifacts remain untouched in dist.
- Wrapping the component package with productbuild allows Apple Installer to show Japanese welcome/readme screens while preserving a one-file double-click experience.

- The existing component package is valid, installs 9 payload files to /Applications, carries bundle version 1.2.0 build 3, and is currently unsigned because no Developer ID Installer identity is available.
- The new product archive must preserve the current company-signing parameters: unsigned/ad-hoc for local testing now, and Developer ID Installer plus notarization when company credentials are supplied.
- README and enterprise guidance currently refer to the multi-artifact dist flow; they need an explicit single-file installer command and the new final package name.
- The managed sandbox cannot resolve the root volume for installer’s showChoicesXML target check, but installer’s read-only pkginfo mode can validate that the final product archive is recognized without attempting an installation.
- Opening the final PKG with the Installer application succeeded, matching a Finder double-click. The initial AppleScript window-title query did not return promptly, so process/window validation should use a non-blocking process check before closing Installer.
- Final standalone installer: 643,112-byte HSVoice-Installer-1.2.0.pkg with SHA-256 ad4231cab5bdbeb497316c2b30a13faecc393951042eda549b5aa92b8d9c016c.
- The final handoff directory contains exactly one file. Its product archive contains the Universal component payload plus Japanese welcome, readme, and completion resources.
- The local artifact is intentionally unsigned because no company Developer ID Installer identity is available. The same build script accepts company Application/Installer identities and a notarization profile for trusted all-employee distribution.

## Zero-Configuration Deployment Requirement
- The comparison product is Aqua Voice, not “Smart Voice.” The target experience is one installer, sensible defaults, guided permissions, and immediate Option+Space use.

### Apple platform constraints verified on 2026-08-24
- Apple requires a system consent prompt the first time SFSpeechRecognizer authorization is requested; the response is stored for later launches. Source: https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition
- Legacy PPPC cannot grant microphone access; it can only deny it. Speech Recognition is manageable, while legacy Accessibility pre-approval is deprecated from macOS 26.2 and removed in macOS 27. Source: https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary
- Apple’s newer declarative App Settings flow can bundle privacy defaults into one organization-justified consent prompt for AppKit apps; if the employee accepts, configured defaults are applied, and if declined normal prompts remain. Source: https://developer.apple.com/documentation/devicemanagement/appsettings
- Therefore the supportable target is not zero consent: it is zero app configuration, plus one guided Apple permission sequence on unmanaged/current Macs or one consolidated organization consent on supported managed Macs.

### Current first-run audit
- App defaults are already Aqua Voice-like: Japanese, hold-to-talk, Option+Space, automatic insertion, on-device preference, spoken formatting on, and history off. Employees do not need to choose settings.
- The previous onboarding required an app button to request microphone/speech, a separate Accessibility settings action, and a final completion click; the implemented flow removes those extra app-level steps.
- The safe friction reduction is one “セットアップを開始” action that requests microphone and speech sequentially, prompts Accessibility for automatic insertion, and automatically closes onboarding as soon as all required grants are present.
- Clipboard-only must remain an explicit fallback because macOS may deny Accessibility or company policy may forbid it.

### Managed deployment compatibility
- For macOS 14 through current macOS 26, use legacy PPPC to preapprove Speech Recognition and Accessibility; microphone still requires the employee’s Apple consent. On macOS 26.2+ this Accessibility grant path is deprecated but remains until its removal in macOS 27.
- Apple’s replacement declarative App Settings API is preliminary; Accessibility defaults are documented for macOS 27+, and it presents an organization-justified consent prompt rather than silently bypassing privacy.
- The new App Settings object currently documents Accessibility and Microphone defaults but not Speech Recognition, so HS Voice must continue to handle the Speech framework’s own authorization state safely.
- For a normal downloaded installer experience, the final app and PKG must use valid Developer ID Application/Installer signatures, hardened runtime, secure timestamps, notarization, and a stapled ticket. Source: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

- Info.plist already contains clear Japanese microphone and speech-recognition purpose strings and macOS 14 minimum metadata.
- Onboarding has a dedicated closeable window and can safely auto-close once required grants are detected after returning from System Settings.
- Existing settings tests cover insertion-mode persistence but not the complete fresh-install default set; add a regression test that proves users can rely on Japanese, Option+Space, hold-to-talk, automatic insertion, history-off, and spoken-formatting defaults.
- Automatic insertion relies on Accessibility trust and posts synthetic Command-V keyboard events, so managed deployment should cover both `Accessibility` and `PostEvent` services where the deployed macOS version supports them.
- The current ad-hoc build's designated requirement contains only `cdhash` identities. Those hashes change with the binary and are unsuitable for production PPPC; the managed-profile generator must reject ad-hoc/CDHash-only builds unless an explicit test-only override is supplied.

### Implemented zero-configuration flow
- Fresh installs now present one `セットアップを開始` action, request microphone and Speech authorization in sequence, continue directly to Accessibility for automatic insertion, and auto-close onboarding when all required grants become available.
- Users who cannot grant Accessibility retain an explicit `コピーだけで使う` fallback; selecting it persists clipboard-only mode and completes onboarding without further app configuration.
- A new fresh-install regression test locks the ready-to-use defaults: Japanese, Option+Space, hold-to-talk, automatic insertion, on-device preference, spoken formatting on, and history off.
- The PPPC generator derives the Bundle ID and exact designated requirement from the final app, includes SpeechRecognition, Accessibility, and PostEvent, deliberately omits Microphone, and rejects ad-hoc/CDHash-only identities for production use.
- Final local installer is v1.2.0 build 4, 656,010 bytes, Universal `x86_64 arm64`, and SHA-256 `3495ad499476897c319066a2aa33f083e1205fd979ea09eecf4a080f8bdeacde`.
- The final handoff directory contains exactly one PKG; it passed package/resource/payload verification and opened successfully in Apple Installer without performing an installation.
- The updated manual passed DOCX ZIP integrity, accessibility audit (0 high/medium/low), tagged/searchable 9-page PDF checks, exact text extraction, and page-by-page visual QA.

## fn Key Default Findings
- Apple exposes the laptop Fn/Globe modifier as `CGEventFlags.maskSecondaryFn`, including on flag-changed events, so the app can distinguish the physical Fn key from F1–F12. Source: https://developer.apple.com/documentation/coregraphics/cgeventflags/masksecondaryfn
- Carbon `RegisterEventHotKey` is appropriate for the existing modifier-plus-Space combinations but not a modifier-only Fn shortcut.
- AppKit global event monitors are observation-only, do not receive the app's own events, and require Accessibility for key-related events. An active Core Graphics session event tap is the more appropriate Fn-only path because it can handle press/release globally and prevent the same standalone Fn press from also triggering the macOS Globe-key action. Source: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29
- Core Graphics event taps for keyboard events require assistive-device/Accessibility trust, which HS Voice already requests for its default automatic-insertion mode. Source: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29
- Keep the four Space-based shortcuts as fallbacks for external keyboards without Fn and for clipboard-only deployments that intentionally decline Accessibility.

### Implemented fn behavior
- Fresh settings now default to `ShortcutChoice.functionKey`; the existing Option/Control/Command Space combinations remain selectable and persisted.
- A Core Graphics session event tap listens only for the physical `kVK_Function` flag-change events, dispatches hold press/release callbacks, and consumes that standalone event so the Globe-key action does not fire at the same time.
- If the event tap is disabled by timeout or user input, HS Voice re-enables it. When Accessibility changes during onboarding, the app re-registers the fn tap automatically.
- Settings now explains that fn requires Accessibility and offers the Space combinations for keyboards without an fn key.

### Final fn-default artifacts
- Swift formatting lint passed and the full suite completed with 15 passed, 0 failed, including physical-fn press/release classification.
- The updated DOCX and PDF manual describe fn as the initial key; the PDF remains a tagged, searchable, visually inspected nine-page document.
- The final v1.2.0 build-5 PKG is Universal `x86_64 arm64`, 659,094 bytes, with SHA-256 `b5c4977e1631f523f6b45fd4234d7d0df75ec7b54b299fdb0aebfed6c53e1a7a`.
- Installer resource, payload, signature-state, bundle-version, and single-file checks passed. The exact PKG opened in Apple Installer and was closed without installation.
- The package remains unsigned and the app ad-hoc signed for local testing. Trusted company-wide distribution and a stable production PPPC profile still require company Developer ID Application/Installer identities and notarization.
# Final Completion Scope — 2026-08-25
- The only product in scope is the current HS Voice. New variants and parallel prototypes are explicitly out of scope.
- Previous phases marked features complete, but the final pass must revalidate the whole journey from launch through permissions, dictation, insertion, settings, and installation using current source and runtime evidence.
- “Perfect” will be treated as: no known reproducible high-impact defects, coherent existing-product UX, passing automated checks, and one canonical installer; unavoidable macOS permission/signing constraints must be stated rather than hidden.
- The workspace is a SwiftPM native macOS app and is not currently a Git repository, so all changes must be preserved and audited by explicit file inspection.
- The canonical handoff already exists at `release/HSVoice-1.2.0/HSVoice-Installer-1.2.0.pkg`, but `dist/` still contains legacy 1.0/1.1 artifacts and the README still advertises a three-artifact build path. The final pass should avoid presenting those as additional products.
- The source surface is compact enough for a complete audit: 17 application Swift files, 6 test files, packaging scripts/resources, and one installer verifier.
- The core user path is centralized in `AppModel`: shortcut press → permission check → target capture → `SpeechTranscriber` → text processing → `TextInsertionService` → transient outcome/undo.
- The insertion implementation intentionally snapshots the previous pasteboard, activates the original external app, posts Command-V, and restores the previous pasteboard only if the user has not changed it; clipboard-only fallback is preserved.
- The fn implementation has a 60 Hz HID-state polling path even when the optional Accessibility-backed event tap cannot be created, so the default shortcut is not entirely dependent on the tap.
- Audit candidate: `SpeechTranscriber` has only shared `didComplete` state and no per-recording generation token. A delayed callback from a canceled prior `SFSpeechRecognitionTask` may be able to complete a newly started recording. This must be confirmed from full lifecycle code and then covered or repaired.
- Existing automated coverage is strongest around settings, text processing, history, state presentation, and diagnostics; there is no visible direct coverage yet for transcription-session races, hotkey registration failure recovery, or actual paste delivery.
- The previous completion log explicitly records that three scripted reopen/activation attempts never surfaced Settings, yet Phase 35 was closed because Dock presence alone was accepted. Under the new “finish one product” instruction, this remains a known interaction gap and must not be carried forward as complete.
- The regular Dock app has no SwiftUI `WindowGroup`; all windows are custom AppKit controllers. `applicationShouldHandleReopen` is intended to open Settings, but current runtime evidence says it did not. A reliable activation/reopen path needs implementation and live proof.
- The bottom overlay is intentionally passive (`ignoresMouseEvents = true`) and uses a minimal 54×8 idle capsule; its active states are visually compact and retain screen-reader status text.
- Settings/onboarding expose all three macOS permissions and the clipboard-only fallback. The onboarding auto-completes only when transcription plus either Accessibility or copy-only mode is ready.
- The current tests total 20 cases but exercise no `AppModel`, `SpeechTranscriber`, window-controller, or `TextInsertionService` behavior directly. The known Dock issue and session race can therefore pass the full suite unchanged.
- Installer verification is appropriately strict about a single file in the canonical `release/HSVoice-<version>/` directory, Universal architectures, app code-sign integrity, Japanese resources, payload path, and non-relocatable installation.
- Documentation metadata is inconsistent: the app/installer scripts and README default to build 8, while `docs/ENTERPRISE_DEPLOYMENT.md` still shows build 6 in the production command. This must be synchronized in the final pass.
- The canonical local package is necessarily unsigned/ad-hoc without company certificates. “Perfect” can mean functionally verified locally, but cannot honestly mean Gatekeeper-ready company distribution until Developer ID Application/Installer identities and notarization credentials are supplied.
- Baseline formatter lint passes and all existing 20 tests pass. This establishes a clean starting point but does not invalidate the uncovered lifecycle gaps.
- Existing build-8 screenshots visually confirm the Dock icon, menu-bar icon, and bottom idle capsule. A separate reopen screenshot is visually unchanged: no Settings window appeared, corroborating the documented Dock activation defect.
- The bottom capsule remains visible above foreground app content and does not steal focus; no obvious clipping or color defect is visible in the prior full-desktop capture.
- Menu-bar language and insertion pickers are correctly disabled while the app is busy, but the standalone Settings window remains fully editable during recording/processing. This can change locale/formatting/history semantics between session start and completion.
- `AppModel.refreshPermissions()` re-registers the fn shortcut on every activation even while recording. Re-registration clears the pressed state; activating HS Voice while holding fn can therefore lose the release transition and leave recording running until the 55-second safety stop.
- `copyDiagnostics()` can be invoked from Settings while recording and currently changes the global voice state to success. That makes the subsequent fn release ineligible to stop the live transcriber. Transient utility feedback must never overwrite a busy state.
- The menu-bar itself already guards repeat/undo and disables quick controls while busy, so the repair should centralize invariants in `AppModel` and also disable standalone settings controls during active work.
- Post-processing and history decisions currently read live settings at completion instead of the values used to start the recording. Capturing a per-recording configuration will make each session deterministic even if settings change through another path.
- The canonical installer build itself is reproducible and isolated under `.artifacts`; it overwrites one versioned final directory and its verifier enforces exactly one handoff file. Legacy `.app/.pkg/.dmg` generation exists only as an underlying developer build step.
- Installer HTML is concise, Japanese, and consistent with the actual default/permission flow. No additional product branding or variant is needed.
- The final repair scope should remain narrow: explicit reopen-event handling, per-session speech callback isolation, busy-state invariants, deterministic recording configuration, test coverage, metadata synchronization, and one rebuilt package.
- Japanese spoken-command replacement can theoretically match prose containing command phrases, but changing natural-language parsing without real-world samples would expand scope and risk regressions. It is not part of this completion pass unless tests reveal a reproducible user path.
- The completion implementation compiles cleanly. The suite now has 22 passing tests, including stale speech-session invalidation and busy-state configuration policy.
- Reopen handling now registers directly for the macOS `kAEReopenApplication` Apple event while retaining the normal AppDelegate reopen callback; both routes open the same existing Settings/onboarding window controller.
- Active recordings now capture locale, spoken-formatting, and history policy once at start, and utility success messages cannot replace listening/processing state.
- Shell syntax, plist validation, and build-number search all pass. Every current build reference is synchronized to internal build 9; no stale build 6/8 command remains in product documentation or scripts.
- The build-8 canonical installer was preserved only as a rollback artifact under `.artifacts`; it is not part of the user-facing release directory.
- Build 9 completed successfully for both arm64 and x86_64. The build emitted sandbox-only SwiftPM cache and unavailable CoreSimulator logging warnings, but the application signed, packaged, and passed the full installer verifier.
- The final release directory again contains one Installer-compatible PKG with Japanese resources and a non-relocatable `/Applications/HS Voice.app` payload. It remains unsigned at the product-package level because company signing credentials are not present.
- Final package metadata: HS Voice 1.2.0 build 9, 699,526 bytes, SHA-256 `e63f21eee5139efbaaf1ba1c657e58adb067b17b4a7235062524ee9bdce86d35`.
- The embedded application is Universal `x86_64 arm64`, has `LSUIElement = false`, and passes strict ad-hoc signature verification. The final release directory contains exactly the one PKG.
- The current user defaults show onboarding complete but a legacy permission-fallback `clipboardOnly` value; the existing startup migration should restore automatic insertion when the trusted build reports Accessibility permission. Live QA must avoid treating this stored fallback as an explicit user choice.
- Live QA replaced the old PID 42861 with build-9 PID 65599 from the exact verified application bundle.
- Sending `open -b com.hsvoice.desktop` to the running app still produced no Settings window in the screenshot. This command may activate/register the app without emitting `kAEReopenApplication`; test the explicit AppleScript `reopen` event before judging the new handler.
- The live build-9 screenshot otherwise shows the existing bottom idle capsule and Dock icon intact with no visual regression.
- An explicit AppleScript `reopen` event also left the desktop unchanged, so direct Apple-event registration is not sufficient in this SwiftUI `MenuBarExtra`-only lifecycle. The next repair will use application activation as a fallback while suppressing initial/login launch and respecting already-visible onboarding/settings/history windows.
- This activation fallback is appropriate for the actual user intents that select a regular app from the Dock, Finder, or Command-Tab. It must not trigger when a workflow window is already visible.
- Activation-gate implementation compiles, formatter lint passes, and the suite now passes 23/23 tests.
- The gate is enabled only 0.75 seconds after launch, so initial/login startup and the scheduled first-run onboarding activation are not converted into a surprise Settings window.
- The final Universal installer was rebuilt after the activation repair and again passed all automated package/app checks. The earlier checksum is superseded and must be recalculated after live acceptance.
- The exact repaired build (PID 70200) still remained visually inert after AppleScript `activate`; LINE stayed foreground and no Settings window appeared. This is the third distinct failed simulation, so the current callback/activation-gate approach is not accepted.
- Further blind retries are ruled out. The lifecycle needs a broader redesign grounded in the local macOS Apple-event definitions or an actual regular window scene that guarantees a Dock-visible primary window.
- Local Xcode SDK headers confirm `kCoreEventClass = 'aevt'` and `kAEReopenApplication = 'rapp'`; the direct handler uses the correct constants. They also document `keyAELaunchedAsLogInItem`, validating the need to suppress windows during login-item launch.
- AppKit still documents `applicationShouldHandleReopen` and `applicationDidBecomeActive` as the canonical delegate hooks. Because synthetic AppleScript commands did not make HS Voice foreground, the decisive next check is an actual accessibility-driven click on the HS Voice Dock item, not another Apple-event simulation.
- The environment denied Accessibility to System Events, and a raw Core Graphics click produced no visible activation, so UI automation cannot provide trustworthy physical-Dock evidence here.
- The architectural root issue is now clear: HS Voice advertises itself as a regular Dock app but defines only a `MenuBarExtra` scene. Replace the custom Settings controller/callback maze with a real SwiftUI `Window` scene as the single primary Dock window.
- A real Window scene gives LaunchServices/AppKit a native window to open on normal launch and reopen from the Dock. First-run onboarding and login-item launches can explicitly close/suppress that Settings window; the SDK-provided `keyAELaunchedAsLogInItem` distinguishes the latter.
- The native Window-scene architecture compiles cleanly, formatter lint passes, and the complete suite returns to 22/22 passing tests after removing the obsolete activation-gate test.
- Menu-bar Settings and Command-comma now call SwiftUI's `openWindow(id: "settings")`; the custom Settings controller and all explicit reopen/activation hooks have been removed.
- The Universal single-file installer rebuilt successfully with the native Settings window scene and passed the same automated package verifier.
- Live launch of the exact final bundle now visibly creates the centered HS Voice Settings window for the first time. It appears behind the currently foreground LINE window because `open` did not request foreground activation, but the primary Dock window now exists in the regular app lifecycle.
- With a real Settings window present, a subsequent standard application activation should bring HS Voice forward; this is the final live check for Dock-equivalent behavior.
- Foreground activation now succeeds: the macOS menu bar switches to HS Voice and the application's windows come forward. This is the first conclusive Dock-equivalent activation proof.
- Live QA also exposed a first-run presentation defect: onboarding opened in front of the native Settings scene, leaving Settings visibly stacked behind it. The primary-window conversion is correct, but first-run suppression must use a reliable hide/order-out path or unify onboarding with the scene before acceptance.
- The onboarding itself renders cleanly with all permission rows, default summary, fallback, and no clipping; the defect is window stacking, not its layout.
- The preference domain now reads `completedOnboarding = true` and `insertionMode = automatic`, so the visible onboarding may belong to a stale duplicate process/bundle registration rather than the newly launched final executable. Resolve exact live PIDs and window owners before changing first-run code.
- Process inspection confirms there is exactly one HS Voice process and it is the final bundle (PID 75618); the onboarding/settings stack is therefore a real lifecycle issue, not a duplicate app.
- The clean resolution is one primary SwiftUI Window whose content is onboarding until `completedOnboarding` becomes true and Settings afterward. Keep the custom onboarding window only for later permission-repair requests after users close the primary scene.
- Login-item launch should `orderOut` the primary Window rather than closing a SwiftUI scene that may immediately recreate itself.
- Unified primary-window implementation compiles and all 22 tests pass. Onboarding and Settings can no longer coexist as separate startup windows because they are mutually exclusive content of the same scene.
- The canonical Universal installer rebuilt and passed verification after this final window-stack repair.
- The black capture is a valid 3024×1964 PNG, but `lsappinfo front` simultaneously returned no frontmost application. This indicates a temporary unavailable/locked UI session rather than an HS Voice rendering failure; it is excluded from product QA evidence.
- The first-run menu-bar Permissions action now reopens the same primary onboarding scene instead of creating a duplicate custom onboarding window; completed users still get the dedicated permission-repair window.
- The final menu-edge repair preserves 22/22 passing tests and formatter lint. The canonical package was rebuilt once more and passed the full installer verifier.
- Final independent acceptance passed: formatter lint, 22/22 tests, shell syntax, all plists, strict app signature verification, Universal `x86_64 arm64`, Japanese installer resources, payload path, non-relocatable component, and exactly one release file.
- Final canonical installer: 715,433 bytes, SHA-256 `febe6fc0ade11f7dc72d9b68848e01cfdb55f5cfd041eb1f841381f05b7dc80c`.
- No obsolete custom Settings controller, activation gate, explicit reopen handler, `showSettings()` path, or stale build 6/8 metadata remains.
- The only outstanding external distribution constraint is credentials: the app is ad-hoc signed and the product PKG is unsigned until the company provides Developer ID Application/Installer identities and notarization access.
