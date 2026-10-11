import 'dart:convert';
import 'dart:io';

const _nativePackages = {'bluez_obex_native'};

Future<void> main() async {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    stderr.writeln('Run flutter pub get before this bootstrap tool.');
    exitCode = 2;
    return;
  }
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, Object?>;
  final packages = (config['packages'] as List).cast<Map<String, Object?>>();
  final roots = <String, Uri>{
    for (final package in packages)
      if (_nativePackages.contains(package['name']))
        package['name']! as String: configFile.uri.resolve(
          package['rootUri']! as String,
        ),
  };
  final missing = _nativePackages.difference(roots.keys.toSet());
  if (missing.isNotEmpty) {
    stderr.writeln('Missing packages: ${missing.join(', ')}');
    exitCode = 2;
    return;
  }
  for (final entry in roots.entries) {
    final directory = Directory.fromUri(entry.value).path;
    stdout.writeln('Initializing ${entry.key} native submodules...');
    final result = await Process.run('git', [
      '-C',
      directory,
      'submodule',
      'update',
      '--init',
      '--recursive',
    ], runInShell: false);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      exitCode = result.exitCode;
      return;
    }
  }
}
