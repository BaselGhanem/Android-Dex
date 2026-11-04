import 'package:flutter/material.dart';
import 'android_bridge.dart';
import 'virtual_window_manager.dart';
import 'my_desktop.dart';


void main() => runApp(const BaselDesktopHub());

const accent = Color(0xFF099999);
const bg = Color(0xFF0B1619);
const surface = Color(0xFF14272B);
const muted = Color(0xFF95ABAF);

class BaselDesktopHub extends StatelessWidget {
  const BaselDesktopHub({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Basel Desktop Hub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: accent, surface: surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF1B3438),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final bridge = AndroidBridge();
  final virtualWindows = VirtualWindowManager();
  final query = TextEditingController();
  final wifi = TextEditingController();
  final file = TextEditingController();
  List<String> devices = [];
  List<String> apps = [];
  String? selected;
  String battery = '?';
  String message = 'Connect an Android device with USB debugging enabled';
  int tab = 4; // Open Basel's personalized desktop first.
  bool busy = false;

  @override
  void initState() {
    super.initState();
    query.addListener(() { if (mounted) setState(() {}); });
    virtualWindows.changes.listen((_) { if (mounted) setState(() {}); });
    refresh();
  }

  @override
  void dispose() {
    query.dispose();
    wifi.dispose();
    file.dispose();
    virtualWindows.dispose();
    super.dispose();
  }

  Future<void> execute(Future<void> Function() operation, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
      if (mounted && success != null) setState(() => message = success);
    } catch (e) {
      if (mounted) setState(() => message = 'Error: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() => execute(() async {
    final found = await bridge.devices();
    final serial = found.contains(selected) ? selected : (found.isEmpty ? null : found.first);
    String level = '?';
    if (serial != null) {
      try { level = await bridge.battery(serial); } catch (_) {}
    }
    if (mounted) setState(() {
      devices = found;
      if (selected != serial) apps = [];
      selected = serial;
      battery = level;
      message = serial == null ? 'No authorized device detected' : 'Device connected: ' + serial;
    });
  });

  Future<void> loadApps({bool switchToApplications = true}) => execute(() async {
    if (selected == null) throw StateError('Connect a device first');
    final installed = await bridge.packages(selected!);
    if (mounted) setState(() {
      apps = installed;
      if (switchToApplications) tab = 1;
    });
  }, success: 'Application list refreshed');

  Future<void> launch(String pkg) => execute(() async {
    if (selected == null) throw StateError('No selected device');
    await bridge.launch(selected!, pkg);
  }, success: 'Launch requested: ' + pkg);

  Future<void> openIndependent(String pkg, {bool switchToWindows = true}) => execute(() async {
    if (selected == null) throw StateError('No selected device');
    final window = await virtualWindows.open(serial: selected!, package: pkg);
    if (mounted) setState(() {
      message = 'Virtual display started for ' + window.package +
          ' (window ' + window.id.toString() + ')';
      if (switchToWindows) tab = 3;
    });
  });

  Future<void> openFromDesktop(String pkg) async {
    final device = selected;
    if (device == null) throw StateError('Connect your phone first');
    await virtualWindows.open(serial: device, package: pkg);
  }

  Future<void> mirror() => execute(() async {
    if (selected == null) throw StateError('No selected device');
    await bridge.mirror(selected!);
  }, success: 'Mirror opened in scrcpy');

  Future<void> screenshot() => execute(() async {
    if (selected == null) throw StateError('No selected device');
    final path = await bridge.screenshot(selected!);
    if (mounted) setState(() => message = 'Screenshot saved: ' + path);
  });

  Widget button(String label, IconData icon, VoidCallback onPressed, {bool secondary = false}) {
    return secondary
        ? OutlinedButton.icon(onPressed: busy ? null : onPressed,
            icon: Icon(icon), label: Text(label))
        : FilledButton.icon(onPressed: busy ? null : onPressed,
            icon: Icon(icon), label: Text(label));
  }

  Widget card(Widget child) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: surface, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF244146))),
    child: child,
  );

  Widget title(String headline, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(headline, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: muted)),
    ]),
  );

  Widget overview() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    title("Basel's Workspace", 'Sales insights. X Academy. Building what comes next.'),
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.smartphone, color: accent, size: 27),
        SizedBox(width: 10),
        Text('My Galaxy connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 23),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Authorized device'),
          items: devices.map((d) => DropdownMenuItem(
            value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() { selected = value; apps = []; }),
        )),
        const SizedBox(width: 12),
        button('Refresh', Icons.refresh, refresh, secondary: true),
      ]),
      const SizedBox(height: 16),
      Text('Battery level: ' + battery + '%',
          style: const TextStyle(color: muted)),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [
        button('Mirror device', Icons.cast, mirror),
        button('My apps', Icons.apps, () => loadApps(), secondary: true),
        button('Screenshot', Icons.camera_alt_outlined, screenshot, secondary: true),
      ]),
    ])),
    const SizedBox(height: 19),
    card(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('LOCAL FIRST', style: TextStyle(color: accent, letterSpacing: 1.3)),
      SizedBox(height: 10),
      Text('USB or Wi-Fi ADB. Screen mirroring is handled by scrcpy.'),
      SizedBox(height: 8),
      Text('Independent virtual-display windows use scrcpy; support depends on Android and the app.',
          style: TextStyle(color: muted)),
    ])),
  ]);

  Widget appList() {
    final shown = apps.where((p) =>
      p.toLowerCase().contains(query.text.toLowerCase().trim())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      title('My Android apps', 'Launch the tools that keep your day moving'),
      Row(children: [
        Expanded(child: TextField(controller: query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Search Android package'))),
        const SizedBox(width: 12),
        button('Load Apps', Icons.refresh, () => loadApps(), secondary: true),
      ]),
      const SizedBox(height: 15),
      Text(shown.length.toString() + ' applications',
        style: const TextStyle(color: muted)),
      const SizedBox(height: 9),
      Expanded(child: card(ListView.separated(
        itemCount: shown.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF284348)),
        itemBuilder: (context, index) {
          final pkg = shown[index];
          return ListTile(
            leading: const Icon(Icons.android, color: accent),
            title: Text(pkg, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Wrap(spacing: 6, children: [
              IconButton(tooltip: 'Launch on phone', onPressed: busy ? null : () => launch(pkg),
                  icon: const Icon(Icons.play_arrow)),
              IconButton(tooltip: 'Open independent app window',
                  onPressed: busy ? null : () => openIndependent(pkg),
                  icon: const Icon(Icons.open_in_new)),
            ]),
          );
        },
      ))),
      const Padding(padding: EdgeInsets.only(top: 8),
          child: Text('Independent app windows require scrcpy virtual display support. Some apps/devices may reject them.',
              style: TextStyle(color: muted, fontSize: 12))),
    ]);
  }

  Widget windowList() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    title('My app windows', 'Every app, exactly where you need it'),
    Row(children: [
      Text(virtualWindows.windows.where((w) => w.status == WindowStatus.running).length.toString() +
        ' running', style: const TextStyle(color: muted)),
      const Spacer(),
      button('Clear finished', Icons.cleaning_services_outlined,
        virtualWindows.clearFinished, secondary: true),
    ]),
    const SizedBox(height: 15),
    Expanded(child: card(virtualWindows.windows.isEmpty
      ? const Center(child: Text('Open an app using the new window button in Applications.',
          style: TextStyle(color: muted)))
      : ListView.separated(
          itemCount: virtualWindows.windows.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF284348)),
          itemBuilder: (context, index) {
            final w = virtualWindows.windows[index];
            final active = w.status == WindowStatus.running || w.status == WindowStatus.starting;
            return ListTile(
              leading: Icon(Icons.web_asset_outlined,
                color: active ? accent : muted),
              title: Text(w.package),
              subtitle: Text(w.status.name +
                  (w.diagnostic.isEmpty ? '' : ' - ' + w.diagnostic),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted)),
              trailing: IconButton(
                tooltip: 'Close this virtual display',
                onPressed: active ? () => virtualWindows.close(w.id) : null,
                icon: const Icon(Icons.close)),
            );
          },
        ))),
    const SizedBox(height: 12),
    const Text('Each app has its own scrcpy virtual display. Close an app window to end that display.',
        style: TextStyle(color: muted, fontSize: 12)),
  ]);

  Widget tools() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    title('My phone controls', 'Your Galaxy, managed from the desktop'),
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Connect an existing Wi-Fi ADB endpoint',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 13),
      Row(children: [
        Expanded(child: TextField(controller: wifi,
          decoration: const InputDecoration(hintText: '192.168.1.10:5555'))),
        const SizedBox(width: 12),
        button('Connect', Icons.wifi, () => execute(() async {
          await bridge.connectWifi(wifi.text.trim());
          final found = await bridge.devices();
          if (mounted) setState(() {
            devices = found;
            selected = found.isEmpty ? null : found.last;
          });
        }, success: 'ADB connection requested'), secondary: true),
      ]),
      const SizedBox(height: 12),
      const Text('Wireless Debugging pairing is not included in this version.',
        style: TextStyle(color: muted)),
    ])),
    const SizedBox(height: 16),
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Transfer local file into Android Downloads',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 13),
      TextField(controller: file,
          decoration: const InputDecoration(hintText: 'Absolute Windows file path')),
      const SizedBox(height: 13),
      button('Send File', Icons.upload_file, () => execute(() async {
        if (selected == null) throw StateError('No selected device');
        await bridge.pushFile(selected!, file.text.trim());
      }, success: 'File transferred to Android Downloads')),
    ])),
    const SizedBox(height: 16),
    card(Wrap(spacing: 12, runSpacing: 10, children: [
      button('Home', Icons.home_outlined, () => key(3), secondary: true),
      button('Back', Icons.arrow_back, () => key(4), secondary: true),
      button('Recents', Icons.crop_square, () => key(187), secondary: true),
      button('Power', Icons.power_settings_new, () => key(26), secondary: true),
    ])),
  ]);

  void key(int code) => execute(() async {
    if (selected == null) throw StateError('No selected device');
    await bridge.key(selected!, code);
  }, success: 'Device command sent');

  Widget nav(int index, IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      selected: tab == index, selectedTileColor: accent.withAlpha(36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: tab == index ? accent : muted),
      title: Text(label, style: TextStyle(color: tab == index ? Colors.white : muted)),
      onTap: () => setState(() => tab = index),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(children: [
      Container(width: 245, padding: const EdgeInsets.fromLTRB(18, 27, 18, 20),
        color: const Color(0xFF102024),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.hub_outlined, size: 29, color: accent),
            SizedBox(width: 9),
            Text('BASEL HUB', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          const Text('Android desktop workspace',
            style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 42),
          nav(0, Icons.dashboard_outlined, 'Overview'),
          nav(1, Icons.apps, 'Applications'),
          nav(2, Icons.tune, 'Device Tools'),
          nav(3, Icons.web_asset_outlined, 'App Windows'),
          nav(4, Icons.desktop_windows_outlined, 'My Desktop'),
          const Spacer(),
          const Text('OPEN SOURCE  ·  v0.4',
            style: TextStyle(color: muted, fontSize: 11)),
        ])),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 22),
        child: Column(children: [
          Expanded(child: tab == 1 ? appList() :
            tab == 3 ? windowList() :
            tab == 4 ? MyDesktop(
              manager: virtualWindows,
              serial: selected,
              packages: apps,
              onOpenApp: openFromDesktop,
              onLoadApps: () => loadApps(switchToApplications: false),
            ) :
            SingleChildScrollView(child: tab == 0 ? overview() : tools())),
          const SizedBox(height: 13),
          HubTaskbar(
            manager: virtualWindows,
            onNotice: (text) { if (mounted) setState(() => message = text); },
            onWorkspace: () => setState(() => tab = 4),
          ),
          const SizedBox(height: 10),
          Row(children: [
            if (busy) const Padding(padding: EdgeInsets.only(right: 10),
              child: SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))),
            const Icon(Icons.info_outline, color: muted, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 12))),
          ]),
        ]),
      )),
    ]),
  );
}
