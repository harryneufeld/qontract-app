import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    receive(connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let links = Set(URLContexts.filter { !$0.url.isFileURL })
    if !links.isEmpty { super.scene(scene, openURLContexts: links) }
    receive(URLContexts)
  }

  private func receive(_ contexts: Set<UIOpenURLContext>) {
    let urls = contexts.map { $0.url }.filter { $0.isFileURL }
    guard !urls.isEmpty else { return }
    DispatchQueue.global(qos: .userInitiated).async {
      for url in urls {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { try DocumentInbox.add(url) }
        catch {
          DispatchQueue.main.async {
            let alert = UIAlertController(title: "Could not import document", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.window?.rootViewController?.present(alert, animated: true)
          }
        }
      }
      DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("QontractInboxChanged"), object: nil) }
    }
  }
}
