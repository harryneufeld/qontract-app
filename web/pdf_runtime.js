// Match the web runtime required by pdfx 2.11.0. Load before Flutter starts;
// keep the renderer, worker and character maps on the application's origin.
try {
  const pdfjs = await import('./vendor/pdfjs/build/pdf.min.mjs');
  globalThis.pdfjsLib = pdfjs;
  pdfjs.GlobalWorkerOptions.workerSrc =
    new URL('./vendor/pdfjs/build/pdf.worker.min.mjs', import.meta.url).href;
  globalThis.pdfRenderOptions = {
    cMapUrl: new URL('./vendor/pdfjs/cmaps/', import.meta.url).href,
    cMapPacked: true,
  };
} catch (error) {
  // Preserve the existing download fallback if the renderer cannot load.
  console.warn('qontract: PDF preview renderer unavailable', error);
}

const flutter = document.createElement('script');
flutter.src = new URL('./flutter_bootstrap.js', import.meta.url).href;
flutter.async = true;
document.body.append(flutter);
