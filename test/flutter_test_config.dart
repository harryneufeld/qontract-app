import 'dart:async';

import 'package:qontract_app/services/token_store.dart';

/// Runs before every test file. Session tokens normally live in the platform
/// keystore, which needs a platform channel that tests cannot answer (and that
/// never completes under the fake clock of widget tests), so they use memory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TokenStore.shared = TokenStore(backend: MemorySecretBackend());
  await testMain();
}
