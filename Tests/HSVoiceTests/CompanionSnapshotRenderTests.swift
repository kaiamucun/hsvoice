import AppKit
import Foundation
import SwiftUI
import XCTest

@testable import HSVoice

/// Throwaway visual check: writes PNGs of the companion UI when
/// HSVOICE_SNAPSHOT_DIR is set. Skipped otherwise.
@MainActor
final class CompanionSnapshotRenderTests: XCTestCase {
  private var outputDirectory: URL? {
    ProcessInfo.processInfo.environment["HSVOICE_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
  }

  /// Pure SwiftUI content (no AppKit controls, no lazy containers).
  private func write<V: View>(_ view: V, name: String, scale: CGFloat = 2) throws {
    guard let outputDirectory else { throw XCTSkip("HSVOICE_SNAPSHOT_DIR not set") }
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let image = renderer.nsImage,
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else {
      XCTFail("could not render \(name)")
      return
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
  }

  /// Full AppKit-hosted layout, so text fields, buttons and lazy grids draw.
  private func writeHosted<V: View>(_ view: V, size: CGSize, name: String) throws {
    guard let outputDirectory else { throw XCTSkip("HSVOICE_SNAPSHOT_DIR not set") }
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    _ = NSApplication.shared
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    let hosting = NSHostingView(rootView: view)
    hosting.frame = CGRect(origin: .zero, size: size)
    window.contentView = hosting
    for _ in 0..<6 { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
    hosting.layoutSubtreeIfNeeded()
    guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
      XCTFail("no bitmap for \(name)")
      return
    }
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
      XCTFail("no png for \(name)")
      return
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    window.close()
  }

  private static func outfit(wearing item: CompanionItem) -> CompanionOutfit {
    var outfit = CompanionOutfit.default
    outfit.set(item.id, for: item.category)
    return outfit
  }

  func testRenderSpriteCatalog() throws {
    guard outputDirectory != nil else { throw XCTSkip("HSVOICE_SNAPSHOT_DIR not set") }
    L.current = .japanese
    let hats = CompanionCatalog.items(in: .hat)
    let faces = CompanionCatalog.items(in: .face)
    let held = CompanionCatalog.items(in: .held)
    let colors = CompanionCatalog.items(in: .color)

    let view = VStack(alignment: .leading, spacing: 12) {
      ForEach([hats, faces, held, colors], id: \.first!.id) { group in
        HStack(spacing: 8) {
          ForEach(group) { item in
            VStack(spacing: 2) {
              CompanionSpriteView(outfit: Self.outfit(wearing: item), animated: false, size: 96)
              Text(item.name).font(.system(size: 9))
            }
          }
        }
      }
      HStack(spacing: 8) {
        CompanionSpriteView(outfit: .default, listening: true, animated: false, size: 96)
        ForEach(hats.prefix(6)) { item in
          CompanionItemThumbnail(item: item, size: 56)
        }
      }
    }
    .padding(16)
    .background(Color.white)
    try write(view, name: "sprites")
  }

  func testRenderCompanionWindow() throws {
    guard outputDirectory != nil else { throw XCTSkip("HSVOICE_SNAPSHOT_DIR not set") }
    L.current = .japanese
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let usage = UsageStatsStore(storageURL: directory.appendingPathComponent("usage.json"))
    // A few weeks of use so the window has something to show.
    var day = Date().addingTimeInterval(-20 * 86_400)
    for index in 0..<20 {
      usage.recordDictation(
        characters: 400 + index * 37,
        applicationName: ["Notes", "Slack", "Mail", "Safari", "Pages"][index % 5],
        localeIdentifier: index % 3 == 0 ? "en-US" : "ja-JP", at: day)
      day = day.addingTimeInterval(86_400)
    }
    usage.recordDictation(characters: 874, applicationName: "Notes", localeIdentifier: "ja-JP")

    let suiteName = "HSVoiceTests.snapshot.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = SettingsStore(defaults: defaults)
    settings.companionName = "ぷにたろう"
    settings.wearCompanionItem("partyHat", for: .hat)
    settings.wearCompanionItem("microphone", for: .held)

    let state = CompanionState(settings: settings, usage: usage)
    XCTAssertGreaterThan(state.progress.level, 1)

    try writeHosted(
      CompanionMenuRow(model: .shared, settings: settings, usage: usage)
        .padding(18).background(Color(nsColor: .windowBackgroundColor)),
      size: CGSize(width: 392, height: 100), name: "menu-row")
    try writeHosted(
      CompanionView(model: .shared, settings: settings, usage: usage),
      size: CGSize(width: 900, height: 680), name: "window-seeded")

    let fresh = UsageStatsStore(storageURL: directory.appendingPathComponent("fresh.json"))
    let freshSettings = SettingsStore(defaults: UserDefaults(suiteName: suiteName + ".fresh")!)
    try writeHosted(
      CompanionView(model: .shared, settings: freshSettings, usage: fresh),
      size: CGSize(width: 900, height: 680), name: "window-fresh")
    try writeHosted(
      CompanionSettingsPage(model: .shared).frame(width: 640),
      size: CGSize(width: 640, height: 560), name: "settings-page")
  }
}
