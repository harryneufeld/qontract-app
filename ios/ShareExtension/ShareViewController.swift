import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let status = UILabel()
  private let done = UIButton(type: .system)
  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    status.numberOfLines = 0
    status.textAlignment = .center
    status.text = "Saving documents to qontract…"
    done.setTitle("Done", for: .normal)
    done.isEnabled = false
    done.addTarget(self, action: #selector(finish), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [status, done])
    stack.axis = .vertical
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
    ])
    guard !started else { return }
    started = true
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
    save(providers, index: 0, count: 0, errors: [])
  }

  private func save(_ providers: [NSItemProvider], index: Int, count: Int, errors: [String]) {
    guard index < providers.count else {
      DispatchQueue.main.async {
        self.status.text = (count > 0 ? "Saved \(count) document(s). Open qontract to find a contract and review where to save them." : "No documents were saved.") +
          (errors.isEmpty ? "" : "\n\n" + errors.joined(separator: "\n"))
        self.done.isEnabled = true
      }
      return
    }
    let provider = providers[index]
    guard let type = provider.registeredTypeIdentifiers.first(where: {
      guard let type = UTType($0) else { return false }
      return type.conforms(to: .pdf) || type.conforms(to: .image)
    }) else {
      save(providers, index: index + 1, count: count, errors: errors + ["Choose a PDF or image."])
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
      var nextErrors = errors
      var nextCount = count
      do {
        guard let url = url else { throw error ?? DocumentImportError.message("Could not read the shared document.") }
        // The provider's temporary URL is valid only inside this callback.
        let suggested = provider.suggestedName
        let name = suggested.map { ($0 as NSString).pathExtension.isEmpty ? $0 + "." + (UTType(type)?.preferredFilenameExtension ?? url.pathExtension) : $0 }
        try DocumentInbox.add(url, suggestedName: name)
        nextCount += 1
      } catch { nextErrors.append(error.localizedDescription) }
      self.save(providers, index: index + 1, count: nextCount, errors: nextErrors)
    }
  }

  @objc private func finish() { extensionContext?.completeRequest(returningItems: nil) }
}
