import 'dart:io';

void main() async {
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

    stdout.write(result.stdout);
    if (result.stderr.isNotEmpty) {
      stderr.write(result.stderr);
    }

    if (result.exitCode == 0) {
      print('[OK] analyze\n');
    } else {
      print('[ERROR] analyze (exit code: ${result.exitCode})\n');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] analyze: $e\n');
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

    stdout.write(result.stdout);
    if (result.stderr.isNotEmpty) {
      stderr.write(result.stderr);
    }

    if (result.exitCode == 0) {
      print('[OK] seed\n');
    } else {
      print('[ERROR] seed (exit code: ${result.exitCode})\n');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] seed: $e\n');
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

    stdout.write(result.stdout);
    if (result.stderr.isNotEmpty) {
      stderr.write(result.stderr);
    }

    if (result.exitCode == 0) {
      print('[OK] smoke\n');
    } else {
      print('[ERROR] smoke (exit code: ${result.exitCode})\n');
      exit(result.exitCode);
    }
  } catch (e) {
    print('[ERROR] smoke: $e\n');
    exit(1);
  }
}

