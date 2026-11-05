// Sanitizes navigator.language before the Flutter engine starts; see the
// comment in index.html. Kept out of index.html so the Content-Security-Policy
// needs no inline scripts.
(function () {
  var VALID_BASE = /^[a-zA-Z]{2,3}$/;
  function clean(language) {
    if (!language) return 'en-US';
    var base = String(language).split(/[@;]/)[0].trim();
    return VALID_BASE.test(base) ? base : 'en-US';
  }
  try {
    var languages =
      (navigator.languages && navigator.languages.length)
        ? navigator.languages.slice()
        : [navigator.language];
    var cleaned = languages.map(clean);
    if (!VALID_BASE.test(cleaned[0].split(/[-_]/)[0])) {
      cleaned[0] = 'en-US';
    }
    Object.defineProperty(window.navigator, 'languages', {
      get: function () { return cleaned; },
      configurable: true,
    });
    Object.defineProperty(window.navigator, 'language', {
      get: function () { return cleaned[0]; },
      configurable: true,
    });
  } catch (e) {
    // Some engines freeze navigator; nothing more we can do pre-engine.
    console.warn('qontract: could not sanitize navigator.language', e);
  }
})();
