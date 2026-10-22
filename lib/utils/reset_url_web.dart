import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? state, JSString title, JSString url);

@JS('document.baseURI')
external JSString get _baseUri;

@JS('window.location.pathname')
external JSString get _pathname;

@JS('window.location.search')
external JSString get _search;

String get _basePath {
  final path = Uri.parse(_baseUri.toDart).path;
  return path.endsWith('/') ? path : '$path/';
}

/// Removes the one-use token from the address bar and browser history.
/// The fragment keeps the web app on the same screen; the path and query that
/// carried the token are dropped.
void clearResetTokenFromUrl([String fragment = '#/reset-password']) =>
    _replaceState(null, ''.toJS, '$_basePath$fragment'.toJS);

/// The route for an emailed path link such as `<base>confirm-email?token=...`,
/// or null when the address bar holds something else.
String? emailedLinkRoute() {
  final path = _pathname.toDart;
  final base = _basePath;
  if (!path.startsWith(base)) return null;
  final route = '/${path.substring(base.length)}';
  if (route != '/confirm-email' && route != '/reset-password') return null;
  return '$route${_search.toDart}';
}
