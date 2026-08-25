import Foundation

@MainActor
final class HistoryStore: ObservableObject {
  static let shared = HistoryStore()

  @Published private(set) var entries: [HistoryEntry] = []

  private let storageURL: URL
  private let fileManager: FileManager
  private let maximumEntries: Int

  init(
    storageURL: URL? = nil,
    fileManager: FileManager = .default,
    maximumEntries: Int = 100
  ) {
    self.fileManager = fileManager
    self.maximumEntries = maximumEntries
    if let storageURL {
      self.storageURL = storageURL
    } else {
      let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      self.storageURL =
        base
        .appendingPathComponent("HS Voice", isDirectory: true)
        .appendingPathComponent("history.json")
    }
    load()
  }

  func add(_ entry: HistoryEntry) {
    entries.insert(entry, at: 0)
    if entries.count > maximumEntries {
      entries.removeLast(entries.count - maximumEntries)
    }
    save()
  }

  func remove(id: UUID) {
    entries.removeAll { $0.id == id }
    save()
  }

  func clear() {
    entries = []
    save()
  }

  private func load() {
    guard let data = try? Data(contentsOf: storageURL),
      let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
    else {
      entries = []
      return
    }
    entries = Array(decoded.prefix(maximumEntries))
  }

  private func save() {
    do {
      try fileManager.createDirectory(
        at: storageURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(entries)
      try data.write(to: storageURL, options: .atomic)
    } catch {
      NSLog("HS Voice: history could not be saved: %@", error.localizedDescription)
    }
  }
}
