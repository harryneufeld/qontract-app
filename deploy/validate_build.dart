import 'dart:io';

void main(List<String> args) {
  final base = args.isNotEmpty ? args[0] : '/';
  if (!RegExp(r'^/(?:[a-zA-Z0-9_-]+/)*$').hasMatch(base)) {
    stderr.writeln('Base href must be / or a path such as /qontract/.');
    exitCode = 1;
  }
}
