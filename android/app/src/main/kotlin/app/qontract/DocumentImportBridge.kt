package app.qontract

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.widget.Toast
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.roundToInt

class DocumentImportBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "qontract/document_import")
    private val worker = Executors.newSingleThreadExecutor()
    private val inbox = File(activity.filesDir, "document-inbox").apply { mkdirs() }
    private val maxBytes = 20 * 1024 * 1024

    init {
        // Retain only completed entries after an interrupted copy.
        inbox.listFiles()?.filter { it.name.startsWith(".staging-") }?.forEach { it.deleteRecursively() }
        channel.setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    val value: Any? = when (call.method) {
                        "pending" -> entries().map { entry ->
                            mapOf("id" to entry.name, "name" to metadata(entry).getString("name"))
                        }
                        "read" -> {
                            val entry = entry(call.argument<String>("id"))
                            val bytes = File(entry, "content").readBytes()
                            require(bytes.isNotEmpty() && bytes.size <= maxBytes) { "Invalid document size." }
                            mapOf("name" to metadata(entry).getString("name"), "bytes" to bytes)
                        }
                        "discard" -> { entry(call.argument<String>("id")).deleteRecursively(); null }
                        "recognize" -> recognize(call.argument<String>("name") ?: "document",
                            call.argument<ByteArray>("bytes") ?: byteArrayOf())
                        else -> { activity.runOnUiThread { result.notImplemented() }; return@execute }
                    }
                    activity.runOnUiThread { result.success(value) }
                } catch (e: Exception) {
                    activity.runOnUiThread { result.error("document_import", e.message ?: "Could not read document.", null) }
                }
            }
        }
    }

    private fun entries() = inbox.listFiles()?.filter { !it.name.startsWith(".") &&
        File(it, "metadata.json").isFile && File(it, "content").isFile }?.sortedBy { it.lastModified() } ?: emptyList()
    private fun metadata(entry: File) = JSONObject(File(entry, "metadata.json").readText())
    private fun entry(id: String?): File {
        require(id != null && Regex("[a-f0-9-]{36}").matches(id)) { "Invalid inbox document." }
        return File(inbox, id).also { require(it.isDirectory) { "Document is no longer available." } }
    }

    @Suppress("DEPRECATION")
    fun receive(intent: Intent?) {
        val uris: List<Uri> = when (intent?.action) {
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri)
            Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                ?: (0 until (intent.clipData?.itemCount ?: 0)).mapNotNull { intent.clipData?.getItemAt(it)?.uri }
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            else -> return
        }
        worker.execute {
            var errors = 0
            uris.forEach { uri ->
                try { copyShared(uri) } catch (_: Exception) { errors++ }
            }
            activity.runOnUiThread {
                if (errors > 0) Toast.makeText(activity,
                    "Some files could not be imported. Share a PDF or image up to 20 MB; the inbox holds 10 files.", Toast.LENGTH_LONG).show()
                channel.invokeMethod("inboxChanged", null)
            }
        }
    }

    private fun copyShared(uri: Uri) {
        require(uri.scheme == "content") { "Only shared content is supported." }
        require(entries().size < 10) { "Inbox is full." }
        val resolver = activity.contentResolver
        val mime = resolver.getType(uri) ?: ""
        require(mime == "application/pdf" || mime.startsWith("image/")) { "Choose a PDF or image." }
        var name = if (mime == "application/pdf") "document.pdf" else "image.jpg"
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: name
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) require(cursor.getLong(sizeIndex) <= maxBytes) { "File exceeds 20 MB." }
            }
        }
        name = name.substringAfterLast('/').substringAfterLast('\\').take(200).ifBlank { "document" }
        val id = UUID.randomUUID().toString()
        val staging = File(inbox, ".staging-$id").apply { mkdirs() }
        try {
            resolver.openInputStream(uri).use { input ->
                requireNotNull(input) { "Cannot read shared file." }
                File(staging, "content").outputStream().use { output ->
                    val buffer = ByteArray(65536)
                    var total = 0
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= maxBytes) { "File exceeds 20 MB." }
                        output.write(buffer, 0, count)
                    }
                    require(total > 0) { "File is empty." }
                }
            }
            File(staging, "metadata.json").writeText(JSONObject().put("name", name).toString())
            require(staging.renameTo(File(inbox, id))) { "Could not retain shared file." }
        } finally { if (staging.exists()) staging.deleteRecursively() }
    }

    private fun recognize(name: String, bytes: ByteArray): Map<String, Any?> {
        require(bytes.isNotEmpty() && bytes.size <= maxBytes) { "Choose a non-empty document up to 20 MB." }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val temporary = File.createTempFile("ocr-", ".data", activity.cacheDir)
        try {
            temporary.writeBytes(bytes)
            val isPdf = bytes.take(5).toByteArray().contentEquals("%PDF-".toByteArray())
            if (name.endsWith(".pdf", true) || isPdf) {
                ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                    PdfRenderer(fd).use { pdf ->
                        require(pdf.pageCount > 0) { "The PDF is empty." }
                        // Read only the first page; retain the original bytes for upload.
                        pdf.openPage(0).use { page ->
                            val scale = minOf(3.0, 2200.0 / max(page.width, page.height))
                            val bitmap = Bitmap.createBitmap(max(1, (page.width * scale).roundToInt()),
                                max(1, (page.height * scale).roundToInt()), Bitmap.Config.ARGB_8888)
                            try {
                                bitmap.eraseColor(Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val recognized = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 30, TimeUnit.SECONDS)
                                return textResult(recognized, bitmap.width, bitmap.height)
                            } finally { bitmap.recycle() }
                        }
                    }
                }
            }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            require(bounds.outWidth > 0 && bounds.outHeight > 0) { "This image format could not be read. Try JPEG or PNG." }
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / sample > 3000) sample *= 2
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)) { "Could not decode image." }
            try {
                val orientation = try { ExifInterface(temporary.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
                val rotation = when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270
                    else -> 0
                }
                val recognized = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, rotation)), 30, TimeUnit.SECONDS)
                val sideways = rotation == 90 || rotation == 270
                return textResult(recognized, if (sideways) bitmap.height else bitmap.width,
                    if (sideways) bitmap.width else bitmap.height)
            } finally { bitmap.recycle() }
        } finally {
            recognizer.close()
            temporary.delete()
        }
    }

    private fun textResult(text: Text, width: Int, height: Int): Map<String, Any?> = mapOf(
        "text" to text.text,
        "lines" to text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
            line.boundingBox?.let { box -> mapOf("text" to line.text,
                "top" to box.top.toDouble() / height, "left" to box.left.toDouble() / width, "height" to box.height().toDouble() / height) }
        })

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
