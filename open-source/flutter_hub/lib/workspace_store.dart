import 'dart:convert';
import 'dart:io';
import 'desktop_layout.dart';

class WorkspaceDefinition {
  const WorkspaceDefinition(this.id, this.name, this.headline, this.subtitle);
  final String id;
  final String name;
  final String headline;
  final String subtitle;
}

const workspaceDefinitions = <WorkspaceDefinition>[
  WorkspaceDefinition(
    'sales',
    'Sales Desk',
    "Basel's Sales Desk",
    'From raw numbers to decisions that matter.',
  ),
  WorkspaceDefinition(
    'academy',
    'X Academy',
    'X Academy Studio',
    'Learn. Analyse. Lead. Your training space, ready when you are.',
  ),
  WorkspaceDefinition(
    'builder',
    'Build Lab',
    "Basel's Build Lab",
    'Design systems. Simplify workflows. Build what comes next.',
  ),
];

class WorkspaceStore {
  String activeId = 'sales';
  final Map<String, List<String>> pins = {};
  final Map<String, Map<String, DesktopBounds>> positions = {};

  String get currentName =>
      workspaceDefinitions.firstWhere((p) => p.id == activeId).name;

  List<String> pinned(String profileId) =>
      List<String>.from(pins[profileId] ?? const []);

  bool isPinned(String profileId, String package) =>
      pins[profileId]?.contains(package) ?? false;

  DesktopBounds? savedBounds(String profileId, String package) =>
      positions[profileId]?[package];

  Future<File> _file() async {
    final home = Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'];
    if (home == null) throw StateError('Windows profile location unavailable.');
    final folder = Directory(home + r'\BaselDesktopHub');
    await folder.create(recursive: true);
    return File(folder.path + r'\workspaces.json');
  }

  Future<void> load() async {
    final file = await _file();
    if (!await file.exists()) return;
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) throw const FormatException('Workspace settings file is invalid.');
    final data = Map<String, dynamic>.from(raw);
    final id = data['activeId'];
    if (id is String && workspaceDefinitions.any((p) => p.id == id)) activeId = id;

    pins.clear();
    final rawPins = data['pins'];
    if (rawPins is Map) {
      for (final entry in rawPins.entries) {
        if (!workspaceDefinitions.any((p) => p.id == entry.key) || entry.value is! List) continue;
        pins[entry.key.toString()] =
            (entry.value as List).whereType<String>().where(_validPackage).toSet().toList();
      }
    }

    positions.clear();
    final rawPositions = data['positions'];
    if (rawPositions is Map) {
      for (final profile in rawPositions.entries) {
        if (profile.value is! Map) continue;
        final items = <String, DesktopBounds>{};
        for (final app in (profile.value as Map).entries) {
          if (app.key is! String || !_validPackage(app.key as String) ||
              app.value is! Map) continue;
          try {
            final bounds = DesktopBounds.fromJson(
              Map<String, dynamic>.from(app.value as Map));
            if (bounds.width >= 160 && bounds.height >= 160) {
              items[app.key as String] = bounds;
            }
          } catch (_) {
            // Ignore just the invalid placement; retain remaining workspaces.
          }
        }
        positions[profile.key.toString()] = items;
      }
    }
  }

  static bool _validPackage(String value) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$').hasMatch(value);

  Future<void> save() async {
    final file = await _file();
    final payload = {
      'schema': 1,
      'activeId': activeId,
      'pins': pins,
      'positions': {
        for (final profile in positions.entries)
          profile.key: {
            for (final app in profile.value.entries) app.key: app.value.toJson(),
          },
      },
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<void> choose(String id) async {
    if (!workspaceDefinitions.any((p) => p.id == id)) {
      throw const FormatException('Unknown workspace');
    }
    activeId = id;
    await save();
  }

  Future<void> togglePin(String package) async {
    if (!_validPackage(package)) throw const FormatException('Invalid app package');
    final list = pins.putIfAbsent(activeId, () => []);
    if (!list.remove(package)) list.add(package);
    await save();
  }

  Future<void> remember(String package, DesktopBounds bounds) async {
    if (!_validPackage(package)) throw const FormatException('Invalid app package');
    positions.putIfAbsent(activeId, () => {})[package] = bounds;
    await save();
  }
}
