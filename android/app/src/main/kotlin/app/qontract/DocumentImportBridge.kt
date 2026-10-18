package app.qontract

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.widget.Toast
import com.googlecode.tesseract.android.TessBaseAPI
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

class DocumentImportBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "qontract/document_import")
    private val worker = Executors.newSingleThreadExecutor()
    private val inbox = File(activity.filesDir, "document-inbox").apply { mkdirs() }
    private val maxBytes = 20 * 1024 * 1024
    // tessdata_fast models bundled in assets/tessdata; bump the version when replacing them.
    private val ocrLanguages = listOf("deu", "eng")
    private val ocrModelVersion = "fast-8741641"
    private val boldFontName = Regex("bold|black|heavy", RegexOption.IGNORE_CASE)

    init {
        PDFBoxResourceLoader.init(activity.applicationContext)
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
        val temporary = File.createTempFile("ocr-", ".data", activity.cacheDir)
        try {
            temporary.writeBytes(bytes)
            val isPdf = bytes.take(5).toByteArray().contentEquals("%PDF-".toByteArray())
            if (name.endsWith(".pdf", true) || isPdf) {
                // Existing text is faster and preserves exact identifiers.
                embeddedText(temporary)?.let { return it }
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
                                return ocr(bitmap)
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
            val options = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)) { "Could not decode image." }
            val orientation = try { ExifInterface(temporary.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
            val rotation = when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
            // Tesseract has no orientation input, so line positions come from the upright image.
            val upright = if (rotation == 0) bitmap else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height,
                Matrix().apply { postRotate(rotation.toFloat()) }, true)
            try {
                return ocr(upright)
            } finally {
                if (upright !== bitmap) upright.recycle()
                bitmap.recycle()
            }
        } finally {
            temporary.delete()
        }
    }

    private fun ocr(bitmap: Bitmap): Map<String, Any?> {
        val tesseract = TessBaseAPI()
        try {
            require(tesseract.init(tessDataRoot(), ocrLanguages.joinToString("+"), TessBaseAPI.OEM_LSTM_ONLY)) {
                "Text recognition is unavailable."
            }
            tesseract.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
            tesseract.setImage(bitmap)
            val text = tesseract.getUTF8Text().orEmpty().trim()
            val lines = mutableListOf<Map<String, Any?>>()
            tesseract.getResultIterator()?.let { iterator ->
                try {
                    val level = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                    iterator.begin()
                    do {
                        val line = iterator.getUTF8Text(level)?.trim()
                        if (line.isNullOrEmpty()) continue
                        val box = iterator.getBoundingRect(level)
                        lines += mapOf("text" to line, "top" to box.top.toDouble() / bitmap.height,
                            "left" to box.left.toDouble() / bitmap.width, "height" to box.height().toDouble() / bitmap.height)
                    } while (iterator.next(level))
                } finally { iterator.delete() }
            }
            return mapOf("text" to text, "lines" to lines)
        } finally { tesseract.recycle() }
    }

    // Tesseract reads models from the file system: copy them out of the APK once per model set.
    private fun tessDataRoot(): String {
        val root = File(activity.noBackupFilesDir, "tesseract-$ocrModelVersion")
        val data = File(root, "tessdata").apply { mkdirs() }
        for (language in ocrLanguages) {
            val model = File(data, "$language.traineddata")
            if (model.isFile) continue
            val staging = File(data, ".$language.staging")
            activity.assets.open("tessdata/$language.traineddata").use { input ->
                staging.outputStream().use { input.copyTo(it) }
            }
            require(staging.renameTo(model)) { "Could not prepare text recognition." }
        }
        activity.noBackupFilesDir.listFiles()
            ?.filter { it.name.startsWith("tesseract-") && it != root }
            ?.forEach { it.deleteRecursively() }
        return root.path
    }

    // First page only, like the OCR path; null when the page has no usable text layer.
    private fun embeddedText(file: File): Map<String, Any?>? {
        val document = try {
            PDDocument.load(file, MemoryUsageSetting.setupTempFileOnly())
        } catch (_: IOException) {
            return null // Password-protected or damaged: rendering decides whether it is readable.
        }
        document.use { pdf ->
            if (pdf.numberOfPages == 0) return null
            val lines = mutableListOf<Map<String, Any?>>()
            val stripper = object : PDFTextStripper() {
                private val lineText = StringBuilder()
                private val positions = mutableListOf<TextPosition>()

                override fun writeString(text: String, textPositions: MutableList<TextPosition>) {
                    super.writeString(text, textPositions)
                    lineText.append(text)
                    positions += textPositions
                }

                override fun writeWordSeparator() {
                    super.writeWordSeparator()
                    lineText.append(' ')
                }

                override fun writeLineSeparator() {
                    super.writeLineSeparator()
                    flushLine()
                }

                override fun writePageEnd() {
                    flushLine()
                    super.writePageEnd()
                }

                private fun flushLine() {
                    val value = lineText.toString().trim()
                    val first = positions.firstOrNull()
                    if (value.isNotEmpty() && first != null && first.pageWidth > 0 && first.pageHeight > 0) {
                        val top = positions.minOf { it.yDirAdj - it.heightDir }
                        val bottom = positions.maxOf { it.yDirAdj }
                        lines += mapOf("text" to value, "top" to (top / first.pageHeight).toDouble(),
                            "left" to (positions.minOf { it.xDirAdj } / first.pageWidth).toDouble(),
                            "height" to ((bottom - top) / first.pageHeight).toDouble(),
                            "isBold" to positions.any(::isBold))
                    }
                    lineText.clear()
                    positions.clear()
                }
            }
            stripper.sortByPosition = true
            stripper.startPage = 1
            stripper.endPage = 1
            val text = stripper.getText(pdf).trim()
            if (text.isEmpty()) return null
            // Positions of rotated pages would not match the upright page.
            return if (pdf.getPage(0).rotation != 0) mapOf("text" to text) else mapOf("text" to text, "lines" to lines)
        }
    }

    private fun isBold(position: TextPosition): Boolean {
        val font = position.font ?: return false
        val descriptor = font.fontDescriptor
        return descriptor?.isForceBold == true || (descriptor?.fontWeight ?: 0f) >= 700f ||
            boldFontName.containsMatchIn(font.name ?: "")
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
