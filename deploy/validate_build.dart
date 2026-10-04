import 'dart:io';

void main(List<String> args) {
  final api = args.isNotEmpty ? args[0] : '';
  final base = args.length > 1 ? args[1] : '/';
  final uri = Uri.tryParse(api);
  final loopback = uri != null &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1');
  if (uri == null ||
      uri.host.isEmpty ||
      !(uri.scheme == 'https' || (uri.scheme == 'http' && loopback)) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      RegExp(r'\s').hasMatch(api) ||
      !uri.path.endsWith('/api')) {
    stderr.writeln('Use a browser-reachable HTTPS API URL ending in /api, '
        'without credentials, query, fragment or trailing slash. '
        'HTTP loopback is allowed for smoke checks.');
    exitCode = 1;
    return;
  }
  if (!RegExp(r'^/(?:[a-zA-Z0-9_-]+/)*$').hasMatch(base)) {
    stderr.writeln('Base href must be / or a path such as /qontract/.');
    exitCode = 1;
  }
}
