import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? state, JSString title, JSString url);

void clearResetTokenFromUrl() =>
    _replaceState(null, ''.toJS, '#/reset-password'.toJS);
