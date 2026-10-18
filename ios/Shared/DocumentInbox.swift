import Foundation

enum DocumentImportError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self { case .message(let value): return value }
  }
}

/// Shared by the app and its share extension; contains no credentials or OCR.
enum DocumentInbox {
  static let maxBytes = 20 * 1024 * 1024

  static func root() throws -> URL {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "QontractAppGroup") as? String,
          let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
      throw DocumentImportError.message("Shared document storage is unavailable. Check the App Group entitlement.")
    }
    let root = container.appendingPathComponent("DocumentInbox", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  static func entries() throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: root(), includingPropertiesForKeys: nil)
      .filter { !$0.lastPathComponent.hasPrefix(".") &&
        FileManager.default.fileExists(atPath: $0.appendingPathComponent("metadata.json").path) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  static func entry(_ id: String) throws -> URL {
    guard UUID(uuidString: id) != nil else { throw DocumentImportError.message("Invalid shared document.") }
    return try root().appendingPathComponent(id, isDirectory: true)
  }

  static func name(_ entry: URL) throws -> String {
    let data = try Data(contentsOf: entry.appendingPathComponent("metadata.json"))
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
          let name = json["name"] else { throw DocumentImportError.message("Invalid shared document.") }
    return name
  }

  static func add(_ source: URL, suggestedName: String? = nil) throws {
    guard try entries().count < 10 else { throw DocumentImportError.message("The inbox holds 10 files. Review or discard documents in qontract first.") }
    let values = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= maxBytes else {
      throw DocumentImportError.message("Choose a non-empty PDF or image up to 20 MB.")
    }
    let id = UUID().uuidString
    let root = try root()
    let staging = root.appendingPathComponent(".staging-\(id)", isDirectory: true)
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }
    try FileManager.default.copyItem(at: source, to: staging.appendingPathComponent("content"))
    let original = suggestedName ?? source.lastPathComponent
    let name = String(original.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last ?? "document")
    let data = try JSONSerialization.data(withJSONObject: ["name": String(name.prefix(200))])
    try data.write(to: staging.appendingPathComponent("metadata.json"), options: .atomic)
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: staging.path)
    try FileManager.default.moveItem(at: staging, to: root.appendingPathComponent(id, isDirectory: true))
  }
}
