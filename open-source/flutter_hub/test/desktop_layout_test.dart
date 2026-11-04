import 'package:flutter_test/flutter_test.dart';
import '../lib/desktop_layout.dart';

void main() {
  const primary = DesktopMonitor(
    name: 'Primary', bounds: DesktopBounds(0, 0, 1920, 1080), primary: true);
  const secondary = DesktopMonitor(
    name: 'Secondary', bounds: DesktopBounds(-2560, 0, 2560, 1440), primary: false);

  test('tiles Windows on a primary monitor', () {
    final left = DesktopWindowControl.tile(primary, WindowTile.left);
    final right = DesktopWindowControl.tile(primary, WindowTile.right);
    expect(left.x, 0);
    expect(left.width, 960);
    expect(right.x, 960);
    expect(right.width, 960);
    expect(right.height, 1080);
  });

  test('uses negative coordinates for a secondary monitor left of primary', () {
    final full = DesktopWindowControl.tile(secondary, WindowTile.full);
    expect(full.x, -2560);
    expect(full.width, 2560);
    final center = DesktopWindowControl.tile(secondary, WindowTile.center);
    expect(center.x < 0, isTrue);
    expect(center.x + center.width <= 0, isTrue);
  });

  test('saved window coordinates round-trip through JSON', () {
    const original = DesktopBounds(-1200, 160, 1000, 740);
    final restored = DesktopBounds.fromJson(original.toJson());
    expect(restored.x, original.x);
    expect(restored.y, original.y);
    expect(restored.width, original.width);
    expect(restored.height, original.height);
  });
}
