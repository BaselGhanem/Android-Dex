import 'dart:io';
import 'dart:convert';

class AndroidBridge {
  Future<String> adb(List<String> args) async {
    final result = await Process.run('adb', args).timeout(const Duration(seconds: 45));
    if (result.exitCode != 0) throw StateError((result.stderr as String).trim());
    return (result.stdout as String).trim();
  }

  Future<List<String>> devices() async {
    final output = await adb(['devices']);
    return output.split('\n').skip(1).where((x) => x.trim().endsWith('\tdevice'))
        .map((x) => x.split('\t').first.trim()).toList();
  }

  Future<List<String>> packages(String serial) async {
    final output = await adb(['-s', serial, 'shell', 'pm', 'list', 'packages', '-3']);
    return output.split('\n').where((x) => x.startsWith('package:'))
      .map((x) => x.substring(8).trim()).toList()..sort();
  }

  Future<void> launch(String serial, String package) async {
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]*$').hasMatch(package)) {
      throw const FormatException('Invalid package');
    }
    await adb(['-s', serial, 'shell', 'monkey', '-p', package,
        '-c', 'android.intent.category.LAUNCHER', '1']);
  }

  Future<void> mirror(String serial) async {
    await Process.start('scrcpy', ['-s', serial], mode: ProcessStartMode.detached);
  }

  Future<void> connectWifi(String address) async {
    final match = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3}):(\d{1,5})$').firstMatch(address);
    if (match == null || match.group(1)!.split('.').any((x) => int.parse(x) > 255)
      || int.parse(match.group(2)!) < 1 || int.parse(match.group(2)!) > 65535) {
      throw const FormatException('Enter valid IPv4:port');
    }
    await adb(['connect', address]);
  }

  Future<String> battery(String serial) async {
    final output = await adb(['-s', serial, 'shell', 'dumpsys', 'battery']);
    return RegExp(r'level:\s*(\d+)').firstMatch(output)?.group(1) ?? '?';
  }

  Future<String> screenshot(String serial) async {
    final home = Platform.environment['USERPROFILE'];
    if (home == null) throw StateError('Windows user home not found');
    final dir = Directory(home + r'\Pictures\BaselDesktopHub');
    await dir.create(recursive: true);
    final path = dir.path + r'\capture_' +
        DateTime.now().millisecondsSinceEpoch.toString() + '.png';
    final p = await Process.start('adb', ['-s', serial, 'exec-out', 'screencap', '-p']);
    final bytes = <int>[];
    final stderr = p.stderr.transform(utf8.decoder).join();
    await for (final chunk in p.stdout) { bytes.addAll(chunk); }
    final code = await p.exitCode.timeout(const Duration(seconds: 30));
    final err = await stderr;
    if (code != 0 || bytes.length < 8 ||
      bytes[0] != 137 || bytes[1] != 80 || bytes[2] != 78 || bytes[3] != 71) {
      throw StateError('Screenshot failed: ' + err);
    }
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<void> pushFile(String serial, String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('File does not exist');
    await adb(['-s', serial, 'push', file.absolute.path,
      '/sdcard/Download/' + file.uri.pathSegments.last]);
  }

  Future<void> key(String serial, int code) async {
    await adb(['-s', serial, 'shell', 'input', 'keyevent', code.toString()]);
  }
}
