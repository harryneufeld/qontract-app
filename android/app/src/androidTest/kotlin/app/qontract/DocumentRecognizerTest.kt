package app.qontract

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Random
import kotlin.math.roundToInt

/**
 * Runs DocumentRecognizer on generated German documents: a digital PDF (text
 * layer), the same page as an image-only scan, and a skewed, noisy, low-contrast
 * phone photo with EXIF rotation. Key fields are what date and contract matching use.
 */
@RunWith(AndroidJUnit4::class)
class DocumentRecognizerTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val recognizer = DocumentRecognizer(context)

    private val title = "Stadtwerke Musterstadt GmbH"
    private val body = listOf(
        "Rechnung Nr. RE-2026-104582",
        "Rechnungsdatum: 14.10.2026",
        "Vertragsnummer: 4711-0815-22",
        "Kundennummer: 100234567",
        "Abschlagszahlung Strom für November",
        "Gesamtbetrag: 84,90 EUR",
        "Zahlbar bis 28.10.2026 per Lastschrift",
    )
    private val keyFields = listOf("RE-2026-104582", "14.10.2026", "4711-0815-22", "100234567",
        "84,90", "28.10.2026", "Abschlagszahlung", "für")

    @Test
    fun digitalPdfUsesTextLayerExactly() {
        val result = recognizer.recognize("invoice.pdf", digitalPdf())
        val text = result["text"] as String
        keyFields.forEach { assertTrue("missing $it", text.contains(it)) }
        @Suppress("UNCHECKED_CAST")
        val lines = result["lines"] as List<Map<String, Any?>>
        val titleLine = lines.first { (it["text"] as String).contains("Stadtwerke") }
        assertEquals(true, titleLine["isBold"])
        assertTrue(lines.filter { (it["text"] as String).contains("Rechnungsdatum") }.none { it["isBold"] == true })
        // Positions are normalized to the upright page, title first.
        assertTrue((titleLine["top"] as Double) < (lines.first { (it["text"] as String).contains("Zahlbar") }["top"] as Double))
    }

    @Test
    fun scannedPdfFallsBackToOcr() {
        val result = recognizer.recognize("scan.pdf", scannedPdf())
        val text = result["text"] as String
        keyFields.forEach { assertTrue("missing $it in:\n$text", text.contains(it)) }
        @Suppress("UNCHECKED_CAST")
        assertTrue((result["lines"] as List<Map<String, Any?>>).size >= body.size)
    }

    @Test
    fun photoWithExifRotationIsReadUpright() {
        val result = recognizer.recognize("photo.jpg", photo())
        val text = result["text"] as String
        keyFields.forEach { assertTrue("missing $it in:\n$text", text.contains(it)) }
        @Suppress("UNCHECKED_CAST")
        val lines = result["lines"] as List<Map<String, Any?>>
        // Upright: the title is above the payment line.
        val top = { needle: String -> lines.first { (it["text"] as String).contains(needle) }["top"] as Double }
        assertTrue(top("Stadtwerke") < top("Zahlbar"))
    }

    private fun page(canvas: Canvas, scale: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
        canvas.drawColor(Color.WHITE)
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textSize = 18f * scale
        canvas.drawText(title, 60f * scale, 90f * scale, paint)
        paint.typeface = Typeface.DEFAULT
        paint.textSize = 12f * scale
        body.forEachIndexed { index, line -> canvas.drawText(line, 60f * scale, (150f + index * 26f) * scale, paint) }
    }

    private fun digitalPdf(): ByteArray {
        val document = PdfDocument()
        val page = document.startPage(PdfDocument.PageInfo.Builder(595, 842, 1).create())
        page(page.canvas, 1f)
        document.finishPage(page)
        return ByteArrayOutputStream().also { document.writeTo(it); document.close() }.toByteArray()
    }

    private fun pageBitmap(dpi: Int): Bitmap {
        val scale = dpi / 72f
        val bitmap = Bitmap.createBitmap((595 * scale).roundToInt(), (842 * scale).roundToInt(), Bitmap.Config.ARGB_8888)
        page(Canvas(bitmap), scale)
        return bitmap
    }

    // Same page as an image only: no text layer, like a scanner without OCR.
    private fun scannedPdf(): ByteArray {
        val image = pageBitmap(200)
        val document = PdfDocument()
        val page = document.startPage(PdfDocument.PageInfo.Builder(595, 842, 1).create())
        page.canvas.drawBitmap(image, null, android.graphics.Rect(0, 0, 595, 842), Paint(Paint.FILTER_BITMAP_FLAG))
        document.finishPage(page)
        image.recycle()
        return ByteArrayOutputStream().also { document.writeTo(it); document.close() }.toByteArray()
    }

    // Skewed, low-contrast, noisy JPEG stored sideways with EXIF orientation 90°.
    private fun photo(): ByteArray {
        val sharp = pageBitmap(160)
        val shot = Bitmap.createBitmap(sharp.width + 200, sharp.height + 200, Bitmap.Config.ARGB_8888)
        Canvas(shot).apply {
            drawColor(Color.rgb(150, 140, 125))
            val dim = ColorMatrix(floatArrayOf(0.8f, 0f, 0f, 0f, 20f, 0f, 0.78f, 0f, 0f, 18f,
                0f, 0f, 0.72f, 0f, 12f, 0f, 0f, 0f, 1f, 0f))
            rotate(2.5f, width / 2f, height / 2f)
            drawBitmap(sharp, 100f, 100f, Paint(Paint.FILTER_BITMAP_FLAG).apply { colorFilter = ColorMatrixColorFilter(dim) })
        }
        sharp.recycle()
        val random = Random(7)
        val pixels = IntArray(shot.width * shot.height)
        shot.getPixels(pixels, 0, shot.width, 0, 0, shot.width, shot.height)
        for (i in pixels.indices) {
            val noise = (random.nextGaussian() * 12).roundToInt()
            val p = pixels[i]
            pixels[i] = Color.rgb(((p shr 16 and 255) + noise).coerceIn(0, 255),
                ((p shr 8 and 255) + noise).coerceIn(0, 255), ((p and 255) + noise).coerceIn(0, 255))
        }
        shot.setPixels(pixels, 0, shot.width, 0, 0, shot.width, shot.height)
        val sideways = Bitmap.createBitmap(shot, 0, 0, shot.width, shot.height, Matrix().apply { postRotate(-90f) }, true)
        shot.recycle()
        val file = File.createTempFile("photo", ".jpg", context.cacheDir)
        try {
            file.outputStream().use { sideways.compress(Bitmap.CompressFormat.JPEG, 60, it) }
            sideways.recycle()
            ExifInterface(file.path).apply {
                setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString())
                saveAttributes()
            }
            return file.readBytes()
        } finally { file.delete() }
    }

}
