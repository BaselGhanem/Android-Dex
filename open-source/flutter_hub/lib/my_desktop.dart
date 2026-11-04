import 'package:flutter/material.dart';
import 'desktop_layout.dart';
import 'virtual_window_manager.dart';
import 'workspace_store.dart';

const _teal = Color(0xFF099999);
const _panel = Color(0xFF14272B);
const _muted = Color(0xFF95ABAF);

String appName(String package) {
  const names = {
    'com.whatsapp': 'WhatsApp',
    'com.whatsapp.w4b': 'WhatsApp Business',
    'org.telegram.messenger': 'Telegram',
    'com.google.android.gm': 'Gmail',
    'com.microsoft.teams': 'Microsoft Teams',
    'com.microsoft.office.excel': 'Excel',
    'com.google.android.youtube': 'YouTube',
    'com.spotify.music': 'Spotify',
    'com.android.chrome': 'Chrome',
  };
  if (names.containsKey(package)) return names[package]!;
  final name = package.split('.').last.replaceAll('_', ' ');
  return name.isEmpty ? package : name[0].toUpperCase() + name.substring(1);
}

IconData appSymbol(String package) {
  final key = package.toLowerCase();
  if (key.contains('whatsapp') || key.contains('telegram') ||
      key.contains('messenger')) return Icons.chat_bubble_outline;
  if (key.contains('excel') || key.contains('sheets')) return Icons.table_chart_outlined;
  if (key.contains('teams') || key.contains('zoom')) return Icons.video_call_outlined;
  if (key.contains('gmail') || key.contains('mail')) return Icons.mail_outline;
  if (key.contains('youtube') || key.contains('spotify')) return Icons.play_circle_outline;
  if (key.contains('game') || key.contains('steam')) return Icons.sports_esports_outlined;
  return Icons.android;
}

class MyDesktop extends StatefulWidget {
  const MyDesktop({super.key, required this.manager, required this.serial,
    required this.packages, required this.onOpenApp, required this.onLoadApps});
  final VirtualWindowManager manager;
  final String? serial;
  final List<String> packages;
  final Future<void> Function(String) onOpenApp;
  final Future<void> Function() onLoadApps;

  @override
  State<MyDesktop> createState() => _MyDesktopState();
}

