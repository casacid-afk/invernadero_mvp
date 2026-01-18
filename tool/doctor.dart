import 'dart:io';

bool _verbose = false;

void main(List<String> args) async {
  // Verificar flag --verbose
  _verbose = args.contains('--verbose');

  // Ejecutar comandos en orden
  await _ejecutarDartAnalyze();
  await _ejecutarRunnerSeed();
  await _ejecutarRunnerScenarioSmoke();
}

Future<void> _ejecutarDartAnalyze() async {
  try {
    final result = await Process.run(
      'dart',
      ['analyze'],
      runInShell: true,
    );

    if (_verbose || result.exitCode != 0) {
      stdout.write(result.stdout);
      if (result.stderr.isNotEmpty) {
        stderr.write(result.stderr);
      }
    }

    if (result.exitCode == 0) {
      print('[OK] analyze');
    } else {
      print('[ERROR] analyze (exit code: ${result.exitCode})');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] analyze: $e');
    exit(1);
  }
}

Future<void> _ejecutarRunnerSeed() async {
  try {
    final result = await Process.run(
      'dart',
      ['run', 'tool/runner.dart', 'seed'],
      runInShell: true,
    );

    if (_verbose || result.exitCode != 0) {
      stdout.write(result.stdout);
      if (result.stderr.isNotEmpty) {
        stderr.write(result.stderr);
      }
    }

    if (result.exitCode == 0) {
      print('[OK] seed');
    } else {
      print('[ERROR] seed (exit code: ${result.exitCode})');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] seed: $e');
    exit(1);
  }
}

Future<void> _ejecutarRunnerScenarioSmoke() async {
  try {
    final result = await Process.run(
      'dart',
      ['run', 'tool/runner.dart', 'scenario', 'smoke'],
      runInShell: true,
    );

    if (_verbose || result.exitCode != 0) {
      stdout.write(result.stdout);
      if (result.stderr.isNotEmpty) {
        stderr.write(result.stderr);
      }
    }

    if (result.exitCode == 0) {
      print('[OK] smoke');
    } else {
      print('[ERROR] smoke (exit code: ${result.exitCode})');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] smoke: $e');
    exit(1);
  }
}

