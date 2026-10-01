import 'package:flutter/foundation.dart';

/// Old tenant providers can finish in-flight work after their scope is removed.
/// Their results belong to that discarded scope and must not notify its UI.
class SessionNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