class _MyDesktopState extends State<MyDesktop> {
  final store = WorkspaceStore();
  final search = TextEditingController();
  List<DesktopMonitor> monitors = [];
  int target = 0;
  String notice = 'Your workspace, your apps, your way.';
  bool busy = false;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    search.addListener(_redraw);
    _load();
  }

  void _redraw() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    search.removeListener(_redraw);
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await store.load();
      monitors = await DesktopWindowControl.monitors();
      final primary = monitors.indexWhere((m) => m.primary);
      target = primary >= 0 ? primary : 0;
    } catch (e) {
      notice = 'Workspace setup: ' + e.toString();
    }
    if (mounted) setState(() => ready = true);
  }

  Future<void> _do(Future<void> Function() task, String success) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (mounted) setState(() => notice = success);
    } catch (e) {
      if (mounted) setState(() => notice = 'Action failed: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<AppWindow> get running => widget.manager.windows.where((w) =>
    w.status == WindowStatus.running && w.device == widget.serial).toList();

  bool _isVisible(DesktopBounds rect) => monitors.any((screen) {
    final s = screen.bounds;
    return rect.x < s.x + s.width && rect.x + rect.width > s.x &&
      rect.y < s.y + s.height && rect.y + rect.height > s.y;
  });

  Future<void> _restore() => _do(() async {
    final device = widget.serial;
    if (device == null) throw StateError('Connect your Galaxy device first');
    if (monitors.isEmpty) throw StateError('No Windows monitor information');
    final pins = store.pinned(store.activeId);
    if (pins.isEmpty) throw StateError('Pin your preferred apps first');
    var opened = 0;
    for (final package in pins) {
      if (running.any((w) => w.package == package)) continue;
      var rect = store.savedBounds(store.activeId, package);
      if (rect == null || !_isVisible(rect)) {
        rect = DesktopWindowControl.tile(monitors[target], WindowTile.center);
      }
      await widget.manager.open(serial: device, package: package, placement: rect);
      opened++;
    }
    if (opened == 0) throw StateError('All pinned apps are already running');
  }, 'Saved workspace restored');

  Future<void> _save() => _do(() async {
    if (running.isEmpty) throw StateError('No active windows to save');
    var count = 0;
    for (final window in running) {
      final bounds = await widget.manager.actualBounds(window);
      await store.remember(window.package, bounds);
      count++;
    }
    notice = 'Saved ' + count.toString() + ' window positions';
  }, 'Window positions saved');

  Future<void> _balance() => _do(() async {
    if (running.isEmpty) throw StateError('Open your Android apps first');
    if (monitors.isEmpty) throw StateError('No Windows screens detected');
    final groups = <int, List<AppWindow>>{};
    final active = running;
    for (var i = 0; i < active.length; i++) {
      groups.putIfAbsent(i % monitors.length, () => []).add(active[i]);
    }
    for (final group in groups.entries) {
      final area = monitors[group.key].bounds;
      final columns = group.value.length == 1 ? 1 : 2;
      final rows = (group.value.length / columns).ceil();
      for (var i = 0; i < group.value.length; i++) {
        final column = i % columns;
        final row = i ~/ columns;
        final left = area.x + (area.width * column ~/ columns);
        final top = area.y + (area.height * row ~/ rows);
        final right = area.x + (area.width * (column + 1) ~/ columns);
        final bottom = area.y + (area.height * (row + 1) ~/ rows);
        final rect = DesktopBounds(left, top, right - left, bottom - top);
        await widget.manager.place(group.value[i], rect);
        await store.remember(group.value[i].package, rect);
      }
    }
  }, 'Windows balanced across connected monitors and saved');

  Future<void> _tile(AppWindow window, WindowTile side) => _do(() async {
    if (monitors.isEmpty) throw StateError('No Windows screens detected');
    final rect = DesktopWindowControl.tile(monitors[target], side);
    await widget.manager.place(window, rect);
    await store.remember(window.package, rect);
  }, 'Window arranged and saved');

  Widget card(Widget child) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: _panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF244146))),
    child: child,
  );

  Widget action(String label, IconData icon, VoidCallback callback) =>
      OutlinedButton.icon(onPressed: busy ? null : callback,
        icon: Icon(icon, size: 18), label: Text(label));

  @override
  Widget build(BuildContext context) {
    final profile = workspaceDefinitions.firstWhere((p) => p.id == store.activeId);
    final pinned = store.pinned(store.activeId);
    final filtered = widget.packages.where((p) =>
      p.toLowerCase().contains(search.text.toLowerCase()) ||
      appName(p).toLowerCase().contains(search.text.toLowerCase())).toList()
      ..sort((a, b) => appName(a).compareTo(appName(b)));
    return SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(profile.headline, style: const TextStyle(fontSize: 29,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(profile.subtitle, style: const TextStyle(color: _muted)),
      const SizedBox(height: 22),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MY WORKSPACES', style: TextStyle(
          color: _teal, letterSpacing: 1.3, fontSize: 12)),
        const SizedBox(height: 13),
        DropdownButtonFormField<String>(
          key: ValueKey(store.activeId), initialValue: store.activeId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Choose your focus'),
          items: workspaceDefinitions.map((p) => DropdownMenuItem(
            value: p.id, child: Text(p.name))).toList(),
          onChanged: ready && !busy ? (v) {
            if (v != null) _do(() => store.choose(v), 'Workspace switched');
          } : null,
        ),
        const SizedBox(height: 18),
        Text('Pinned apps for ' + profile.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        if (pinned.isEmpty) const Text(
          'Pin your everyday Android apps below to build this workspace.',
          style: TextStyle(color: _muted)),
        for (final package in pinned)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(appSymbol(package), color: _teal),
            title: Text(appName(package)),
            subtitle: Text(package, style: const TextStyle(
              fontSize: 11, color: _muted)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Open independent window',
                onPressed: busy || widget.serial == null ? null :
                  () => _do(() => widget.onOpenApp(package), 'Opening app'),
                icon: const Icon(Icons.open_in_new)),
              IconButton(tooltip: 'Unpin',
                onPressed: busy ? null : () => _do(
                  () => store.togglePin(package), 'App unpinned'),
                icon: const Icon(Icons.star, color: _teal)),
            ]),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: busy ? null : _restore,
            icon: const Icon(Icons.restore), label: const Text('Restore layout')),
          action('Save positions', Icons.save_outlined, _save),
        ]),
      ])),
      const SizedBox(height: 16),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR TWO-SCREEN DESK', style: TextStyle(
          color: _teal, letterSpacing: 1.3, fontSize: 12)),
        const SizedBox(height: 10),
        Text(monitors.isEmpty ? 'No displays detected' :
          monitors.length.toString() + ' Windows display(s) connected',
          style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (monitors.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey(target), initialValue: target, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Target screen'),
            items: [
              for (var i = 0; i < monitors.length; i++)
                DropdownMenuItem(value: i, child: Text(
                  'Monitor ' + (i + 1).toString() +
                  (monitors[i].primary ? ' · Primary' : ' · Secondary') +
                  ' (' + monitors[i].bounds.width.toString() +
                  '×' + monitors[i].bounds.height.toString() + ')')),
            ],
            onChanged: busy ? null : (v) {
              if (v != null) setState(() => target = v);
            },
          ),
        const SizedBox(height: 13),
        Wrap(spacing: 9, runSpacing: 9, children: [
          action('Auto arrange across screens', Icons.view_quilt_outlined, _balance),
          action('Refresh screens', Icons.refresh, () => _do(() async {
            monitors = await DesktopWindowControl.monitors();
            if (target >= monitors.length) target = 0;
          }, 'Monitor list refreshed')),
        ]),
        const SizedBox(height: 12),
        const Text('Your placements stay saved in your Windows profile.',
          style: TextStyle(color: _muted, fontSize: 12)),
      ])),
      const SizedBox(height: 16),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MY RUNNING WINDOWS', style: TextStyle(
          color: _teal, letterSpacing: 1.3, fontSize: 12)),
        if (running.isEmpty) const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Your Android desktop is clear.',
            style: TextStyle(color: _muted))),
        for (final window in running)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(appName(window.package)),
            subtitle: Text(window.package, style: const TextStyle(
              fontSize: 11, color: _muted)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Bring to front',
                onPressed: busy ? null : () => _do(
                  () => widget.manager.focus(window), 'Window focused'),
                icon: const Icon(Icons.open_in_browser)),
              PopupMenuButton<WindowTile>(
                tooltip: 'Place on selected monitor',
                onSelected: (v) => _tile(window, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: WindowTile.left, child: Text('Left half')),
                  PopupMenuItem(value: WindowTile.right, child: Text('Right half')),
                  PopupMenuItem(value: WindowTile.full, child: Text('Fill monitor')),
                  PopupMenuItem(value: WindowTile.center, child: Text('Center')),
                ],
                icon: const Icon(Icons.dashboard_customize_outlined)),
              IconButton(tooltip: 'Close app window',
                onPressed: () => widget.manager.close(window.id),
                icon: const Icon(Icons.close)),
            ]),
          ),
      ])),
      const SizedBox(height: 16),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('APP DRAWER', style: TextStyle(
          color: _teal, letterSpacing: 1.3, fontSize: 12)),
        const SizedBox(height: 10),
        const Text('Pin your essentials and launch anything in one click.',
          style: TextStyle(color: _muted)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextField(controller: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Find an app'))),
          const SizedBox(width: 10),
          action('Load apps', Icons.refresh,
            () => _do(widget.onLoadApps, 'Android app drawer refreshed')),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 280,
          child: filtered.isEmpty
            ? const Center(child: Text('Connect your phone and load apps.',
                style: TextStyle(color: _muted)))
            : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
                final package = filtered[i];
                final pinned = store.isPinned(store.activeId, package);
                return ListTile(
                  dense: true,
                  leading: Icon(appSymbol(package), color: _teal),
                  title: Text(appName(package)),
                  subtitle: Text(package, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: pinned ? 'Unpin' : 'Pin to workspace',
                      onPressed: busy ? null : () => _do(
                        () => store.togglePin(package), 'Pinned apps updated'),
                      icon: Icon(pinned ? Icons.star : Icons.star_border,
                        color: pinned ? _teal : _muted)),
                    IconButton(
                      tooltip: 'Open independent window',
                      onPressed: busy || widget.serial == null ? null :
                        () => _do(() => widget.onOpenApp(package), 'Opening app'),
                      icon: const Icon(Icons.open_in_new)),
                  ]),
                );
              })),
      ])),
      const SizedBox(height: 15),
      if (busy) const LinearProgressIndicator(minHeight: 2),
      Text(notice, style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 20),
    ]));
  }
}

