import AppKit
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

  private struct RecordingContext {
    let localeIdentifier: String
    let spokenFormattingCommands: Bool
    let keepHistory: Bool
  }

  var isListening: Bool { state == .listening }

  var menuBarSymbol: String {
    state.symbolName
  }

  var shortcutDisplayText: String {
    settings.shortcutChoice.displayName
  }

  var formattedRecordingDuration: String {
    let seconds = max(0, Int(recordingDuration.rounded(.down)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  var recordingProgress: Double {
    min(1, recordingDuration / RecordingLimit.maximumDuration)
  }

  var versionDisplay: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Development"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "HS Voice \(version) (\($0))" } ?? "HS Voice \(version)"
  }

  var stateDetail: String {
    switch state {
    case .idle:
      return "\(shortcutDisplayText)でどこからでも音声入力"
    case .requestingPermission:
      return "macOSの確認に応答してください"
    case .listening:
      if settings.insertionMode == .clipboardOnly {
        return "クリップボードへコピー • \(formattedRecordingDuration)"
      }
      return targetApplicationName.map { "\($0)へ入力 • \(formattedRecordingDuration)" }
        ?? "録音中 • \(formattedRecordingDuration)"
    case .processing:
      return "句読点と空白を整えています"
    case .success(let message), .error(let message):
      return message
    }
  }

  func startServices() {
    guard !hasStartedServices else { return }
    hasStartedServices = true
    permissions.refresh()
    restoreAutomaticInsertionIfAvailable()
    hotKeyManager.onPressed = { [weak self] in self?.handleShortcutPressed() }
    hotKeyManager.onReleased = { [weak self] in self?.handleShortcutReleased() }
    shortcutAvailable = hotKeyManager.register(settings.shortcutChoice)
    OverlayWindowController.shared.show()
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
    guard !lastTranscript.isEmpty, !state.isBusy else { return }
    resetWorkItem?.cancel()
    expireUndoAvailability()

    let repeatTarget =
      settings.insertionMode == .automatic ? insertionService.currentTarget() : nil
    state = .processing
    Task {
      let outcome = await insertionService.insert(lastTranscript, into: repeatTarget)
      finishInsertion(outcome, target: repeatTarget)
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
      scheduleReset(after: 2.2)
    }
  }

  func copyDiagnostics() {
    permissions.refresh()
    let report = DiagnosticsReport.make(
      settings: settings,
      permissions: permissions,
      shortcutAvailable: shortcutAvailable,
      lastError: lastErrorMessage
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
    if settings.shortcutChoice == .functionKey, state.allowsConfigurationChanges {
      shortcutAvailable = hotKeyManager.register(settings.shortcutChoice)
    }
    objectWillChange.send()
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
    } catch {
      transcriber.cancel()
      stopRecordingTimer(resetDuration: true)
      recordingContext = nil
      showError(error.localizedDescription)
      OverlayWindowController.shared.show()
      scheduleReset(after: 2.5)
    }
  }

  private func stopListening() {
    guard state == .listening else { return }
    stopRecordingTimer()
    state = .processing
    audioLevel = 0
    transcriber.finish()
  }

  private func completeTranscription(_ result: Result<String, Error>) {
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
        scheduleReset(after: 2.2)
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
      scheduleReset(after: 2.6)
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
    lastOutcome = outcome
    lastErrorMessage = nil
    state = .success(outcome.message)

    if outcome == .pasted {
      makeUndoAvailable(for: target)
    } else {
      expireUndoAvailability()
    }
    scheduleReset(after: 1.6)
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
    scheduleReset(after: 1.6)
  }

  private func showError(_ message: String) {
    lastErrorMessage = message
    state = .error(message)
  }

  private func startRecordingTimer() {
    stopRecordingTimer()
    let startedAt = Date()
    let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.state == .listening else { return }
        self.recordingDuration = Date().timeIntervalSince(startedAt)
        if self.recordingDuration >= RecordingLimit.maximumDuration {
          self.stopListening()
        }
      }
    }
    recordingTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func stopRecordingTimer(resetDuration: Bool = false) {
    recordingTimer?.invalidate()
    recordingTimer = nil
    if resetDuration {
      recordingDuration = 0
    }
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
