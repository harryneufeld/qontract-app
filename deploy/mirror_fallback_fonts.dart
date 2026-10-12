// Mirrors the Flutter web engine's fallback fonts into the build output.
//
// The engine downloads Noto fonts for characters the bundled fonts lack
// (emoji, CJK, symbols). web/flutter_bootstrap.js points those downloads at
// this app's own assets/fonts/fallback/ instead of fonts.gstatic.com, so the
// image ships the files and browsers never contact Google. The list is read
// from the compiled main.dart.js, so it always matches the engine version.
//
// Usage: dart deploy/mirror_fallback_fonts.dart <main.dart.js> <output dir>
import 'dart:io';

const _source = 'https://fonts.gstatic.com/s/';
final _path = RegExp(r'noto[a-z0-9]+/v[0-9]+/[A-Za-z0-9_.-]+\.woff2');

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: mirror_fallback_fonts.dart <main.dart.js> <out>');
    exit(64);
  }
  final paths = _path
      .allMatches(await File(args[0]).readAsString())
      .map((m) => m.group(0)!)
      .where((p) => !p.contains('..'))
      .toSet()
      .toList();
  if (paths.isEmpty) {
    stderr.writeln('No fallback fonts found in ${args[0]}.');
    exit(1);
  }

  final client = HttpClient();
  var next = 0;
  var bytes = 0;
  Future<void> worker() async {
    while (next < paths.length) {
      final path = paths[next++];
      final file = File('${args[1]}/$path');
      for (var attempt = 1;; attempt++) {
        try {
          final request = await client.getUrl(Uri.parse('$_source$path'));
          final response = await request.close();
          if (response.statusCode != 200) {
            throw HttpException('HTTP ${response.statusCode}');
          }
          await file.parent.create(recursive: true);
          final data =
              await response.fold<List<int>>([], (a, b) => a..addAll(b));
          await file.writeAsBytes(data);
          bytes += data.length;
          break;
        } on Exception catch (error) {
          if (attempt == 3) {
            stderr.writeln('Failed to mirror $path: $error');
            exit(1);
          }
        }
      }
    }
  }

  await Future.wait(List.generate(16, (_) => worker()));
  client.close();
  stdout.writeln('Mirrored ${paths.length} fallback fonts '
      '(${(bytes / 1e6).toStringAsFixed(1)} MB).');
}
