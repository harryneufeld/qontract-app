import Flutter
import ImageIO
import PDFKit
import UIKit
import Vision

final class DocumentImportBridge {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "qontract.document-import")
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "qontract/document_import", binaryMessenger: messenger)
    observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("QontractInboxChanged"), object: nil, queue: .main) { [weak self] _ in
      self?.channel.invokeMethod("inboxChanged", arguments: nil)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      self.queue.async {
        do {
          let args = call.arguments as? [String: Any] ?? [:]
          let value: Any?
          switch call.method {
          case "pending":
            value = try DocumentInbox.entries().map { ["id": $0.lastPathComponent, "name": try DocumentInbox.name($0)] }
          case "read":
            let entry = try DocumentInbox.entry(args["id"] as? String ?? "")
            let content = entry.appendingPathComponent("content")
            let size = try content.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 && size <= DocumentInbox.maxBytes else { throw DocumentImportError.message("Invalid document size.") }
            value = ["name": try DocumentInbox.name(entry), "bytes": FlutterStandardTypedData(bytes: try Data(contentsOf: content))]
          case "discard":
            let entry = try DocumentInbox.entry(args["id"] as? String ?? "")
            if FileManager.default.fileExists(atPath: entry.path) { try FileManager.default.removeItem(at: entry) }
            value = nil
          case "recognize":
            guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data,
                  !data.isEmpty, data.count <= DocumentInbox.maxBytes else {
              throw DocumentImportError.message("Choose a non-empty document up to 20 MB.")
            }
            value = try self.recognize(data, name: args["name"] as? String ?? "")
          default:
            DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
            return
          }
          DispatchQueue.main.async { result(value) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "document_import", message: error.localizedDescription, details: nil)) }
        }
      }
    }
  }

  private func readText(_ image: CGImage) throws -> [String: Any] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US", "de-DE"]
    try VNImageRequestHandler(cgImage: image).perform([request])
    let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
      guard let text = observation.topCandidates(1).first?.string else { return nil }
      return ["text": text, "top": 1 - observation.boundingBox.maxY, "left": observation.boundingBox.minX, "height": observation.boundingBox.height]
    }
    return ["text": lines.compactMap { $0["text"] as? String }.joined(separator: "\n"), "lines": lines]
  }

  private func embeddedText(_ page: PDFPage, text: String) -> [String: Any] {
    let bounds = page.bounds(for: .mediaBox)
    guard bounds.height > 0, bounds.width > 0, page.rotation == 0 else { return ["text": text] }
    let attributed = page.attributedString
    var lines: [[String: Any]] = []
    text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { value, stringRange, _, _ in
      let range = NSRange(stringRange, in: text)
      guard let value = value, let selection = page.selection(for: range) else { return }
      let box = selection.bounds(for: page)
      var bold = false
      if let attributed = attributed, NSMaxRange(range) <= attributed.length {
        attributed.enumerateAttribute(.font, in: range) { font, _, _ in
          if let font = font as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) { bold = true }
        }
      }
      lines.append(["text": value, "top": (bounds.maxY - box.maxY) / bounds.height,
                    "left": (box.minX - bounds.minX) / bounds.width, "height": box.height / bounds.height, "isBold": bold])
    }
    return ["text": text, "lines": lines]
  }

  private func recognize(_ data: Data, name: String) throws -> [String: Any] {
    if name.lowercased().hasSuffix(".pdf") || data.starts(with: Data("%PDF-".utf8)) {
      guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else {
        throw DocumentImportError.message("This PDF cannot be read or requires a password.")
      }
      return try autoreleasepool { () throws -> [String: Any] in
          guard let page = pdf.page(at: 0) else { return ["text": ""] }
          // Existing text is faster and preserves exact identifiers.
          if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return self.embeddedText(page, text: text) }
          let bounds = page.bounds(for: .mediaBox)
          let longest = max(bounds.width, bounds.height)
          guard longest > 0 else { return ["text": ""] }
          let scale = min(3, 2200 / longest)
          let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          format.opaque = true
          let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: context.cgContext)
          }
          guard let cgImage = image.cgImage else { return ["text": ""] }
          return try self.readText(cgImage)
        }
    }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000
          ] as CFDictionary) else { throw DocumentImportError.message("This image format could not be read. Try JPEG or PNG.") }
    return try readText(image)
  }

  deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }
}
