import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'desktop_layout.dart';

enum WindowStatus { starting, running, failed, closed }

class AppWindow {
  AppWindow(this.id, this.device, this.package);
  final int id;
  final String device;
  final String package;
  WindowStatus status = WindowStatus.starting;
  String diagnostic = '';
  Process? process;
  DesktopBounds? placement;
}

class VirtualWindowManager {
  final List<AppWindow> windows = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  int _nextId = 1;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  Future<String> capabilities() async {
    final result = await Process.run('scrcpy', ['--help'])
        .timeout(const Duration(seconds: 15));
    if (result.exitCode != 0) {
      throw StateError('Unable to query scrcpy --help');
    }
    final help = result.stdout.toString() + result.stderr.toString();
    return help;
  }

  Future<AppWindow> open({
    required String serial,
    required String package,
    int width = 1280,
    int height = 800,
    DesktopBounds? placement,
  }) async {
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]*$').hasMatch(package)) {
      throw const FormatException('Invalid Android package');
    }
    if (width < 480 || height < 320 || width > 3840 || height > 2160) {
      throw const FormatException('Invalid virtual display dimensions');
    }
    final help = await capabilities();
    if (!help.contains('--new-display') || !help.contains('--start-app')) {
      throw StateError('Update scrcpy: virtual displays and app launch options are required.');
    }
    final window = AppWindow(_nextId++, serial, package);
    window.placement = placement;
    windows.add(window);
    _notify();
    final args = [
      '-s', serial,
      '--new-display=' + width.toString() + 'x' + height.toString(),
      '--start-app=' + package,
      '--window-title=Basel Hub | ' + package,
      if (help.contains('--flex-display')) '--flex-display',
      if (help.contains('--no-vd-destroy-content')) '--no-vd-destroy-content',
      if (placement != null) ...[
        '--window-x=' + placement.x.toString(),
        '--window-y=' + placement.y.toString(),
        '--window-width=' + placement.width.toString(),
        '--window-height=' + placement.height.toString(),
      ],
    ];
    try {
      final process = await Process.start('scrcpy', args, runInShell: false);
      window.process = process;
      final diagnostics = <String>[];
      void capture(String chunk) {
        diagnostics.add(chunk);
        if (diagnostics.length > 30) diagnostics.removeAt(0);
      }
      process.stdout.transform(utf8.decoder).listen(capture);
      process.stderr.transform(utf8.decoder).listen(capture);
      final earlyExit = await Future.any<int?>([
        process.exitCode.then<int?>((code) => code),
        Future<int?>.delayed(const Duration(seconds: 2), () => null),
      ]);
      if (earlyExit != null) {
        window.status = WindowStatus.failed;
        window.diagnostic = diagnostics.join().trim();
        if (window.diagnostic.isEmpty) {
          window.diagnostic = 'scrcpy terminated (code ' + earlyExit.toString() + ')';
        }
        _notify();
        throw StateError(window.diagnostic);
      }
      window.status = WindowStatus.running;
      _notify();
      unawaited(process.exitCode.then((code) {
        if (window.status == WindowStatus.closed) return;
        window.status = code == 0 ? WindowStatus.closed : WindowStatus.failed;
        window.diagnostic = diagnostics.join().trim();
        if (window.status == WindowStatus.failed && window.diagnostic.isEmpty) {
          window.diagnostic = 'scrcpy exited (code ' + code.toString() + ')';
        }
        _notify();
      }));
      return window;
    } catch (error) {
      window.status = WindowStatus.failed;
      window.diagnostic = error.toString();
      _notify();
      rethrow;
    }
  }

  Future<DesktopBounds> actualBounds(AppWindow window) async {
    final pid = window.process?.pid;
    if (pid == null || window.status != WindowStatus.running) {
      throw StateError('Window is not running');
    }
    return DesktopWindowControl.readBounds(pid);
  }

  Future<void> place(AppWindow window, DesktopBounds bounds) async {
    final pid = window.process?.pid;
    if (pid == null || window.status != WindowStatus.running) {
      throw StateError('Window is not running');
    }
    await DesktopWindowControl.move(pid, bounds);
    window.placement = bounds;
    _notify();
  }

  Future<void> focus(AppWindow window) async {
    final pid = window.process?.pid;
    if (pid == null || window.status != WindowStatus.running) {
      throw StateError('Window is not running');
    }
    await DesktopWindowControl.focus(pid);
  }

  void close(int id) {
    final matching = windows.where((w) => w.id == id);
    if (matching.isEmpty) return;
    final window = matching.first;
    if (window.status == WindowStatus.running || window.status == WindowStatus.starting) {
      window.process?.kill();
    }
    window.status = WindowStatus.closed;
    _notify();
  }

  void clearFinished() {
    windows.removeWhere((w) =>
      w.status == WindowStatus.closed || w.status == WindowStatus.failed);
    _notify();
  }

  void dispose() {
    if (_disposed) return;
    for (final window in windows) {
      if (window.status == WindowStatus.running || window.status == WindowStatus.starting) {
        window.process?.kill();
      }
    }
    _disposed = true;
    _changes.close();
  }
}
