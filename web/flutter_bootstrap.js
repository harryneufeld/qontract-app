{{flutter_js}}
{{flutter_build_config}}

// Load every engine resource from this app's own server: CanvasKit from the
// build output instead of Google's CDN, and no font fallback downloads from
// fonts.gstatic.com (the app bundles its fonts; see pubspec.yaml).
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
    fontFallbackBaseUrl: "assets/fonts/fallback/",
  },
});
