import 'dart:convert';
import 'dart:io';

/// Physical-pixel Windows desktop rectangle.
class DesktopBounds {
  const DesktopBounds(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  Map<String, dynamic> toJson() => {
    'x': x, 'y': y, 'width': width, 'height': height,
  };
  factory DesktopBounds.fromJson(Map<String, dynamic> json) => DesktopBounds(
    (json['x'] as num).toInt(),
    (json['y'] as num).toInt(),
    (json['width'] as num).toInt(),
    (json['height'] as num).toInt(),
  );
}

class DesktopMonitor {
  const DesktopMonitor({
    required this.name, required this.bounds, required this.primary,
  });
  final String name;
  final DesktopBounds bounds;
  final bool primary;
}

enum WindowTile { left, right, full, center }

/// Uses Win32 through local PowerShell; arguments are validated integers only.
class DesktopWindowControl {
  static Future<String> _powershell(String script) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Window management requires Windows.');
    }
    final result = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: false,
    ).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw StateError(stderr.isNotEmpty ? stderr : 'Windows command failed.');
    }
    return (result.stdout as String).trim();
  }

  static Future<List<DesktopMonitor>> monitors() async {
    final output = await _powershell(r'''
Add-Type -AssemblyName System.Windows.Forms
@([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
  [pscustomobject]@{
    name = $_.DeviceName
    x = $_.WorkingArea.X
    y = $_.WorkingArea.Y
    width = $_.WorkingArea.Width
    height = $_.WorkingArea.Height
    primary = $_.Primary
  }
}) | ConvertTo-Json -Compress
''');
    if (output.isEmpty) return [];
    final decoded = jsonDecode(output);
    final entries = decoded is List ? decoded : [decoded];
    return entries.map((entry) {
      final data = Map<String, dynamic>.from(entry as Map);
      return DesktopMonitor(
        name: data['name'].toString(),
        bounds: DesktopBounds(
          (data['x'] as num).toInt(),
          (data['y'] as num).toInt(),
          (data['width'] as num).toInt(),
          (data['height'] as num).toInt(),
        ),
        primary: data['primary'] == true,
      );
    }).toList();
  }

  static const String _native = r'''
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BaselWindowNative {
  [StructLayout(LayoutKind.Sequential)]
  public struct NativeRect {
    public int Left, Top, Right, Bottom;
  }
  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr handle, out NativeRect rect);
  [DllImport("user32.dll")]
  public static extern bool SetWindowPos(IntPtr handle, IntPtr after,
    int x, int y, int width, int height, uint flags);
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr handle, int command);
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr handle);
}
'@
''';

  static String _windowScript(int pid) {
    if (pid <= 0) throw const FormatException('Invalid process ID.');
    return _native + '\n'
        + '\$proc = Get-Process -Id ' + pid.toString() + ' -ErrorAction Stop\n'
        + '\$handle = \$proc.MainWindowHandle\n'
        + 'if (\$handle -eq [IntPtr]::Zero) { throw "Window not ready" }\n';
  }

  static Future<DesktopBounds> readBounds(int pid) async {
    final output = await _powershell(_windowScript(pid) + '\n'
        + '\$rectangle = New-Object BaselWindowNative+NativeRect\n'
        + 'if (-not [BaselWindowNative]::GetWindowRect(\$handle, [ref]\$rectangle)) '
        + '{ throw "Cannot inspect window" }\n'
        + '[pscustomobject]@{ x = \$rectangle.Left; y = \$rectangle.Top; '
        + 'width = \$rectangle.Right - \$rectangle.Left; '
        + 'height = \$rectangle.Bottom - \$rectangle.Top } | ConvertTo-Json -Compress');
    return DesktopBounds.fromJson(Map<String, dynamic>.from(jsonDecode(output) as Map));
  }

  static Future<void> move(int pid, DesktopBounds bounds) async {
    if (bounds.width < 160 || bounds.height < 160 ||
        bounds.width > 10000 || bounds.height > 10000) {
      throw const FormatException('Unsupported window dimensions.');
    }
    await _powershell(_windowScript(pid) + '\n'
        + '[void][BaselWindowNative]::ShowWindowAsync(\$handle, 9)\n'
        + 'if (-not [BaselWindowNative]::SetWindowPos(\$handle, [IntPtr]::Zero, '
        + bounds.x.toString() + ', ' + bounds.y.toString() + ', '
        + bounds.width.toString() + ', ' + bounds.height.toString()
        + ', 0x0040)) { throw "Unable to position window" }');
  }

  static Future<void> focus(int pid) async {
    await _powershell(_windowScript(pid) + '\n'
        + '[void][BaselWindowNative]::ShowWindowAsync(\$handle, 9)\n'
        + '[void][BaselWindowNative]::SetForegroundWindow(\$handle)');
  }

  static DesktopBounds tile(DesktopMonitor monitor, WindowTile side) {
    final a = monitor.bounds;
    switch (side) {
      case WindowTile.left:
        return DesktopBounds(a.x, a.y, a.width ~/ 2, a.height);
      case WindowTile.right:
        final half = a.width ~/ 2;
        return DesktopBounds(a.x + half, a.y, a.width - half, a.height);
      case WindowTile.full:
        return a;
      case WindowTile.center:
        final w = (a.width * 0.7).round();
        final h = (a.height * 0.8).round();
        return DesktopBounds(a.x + (a.width - w) ~/ 2,
            a.y + (a.height - h) ~/ 2, w, h);
    }
  }
}
