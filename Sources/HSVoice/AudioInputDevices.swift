import AVFoundation
import CoreAudio
import Foundation

/// A microphone (or any device with input channels) as seen by CoreAudio.
struct AudioInputDevice: Identifiable, Equatable, Hashable {
  let id: AudioDeviceID
  /// Stable across reboots and re-plugs, unlike the numeric ID — this is what
  /// the settings store keeps.
  let uid: String
  let name: String
}

/// Enumerates input devices and points an `AVAudioEngine` at the chosen one.
enum AudioInputDevices {

  static func available() -> [AudioInputDevice] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    let system = AudioObjectID(kAudioObjectSystemObject)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0
    else { return [] }
    var identifiers = [AudioDeviceID](
      repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &identifiers) == noErr
    else { return [] }

    return identifiers.compactMap { identifier in
      guard inputChannelCount(of: identifier) > 0,
        let uid = string(kAudioDevicePropertyDeviceUID, of: identifier),
        let name = string(kAudioObjectPropertyName, of: identifier)
      else { return nil }
      return AudioInputDevice(id: identifier, uid: uid, name: name)
    }
  }

  static func defaultInputDeviceID() -> AudioDeviceID? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var identifier: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &identifier)
    guard status == noErr, identifier != 0 else { return nil }
    return identifier
  }

  static func device(forUID uid: String) -> AudioInputDevice? {
    available().first { $0.uid == uid }
  }

  /// Routes the engine's input to the preferred device, or to the system
  /// default when none is preferred or the preferred one is unplugged.
  ///
  /// Must run before the tap is installed and before the input format is read:
  /// the format follows the device. Returns false when CoreAudio refused.
  @discardableResult
  static func apply(preferredUID: String?, to engine: AVAudioEngine) -> Bool {
    guard let unit = engine.inputNode.audioUnit else { return false }
    let preferred = preferredUID.flatMap { device(forUID: $0)?.id }
    guard var deviceID = preferred ?? defaultInputDeviceID() else { return false }
    let status = AudioUnitSetProperty(
      unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
      &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
    return status == noErr
  }

  private static func inputChannelCount(of identifier: AudioDeviceID) -> Int {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: kAudioObjectPropertyScopeInput,
      mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(identifier, &address, 0, nil, &size) == noErr, size > 0
    else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
    guard AudioObjectGetPropertyData(identifier, &address, 0, nil, &size, list) == noErr
    else { return 0 }
    return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
  }

  private static func string(
    _ selector: AudioObjectPropertySelector, of identifier: AudioDeviceID
  ) -> String? {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    var value: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    guard AudioObjectGetPropertyData(identifier, &address, 0, nil, &size, &value) == noErr
    else { return nil }
    let result = value as String
    return result.isEmpty ? nil : result
  }
}

/// Short live level meter for the microphone "Test" button in settings.
///
/// Runs its own engine so it never interferes with a dictation, and stops
/// itself after `duration` so a forgotten test cannot keep the mic open.
@MainActor
final class MicrophoneLevelProbe: ObservableObject {
  static let duration: TimeInterval = 6

  @Published private(set) var level: Double = 0
  @Published private(set) var isRunning = false
  @Published private(set) var errorMessage: String?

  private var engine: AVAudioEngine?
  private var stopTask: Task<Void, Never>?

  func start(preferredUID: String?) {
    stop()
    let engine = AVAudioEngine()
    AudioInputDevices.apply(preferredUID: preferredUID, to: engine)
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      errorMessage = L.t(
        "マイクの入力形式を取得できませんでした。", "Couldn't read the microphone's input format.",
        "无法获取麦克风的输入格式。", "마이크 입력 형식을 가져오지 못했습니다.")
      return
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      let value = AudioLevelMeter.normalizedLevel(from: buffer)
      Task { @MainActor in
        guard let self, self.isRunning else { return }
        // Quick attack, slow release, so the bar is readable rather than jittery.
        self.level = max(value, self.level * 0.85)
      }
    }
    do {
      engine.prepare()
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      errorMessage = error.localizedDescription
      return
    }
    self.engine = engine
    errorMessage = nil
    isRunning = true
    stopTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(Self.duration * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.stop()
    }
  }

  func stop() {
    stopTask?.cancel()
    stopTask = nil
    if let engine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    engine = nil
    isRunning = false
    level = 0
  }
}
