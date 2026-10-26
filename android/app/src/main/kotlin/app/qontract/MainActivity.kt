package app.qontract

import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private lateinit var imports: DocumentImportBridge

    // The fragment activity configures the engine after onCreate, so an intent
    // that arrives earlier waits here until the bridge exists.
    private var pendingIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imports = DocumentImportBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        pendingIntent?.let { imports.receive(it) }
        pendingIntent = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The original intent is already persisted after a configuration restart.
        if (savedInstanceState == null) deliver(intent)
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
        deliver(intent)
    }

    private fun deliver(intent: Intent?) {
        if (::imports.isInitialized) imports.receive(intent) else pendingIntent = intent
    }

    // Content URLs identify documents, rather than Flutter navigation routes.
    override fun shouldHandleDeeplinking(): Boolean =
        intent?.data?.scheme != "content" && super.shouldHandleDeeplinking()

    override fun onDestroy() {
        if (::imports.isInitialized) imports.close()
        super.onDestroy()
    }
}
