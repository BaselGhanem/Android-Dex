import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'android_bridge.dart';

/// Keyboard controls run only while this panel has focus. Coordinates are
/// physical pixels on the phone's primary display, not virtual displays.
class GamingPanel extends StatefulWidget {
  const GamingPanel({super.key, required this.bridge, required this.serial});
  final AndroidBridge bridge;
  final String? serial;
  @override
  State<GamingPanel> createState() => _GamingPanelState();
}

class _GamingPanelState extends State<GamingPanel> {
  final package = TextEditingController();
  final keyName = TextEditingController();
  final x = TextEditingController();
  final y = TextEditingController();
  final endX = TextEditingController();
  final endY = TextEditingController();
  final duration = TextEditingController(text: '150');
  final focus = FocusNode();
  Map<String, Map<String, List<int>>> profiles = {};
  String notice = 'Choose a game and map controls for your Galaxy.';
  bool armed = false;
  bool sending = false;

  Future<File> get settings async {
    final base = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'];
    if (base == null) throw StateError('Windows profile is unavailable.');
    final dir = Directory('$base\\BaselDesktopHub');
    await dir.create(recursive: true);
    return File('${dir.path}\\games.json');
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final f = await settings;
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) throw const FormatException('Invalid game profiles');
      final result = <String, Map<String, List<int>>>{};
      for (final item in raw.entries) {
        if (item.key is! String || item.value is! Map) continue;
        final bindings = <String, List<int>>{};
        for (final binding in (item.value as Map).entries) {
          if (binding.key is! String || binding.value is! List) continue;
          final numbers = (binding.value as List).whereType<int>().toList();
          if ((numbers.length == 2 || numbers.length == 5) &&
              numbers.every((v) => v >= 0 && v <= 10000)) {
            bindings[binding.key.toString().toUpperCase()] = numbers;
          }
        }
        result[item.key.toString()] = bindings;
      }
      if (mounted) setState(() => profiles = result);
    } catch (e) {
      if (mounted) setState(() => notice = 'Could not load profiles: $e');
    }
  }

  Future<void> save() async {
    final f = await settings;
    await f.writeAsString(jsonEncode(profiles), flush: true);
  }

  Future<void> add() async {
    try {
      final pkg = package.text.trim();
      final key = keyName.text.trim().toUpperCase();
      if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]*$').hasMatch(pkg)) {
        throw const FormatException('Enter an Android package name.');
      }
      if (!RegExp(r'^[A-Z0-9]$').hasMatch(key)) {
        throw const FormatException('Use one letter or number for the key.');
      }
      int coordinate(TextEditingController c) {
        final n = int.tryParse(c.text.trim());
        if (n == null || n < 0 || n > 10000) {
          throw const FormatException('Enter coordinates between 0 and 10000.');
        }
        return n;
      }
      final values = <int>[coordinate(x), coordinate(y)];
      if (endX.text.trim().isNotEmpty || endY.text.trim().isNotEmpty) {
        final ms = int.tryParse(duration.text.trim());
        if (ms == null || ms < 50 || ms > 5000) {
          throw const FormatException('Swipe duration must be 50–5000 ms.');
        }
        values.addAll([coordinate(endX), coordinate(endY), ms]);
      }
      profiles.putIfAbsent(pkg, () => {})[key] = values;
      await save();
      if (mounted) setState(() => notice = 'Control saved for $pkg.');
    } catch (e) {
      if (mounted) setState(() => notice = 'Cannot save: $e');
    }
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (!armed || event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() { armed = false; notice = 'Controls disabled.'; });
      return KeyEventResult.handled;
    }
    if (sending) return KeyEventResult.ignored;
    final serial = widget.serial;
    final binding = profiles[package.text.trim()]?[event.logicalKey.keyLabel.toUpperCase()];
    if (serial == null || binding == null) return KeyEventResult.ignored;
    sending = true;
    final action = binding.length == 2
      ? ['tap', '${binding[0]}', '${binding[1]}']
      : ['swipe', '${binding[0]}', '${binding[1]}', '${binding[2]}', '${binding[3]}', '${binding[4]}'];
    widget.bridge.adb(['-s', serial, 'shell', 'input', ...action]).then((_) {
      if (mounted) setState(() => notice = 'Control sent to your Galaxy.');
    }).catchError((Object e) {
      if (mounted) setState(() => notice = 'Control failed: $e');
    }).whenComplete(() => sending = false);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    package.dispose(); keyName.dispose(); x.dispose(); y.dispose();
    endX.dispose(); endY.dispose(); duration.dispose(); focus.dispose();
    super.dispose();
  }

  Widget field(TextEditingController c, String label) => SizedBox(width: 150,
    child: TextField(controller: c, decoration: InputDecoration(labelText: label)));

  @override
  Widget build(BuildContext context) {
    final bindings = profiles[package.text.trim()] ?? {};
    return Focus(focusNode: focus, onKeyEvent: onKey,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Basel's Game Desk", style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Save a keyboard layout for each game on your Galaxy.'),
        const SizedBox(height: 20),
        TextField(controller: package, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Android game package')),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(onPressed: widget.serial == null ? null : () async {
            try {
              await widget.bridge.launch(widget.serial!, package.text.trim());
              await widget.bridge.mirror(widget.serial!);
              if (mounted) setState(() => notice = 'Game launch requested. Click Enable controls to use the keyboard here.');
            } catch (e) { if (mounted) setState(() => notice = 'Launch failed: $e'); }
          }, icon: const Icon(Icons.play_arrow), label: const Text('Start game and mirror')),
          OutlinedButton.icon(onPressed: widget.serial == null ? null : () {
            setState(() { armed = !armed; notice = armed
              ? 'Controls enabled. Keep focus on this panel; Esc disables controls.'
              : 'Controls disabled.'; });
            if (armed) focus.requestFocus();
          }, icon: Icon(armed ? Icons.pause : Icons.keyboard),
            label: Text(armed ? 'Disable controls' : 'Enable controls')),
        ]),
        const SizedBox(height: 16),
        const Text('Map a key to a tap, or fill both end coordinates for a swipe.'),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          field(keyName, 'Key e.g. W'), field(x, 'Start X'), field(y, 'Start Y'),
          field(endX, 'End X (swipe)'), field(endY, 'End Y (swipe)'), field(duration, 'Duration ms'),
          FilledButton(onPressed: add, child: const Text('Save control')),
        ]),
        const SizedBox(height: 15),
        for (final entry in bindings.entries)
          ListTile(title: Text(entry.key),
            subtitle: Text(entry.value.length == 2
              ? 'Tap ${entry.value[0]}, ${entry.value[1]}'
              : 'Swipe ${entry.value.join(', ')}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
              profiles[package.text.trim()]?.remove(entry.key);
              await save();
              if (mounted) setState(() {});
            })),
        const SizedBox(height: 10),
        Text(notice),
        const SizedBox(height: 8),
        const Text('Input uses the phone’s primary screen coordinates and only works while this panel has keyboard focus.'),
      ])));
  }
}
