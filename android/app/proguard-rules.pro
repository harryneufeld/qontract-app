# Tesseract4Android ships no consumer rules; its native code calls back into
# these classes by name (e.g. TessBaseAPI.onProgressValues).
-keep class com.googlecode.tesseract.android.** { *; }
-keep class com.googlecode.leptonica.android.** { *; }

# PdfBox-Android's optional JPEG 2000 support (com.gemalto.jp2) is not bundled;
# JPX images are skipped, which only affects rendering, not text extraction.
-dontwarn com.gemalto.jp2.**
