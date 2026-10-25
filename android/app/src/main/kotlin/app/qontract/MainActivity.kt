package app.qontract

import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private lateinit var imports: DocumentImportBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imports = DocumentImportBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The original intent is already persisted after a configuration restart.
        if (savedInstanceState == null) imports.receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
        imports.receive(intent)
    }

    // Content URLs identify documents, rather than Flutter navigation routes.
    override fun shouldHandleDeeplinking(): Boolean =
        intent?.data?.scheme != "content" && super.shouldHandleDeeplinking()

    override fun onDestroy() {
        if (::imports.isInitialized) imports.close()
        super.onDestroy()
    }
}