class HubTaskbar extends StatelessWidget {
  const HubTaskbar({super.key, required this.manager,
    required this.onNotice, required this.onWorkspace});
  final VirtualWindowManager manager;
  final ValueChanged<String> onNotice;
  final VoidCallback onWorkspace;

  @override
  Widget build(BuildContext context) {
    final windows = manager.windows.where((w) =>
      w.status == WindowStatus.running || w.status == WindowStatus.starting).toList();
    return Container(height: 55, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _panel,
        border: Border.all(color: const Color(0xFF244146)),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        IconButton(tooltip: 'Open My Desktop', onPressed: onWorkspace,
          icon: const Icon(Icons.dashboard, color: _teal)),
        const VerticalDivider(indent: 12, endIndent: 12,
          color: Color(0xFF284348)),
        Expanded(child: windows.isEmpty
          ? const Align(alignment: Alignment.centerLeft,
              child: Text("Basel's desk is ready",
                style: TextStyle(color: _muted, fontSize: 12)))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: windows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final win = windows[i];
                return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try { await manager.focus(win); }
                      catch (e) { onNotice('Cannot focus window: ' + e.toString()); }
                    },
                    icon: Icon(appSymbol(win.package), size: 16),
                    label: Text(appName(win.package))));
              })),
        Text(windows.length.toString() + ' windows',
          style: const TextStyle(color: _muted, fontSize: 11)),
      ]));
  }
}
