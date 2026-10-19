import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? state, JSString title, JSString url);

/// Removes the one-use token from the address bar and browser history.
void clearResetTokenFromUrl([String fragment = '#/reset-password']) =>
    _replaceState(null, ''.toJS, fragment.toJS);
