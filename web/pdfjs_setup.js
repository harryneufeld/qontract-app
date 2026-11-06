// Points PDF.js at its worker and character maps on this server. Kept out of
// index.html so the Content-Security-Policy needs no inline scripts.
globalThis.pdfjsLib.GlobalWorkerOptions.workerSrc =
    new URL('pdfjs/pdf.worker.min.js', document.baseURI).href;
globalThis.pdfRenderOptions = {
  cMapUrl: new URL('pdfjs/cmaps/', document.baseURI).href,
  cMapPacked: true,
};
