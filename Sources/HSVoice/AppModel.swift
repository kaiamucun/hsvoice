import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  @Published private(set) var state: VoiceState = .idle
  @Published private(set) var partialTranscript = ""
  @Published private(set) var audioLevel = 0.0
  @Published private(set) var lastTranscript = ""
  @Published private(set) var lastOutcome: TextInsertionOutcome?
  @Published private(set) var targetApplicationName: String?
  @Published private(set) var shortcutAvailable = true
  @Published private(set) var recordingDuration: TimeInterval = 0
  @Published private(set) var lastErrorMessage: String?
  @Published private(set) var canUndoLastInsertion = false

  let settings = SettingsStore.shared
  let permissions = PermissionsManager.shared
  let history = HistoryStore.shared

  private let hotKeyManager = GlobalHotKeyManager()
  private let transcriber = SpeechTranscriber()
  private let insertionService = TextInsertionService()
  private var target: AppTarget?
  private var resetWorkItem: DispatchWorkItem?
  private var undoExpiryWorkItem: DispatchWorkItem?
  private var recordingTimer: Timer?
  private var lastInsertionTarget: AppTarget?
  private var hasStartedServices = false
  private var recordingContext: RecordingContext?
  private var cancellables: Set<AnyCancellable> = []
  private var escapeMonitors: [Any] = []

  private struct RecordingContext {
    let localeIdentifier: String
    let spokenFormattingCommands: Bool
    let keepHistory: Bool
  }

  func startServices() {
    guard !hasStartedServices else { return }
    hasStartedServices = true
    permissions.refresh()
    restoreAutomaticInsertionIfAvailable()
    hotKeyManager.onPressed = { [weak self] in self?.handleShortcutPressed() }
    hotKeyManager.onReleased = { [weak self] in self?.handleShortcutReleased() }
    shortcutAvailable = hotKeyManager.register(settings.shortcutChoice)
    observeLanguageChanges()
    OverlayWindowController.shared.show()
  }

  /// Keeps a recognizer for the selected language ready before the key is pressed.
  ///
  /// `@Published` replays the current value on subscribe, so this covers both the
  /// initial language and every later switch from the menu bar or settings.
  private func observeLanguageChanges() {
    settings.$localeIdentifier
      .removeDuplicates()
      .sink { [weak self] identifier in
        Task { @MainActor in
          guard let self, self.permissions.canTranscribe else { return }
          self.transcriber.prewarm(
            localeIdentifier: identifier,
            includeAnalyzer: self.settings.useAnalyzerEngine
          )
        }
      }
      .store(in: &cancellables)

    // Turning the high-accuracy engine on should immediately fetch its model,
    // so the very next dictation can already use it.
    settings.$useAnalyzerEngine
      .removeDuplicates()
      .filter { $0 }
      .sink { [weak self] _ in
        Task { @MainActor in
          guard let self, self.permissions.canTranscribe else { return }
          self.transcriber.prewarm(localeIdentifier: self.settings.localeIdentifier)
        }
      }
      .store(in: &cancellables)
  }

  func setShortcut(_ shortcut: ShortcutChoice) {
    guard state.allowsConfigurationChanges else { return }
    settings.shortcutChoice = shortcut
    shortcutAvailable = hotKeyManager.register(shortcut)
  }

  func setInsertionMode(_ mode: InsertionMode) {
    guard state.allowsConfigurationChanges else { return }
    settings.setInsertionMode(mode)
  }

  func handleShortcutPressed() {
    switch settings.activationMode {
    case .hold:
      beginListeningIfPossible()
    case .toggle:
      toggleListening()
    }
  }

  func handleShortcutReleased() {
    guard settings.activationMode == .hold, state == .listening else { return }
    stopListening()
  }

  func toggleListening() {
    switch state {
    case .listening:
      stopListening()
    case .idle, .success, .error:
      beginListeningIfPossible()
    case .requestingPermission, .processing:
      break
    }
  }

  func cancelListening() {
    guard state == .listening || state == .processing else { return }
    removeEscapeMonitors()
    transcriber.cancel()
    stopRecordingTimer(resetDuration: true)
    partialTranscript = ""
    audioLevel = 0
    target = nil
    targetApplicationName = nil
    recordingContext = nil
    state = .idle
  }

  func copyLastTranscript() {
    guard !lastTranscript.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(lastTranscript, forType: .string)
    showTransientSuccess("クリップボードにコピーしました")
  }

  func repeatLastTranscript() {
    insertText(lastTranscript)
  }

  /// Inserts arbitrary text (the last transcript, or a history entry) into the
  /// most recent external application, honoring the current insertion mode.
  func insertText(_ text: String) {
    guard !text.isEmpty, !state.isBusy else { return }
    resetWorkItem?.cancel()
    expireUndoAvailability()

    let insertionTarget =
      settings.insertionMode == .automatic ? insertionService.currentTarget() : nil
    state = .processing
    Task {
      let outcome = await insertionService.insert(text, into: insertionTarget)
      finishInsertion(outcome, target: insertionTarget)
    }
  }

  func undoLastInsertion() {
    guard canUndoLastInsertion, !state.isBusy else { return }
    resetWorkItem?.cancel()
    let didUndo = insertionService.undo(in: lastInsertionTarget)
    expireUndoAvailability()

    if didUndo {
      showTransientSuccess("直前の入力を取り消しました")
    } else {
      showError("入力先が変わったため取り消せませんでした")
      scheduleReset(after: Timing.recoverableErrorResetDelay)
    }
  }

  func copyDiagnostics() {
    permissions.refresh()
    let report = DiagnosticsReport.make(
      settings: settings,
      permissions: permissions,
      shortcutAvailable: shortcutAvailable,
      lastError: lastErrorMessage,
      lastEngine: transcriber.lastUsedEngine?.rawValue
    )
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(report, forType: .string)
    showTransientSuccess("診断情報をコピーしました")
  }

  func showOnboarding() {
    OnboardingWindowController.shared.show()
  }

  func showHistory() {
    HistoryWindowController.shared.show()
  }

  func requestPermissions() async {
    state = .requestingPermission
    await permissions.requestTranscriptionPermissions()
    permissions.refresh()

    if permissions.canTranscribe {
      prewarmRecognizerIfPossible()
      state = .idle
      if settings.insertionMode == .automatic && !permissions.canInsertText {
        requestAutomaticInsertionPermission()
      }
      _ = completeOnboardingIfReady()
    } else {
      showError("マイクと音声認識の許可が必要です")
    }
  }

  func requestAutomaticInsertionPermission() {
    settings.setInsertionMode(.automatic)
    if !permissions.requestAccessibility(prompt: true) {
      permissions.openAccessibilitySettings()
    }
    refreshPermissions()
    _ = completeOnboardingIfReady()
  }

  func useClipboardOnlyAndCompleteOnboarding() {
    guard permissions.canTranscribe else { return }
    settings.useClipboardOnlyAsPermissionFallback()
    completeOnboarding()
  }

  @discardableResult
  func completeOnboardingIfReady() -> Bool {
    guard !settings.completedOnboarding, permissions.canTranscribe else { return false }
    guard settings.insertionMode == .clipboardOnly || permissions.canInsertText else {
      return false
    }
    completeOnboarding()
    return true
  }

  func completeOnboarding() {
    settings.completedOnboarding = true
    OnboardingWindowController.shared.close()
  }

  func refreshPermissions() {
    permissions.refresh()
    restoreAutomaticInsertionIfAvailable()
    // On a first run the language subscription fires before the user has granted
    // anything, so this is what actually warms the recognizer for the very first
    // dictation after onboarding.
    prewarmRecognizerIfPossible()
    if settings.shortcutChoice == .functionKey, state.allowsConfigurationChanges {
      shortcutAvailable = hotKeyManager.register(settings.shortcutChoice)
    }
    objectWillChange.send()
  }

  /// Lightweight variant for the 1-second poll while a permissions screen is
  /// visible: re-reads authorization state without re-registering the global
  /// shortcut (tearing the fn event tap down every second would reset its
  /// confirmed state and its low-power watchdog).
  func refreshPermissionStatus() {
    permissions.refresh()
    restoreAutomaticInsertionIfAvailable()
    _ = completeOnboardingIfReady()
  }

  private func prewarmRecognizerIfPossible() {
    guard permissions.canTranscribe else { return }
    transcriber.prewarm(
      localeIdentifier: settings.localeIdentifier,
      includeAnalyzer: settings.useAnalyzerEngine
    )
  }

  private func restoreAutomaticInsertionIfAvailable() {
    _ = settings.restoreAutomaticInsertionIfPermissionGranted(permissions.canInsertText)
  }

  private func beginListeningIfPossible() {
    guard !state.isBusy else { return }
    resetWorkItem?.cancel()
    expireUndoAvailability()
    permissions.refresh()

    guard permissions.canTranscribe else {
      showOnboarding()
      Task {
        await requestPermissions()
      }
      return
    }

    target = settings.insertionMode == .automatic ? insertionService.currentTarget() : nil
    targetApplicationName = target?.displayName
    partialTranscript = ""
    audioLevel = 0
    recordingDuration = 0
    lastOutcome = nil
    recordingContext = RecordingContext(
      localeIdentifier: settings.localeIdentifier,
      spokenFormattingCommands: settings.spokenFormattingCommands,
      keepHistory: settings.keepHistory
    )
    state = .listening
    OverlayWindowController.shared.show()

    do {
      try transcriber.start(
        localeIdentifier: settings.localeIdentifier,
        vocabulary: settings.vocabularyTerms,
        preferOnDevice: settings.preferOnDevice,
        useAnalyzerEngine: settings.useAnalyzerEngine,
        onPartial: { [weak self] text in
          self?.partialTranscript = text
        },
        onLevel: { [weak self] level in
          self?.audioLevel = level
        },
        onCompletion: { [weak self] result in
          self?.completeTranscription(result)
        }
      )
      startRecordingTimer()
      installEscapeMonitors()
      playSoundCue(SoundCue.start)
    } catch {
      transcriber.cancel()
      stopRecordingTimer(resetDuration: true)
      recordingContext = nil
      showError(error.localizedDescription)
      OverlayWindowController.shared.show()
      scheduleReset(after: Timing.startupErrorResetDelay)
    }
  }

  private func stopListening() {
    guard state == .listening else { return }
    removeEscapeMonitors()
    stopRecordingTimer()
    state = .processing
    audioLevel = 0
    playSoundCue(SoundCue.stop)
    transcriber.finish()
  }

  private func completeTranscription(_ result: Result<String, Error>) {
    // A session can complete while still `.listening` (recognizer error,
    // early final result), which skips `stopListening()` — the monitors must
    // never outlive the recording.
    removeEscapeMonitors()
    stopRecordingTimer()
    guard let recordingContext else { return }
    self.recordingContext = nil
    if state == .listening {
      state = .processing
      audioLevel = 0
    }

    switch result {
    case .success(let rawText):
      let text = TextPostProcessor.process(
        rawText,
        localeIdentifier: recordingContext.localeIdentifier,
        spokenCommandsEnabled: recordingContext.spokenFormattingCommands
      )
      guard !text.isEmpty else {
        showError("音声を認識できませんでした")
        scheduleReset(after: Timing.recoverableErrorResetDelay)
        return
      }

      partialTranscript = text
      lastTranscript = text
      if recordingContext.keepHistory {
        history.add(
          HistoryEntry(
            text: text,
            applicationName: targetApplicationName,
            localeIdentifier: recordingContext.localeIdentifier
          )
        )
      }

      Task {
        let outcome = await insertionService.insert(text, into: target)
        finishInsertion(outcome, target: target)
      }

    case .failure(let error):
      showError(readableRecognitionError(error))
      scheduleReset(after: Timing.recognitionErrorResetDelay)
    }
  }

  private func readableRecognitionError(_ error: Error) -> String {
    let message = error.localizedDescription
    if message.lowercased().contains("network") {
      return "音声認識サービスに接続できません"
    }
    return message.isEmpty ? "音声認識を完了できませんでした" : message
  }

  private func finishInsertion(_ outcome: TextInsertionOutcome, target: AppTarget?) {
    var outcome = outcome
    // The service reports .copiedOnly when it had no target to type into, but in
    // automatic mode with the Accessibility grant missing the real story is the
    // permission — surface that instead of a quiet "copied".
    if outcome == .copiedOnly, settings.insertionMode == .automatic,
      !permissions.canInsertText
    {
      outcome = .copiedNoAccessibility
    }
    lastOutcome = outcome

    // Falling back to the clipboard because the Accessibility grant is not
    // actually working (the classic stale-grant trap after a rebuild) is a
    // problem the user must see, not a quiet success.
    if outcome == .copiedNoAccessibility {
      expireUndoAvailability()
      showError(outcome.message)
      scheduleReset(after: Timing.recoverableErrorResetDelay)
      return
    }

    lastErrorMessage = nil
    state = .success(outcome.message)

    if outcome == .inserted {
      makeUndoAvailable(for: target)
    } else {
      expireUndoAvailability()
    }
    scheduleReset(after: Timing.successResetDelay)
  }

  private func makeUndoAvailable(for target: AppTarget?) {
    undoExpiryWorkItem?.cancel()
    guard let target else {
      expireUndoAvailability()
      return
    }

    lastInsertionTarget = target
    canUndoLastInsertion = true
    let workItem = DispatchWorkItem { [weak self] in
      self?.expireUndoAvailability()
    }
    undoExpiryWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + RecordingLimit.undoAvailabilityDuration,
      execute: workItem
    )
  }

  private func expireUndoAvailability() {
    undoExpiryWorkItem?.cancel()
    undoExpiryWorkItem = nil
    lastInsertionTarget = nil
    canUndoLastInsertion = false
  }

  private func showTransientSuccess(_ message: String) {
    guard state.allowsConfigurationChanges else { return }
    state = .success(message)
    scheduleReset(after: Timing.successResetDelay)
  }

  private func showError(_ message: String) {
    lastErrorMessage = message
    state = .error(message)
  }

  private func startRecordingTimer() {
    stopRecordingTimer()
    let startedAt = Date()
    let timer = Timer(timeInterval: Timing.recordingTick, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickRecordingTimer(startedAt: startedAt)
      }
    }
    recordingTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  /// The safety stop is checked on every tick, but `recordingDuration` is only
  /// published when the displayed second actually changes. Assigning an
  /// `@Published` property redraws the popover and the floating indicator whether
  /// or not the value moved, and the label has one-second resolution.
  private func tickRecordingTimer(startedAt: Date) {
    guard state == .listening else { return }
    let elapsed = Date().timeIntervalSince(startedAt)

    if Int(elapsed) != Int(recordingDuration) {
      recordingDuration = elapsed
    }

    if elapsed >= RecordingLimit.maximumDuration {
      recordingDuration = elapsed
      stopListening()
    }
  }

  private func stopRecordingTimer(resetDuration: Bool = false) {
    recordingTimer?.invalidate()
    recordingTimer = nil
    if resetDuration {
      recordingDuration = 0
    }
  }

  // MARK: Engine info for presentation

  /// True when this Mac's OS offers the high-accuracy SpeechAnalyzer engine.
  nonisolated var analyzerEngineSupported: Bool {
    SpeechTranscriber.analyzerEngineSupported
  }

  /// True when the high-accuracy engine can start instantly for the selected language.
  var analyzerEngineReady: Bool {
    transcriber.analyzerEngineReady(localeIdentifier: settings.localeIdentifier)
  }

  // MARK: Sound cues

  private enum SoundCue {
    static let start = "Tink"
    static let stop = "Pop"
  }

  /// Short, quiet cues confirm hands-free that recording started or stopped,
  /// matching what macOS dictation users expect. Off with one toggle.
  private func playSoundCue(_ name: String) {
    guard settings.soundFeedback else { return }
    guard let sound = NSSound(named: NSSound.Name(name)) else { return }
    sound.volume = 0.25
    sound.play()
  }

  // MARK: Escape to cancel

  /// While recording, esc discards the dictation without inserting anything.
  private func installEscapeMonitors() {
    guard escapeMonitors.isEmpty else { return }

    if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {
      [weak self] event in
      guard let self, event.keyCode == 53, self.state == .listening else { return event }
      self.cancelListening()
      return nil
    }) {
      escapeMonitors.append(local)
    }

    // The global monitor only receives events when Accessibility is granted;
    // without it, esc still works whenever HS Voice itself has focus.
    if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: {
      [weak self] event in
      guard event.keyCode == 53 else { return }
      Task { @MainActor in
        guard let self, self.state == .listening else { return }
        self.cancelListening()
      }
    }) {
      escapeMonitors.append(global)
    }
  }

  private func removeEscapeMonitors() {
    for monitor in escapeMonitors {
      NSEvent.removeMonitor(monitor)
    }
    escapeMonitors.removeAll()
  }

  private func scheduleReset(after seconds: TimeInterval) {
    resetWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.state = .idle
      self.partialTranscript = ""
      self.audioLevel = 0
      self.stopRecordingTimer(resetDuration: true)
      self.target = nil
      self.targetApplicationName = nil
      self.recordingContext = nil
    }
    resetWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
  }
}
