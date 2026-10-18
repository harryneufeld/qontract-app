package app.qontract

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.os.ParcelFileDescriptor
import com.googlecode.leptonica.android.AdaptiveMap
import com.googlecode.leptonica.android.Convert
import com.googlecode.leptonica.android.Pix
import com.googlecode.leptonica.android.ReadFile
import com.googlecode.leptonica.android.Scale
import com.googlecode.leptonica.android.Skew
import com.googlecode.tesseract.android.TessBaseAPI
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.File
import java.io.IOException
import kotlin.math.max
import kotlin.math.roundToInt

/** Reads text and line positions from a PDF or image entirely on the device. */
class DocumentRecognizer(private val context: Context) {
    private val maxBytes = 20 * 1024 * 1024
    // tessdata_fast models bundled in assets/tessdata; bump the version when replacing them.
    private val ocrLanguages = listOf("deu", "eng")
    private val ocrModelVersion = "fast-8741641"
    private val boldFontName = Regex("bold|black|heavy", RegexOption.IGNORE_CASE)
    // Longest side for OCR input; smaller pages and photos are scaled up to it.
    private val ocrTargetSize = 3000

    init {
        PDFBoxResourceLoader.init(context.applicationContext)
    }

    fun recognize(name: String, bytes: ByteArray): Map<String, Any?> {
        require(bytes.isNotEmpty() && bytes.size <= maxBytes) { "Choose a non-empty document up to 20 MB." }
        val temporary = File.createTempFile("ocr-", ".data", context.cacheDir)
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
        val image = prepare(bitmap)
        try {
            require(tesseract.init(tessDataRoot(), ocrLanguages.joinToString("+"), TessBaseAPI.OEM_LSTM_ONLY)) {
                "Text recognition is unavailable."
            }
            tesseract.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
            tesseract.setImage(image)
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
                        lines += mapOf("text" to line, "top" to box.top.toDouble() / image.height,
                            "left" to box.left.toDouble() / image.width, "height" to box.height().toDouble() / image.height)
                    } while (iterator.next(level))
                } finally { iterator.delete() }
            }
            return mapOf("text" to text, "lines" to lines)
        } finally {
            tesseract.recycle()
            image.recycle()
        }
    }

    // Tesseract misreads uneven lighting, skew and small text (e.g. stray spaces in
    // numbers), so flatten the background, straighten, and enlarge before reading.
    private fun prepare(bitmap: Bitmap): Pix {
        var pix = ReadFile.readBitmap(bitmap)
        // Leptonica clones are reference-counted, so releasing the previous step is always safe.
        fun replace(next: Pix) {
            pix.recycle()
            pix = next
        }
        try {
            replace(Convert.convertTo8(pix))
            replace(AdaptiveMap.backgroundNormMorph(pix))
            replace(Skew.deskew(pix, FloatArray(2)))
            val longest = max(pix.width, pix.height)
            if (longest < ocrTargetSize) replace(Scale.scale(pix, ocrTargetSize.toFloat() / longest))
            return pix
        } catch (e: Exception) {
            pix.recycle()
            throw e
        }
    }

    // Tesseract reads models from the file system: copy them out of the APK once per model set.
    private fun tessDataRoot(): String {
        val root = File(context.noBackupFilesDir, "tesseract-$ocrModelVersion")
        val data = File(root, "tessdata").apply { mkdirs() }
        for (language in ocrLanguages) {
            val model = File(data, "$language.traineddata")
            if (model.isFile) continue
            val staging = File(data, ".$language.staging")
            context.assets.open("tessdata/$language.traineddata").use { input ->
                staging.outputStream().use { input.copyTo(it) }
            }
            require(staging.renameTo(model)) { "Could not prepare text recognition." }
        }
        context.noBackupFilesDir.listFiles()
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
}
