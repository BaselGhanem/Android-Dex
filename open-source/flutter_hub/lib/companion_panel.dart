import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'android_bridge.dart';

class CompanionPanel extends StatefulWidget {
  const CompanionPanel({super.key, required this.bridge, required this.serial});
  final AndroidBridge bridge;
  final String? serial;
  @override
  State<CompanionPanel> createState() => _CompanionPanelState();
}

class _CompanionPanelState extends State<CompanionPanel> {
  final token = TextEditingController();
  Map<String, dynamic>? status;
  String notice = 'Start Basel Companion on your Galaxy and enter its access code.';
  bool busy = false;
  @override void dispose() { token.dispose(); super.dispose(); }

  Future<void> read() async {
    final serial = widget.serial;
    if (serial == null || busy) return;
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(token.text.trim())) {
      setState(() => notice = 'Enter the 48-character access code shown on your Galaxy.');
      return;
    }
    setState(() => busy = true);
    String? local;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final port = (await widget.bridge.adb(['-s', serial, 'forward', 'tcp:0', 'tcp:37971'])).trim();
      if (!RegExp(r'^\d{1,5}$').hasMatch(port)) throw StateError('ADB did not provide a local port.');
      local = 'tcp:$port';
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/status'))
        .timeout(const Duration(seconds: 5));
      request.headers.set('X-Basel-Token', token.text.trim());
      final response = await request.close().timeout(const Duration(seconds: 5));
      final text = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) throw StateError('Phone rejected the access code.');
      final raw = jsonDecode(text);
      if (raw is! Map) throw const FormatException('Unexpected response from phone.');
      if (mounted) setState(() {
        status = Map<String, dynamic>.from(raw);
        notice = 'Updated from your Galaxy.';
      });
    } catch (e) {
      if (mounted) setState(() => notice = 'Could not connect: $e');
    } finally {
      client.close(force: true);
      if (local != null) {
        try { await widget.bridge.adb(['-s', serial, 'forward', '--remove', local]); } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> media(int code) async {
    final serial = widget.serial;
    if (serial == null) return;
    try {
      await widget.bridge.key(serial, code);
      if (mounted) setState(() => notice = 'Media command sent to your Galaxy.');
    } catch (e) { if (mounted) setState(() => notice = 'Media command failed: $e'); }
  }

  @override Widget build(BuildContext context) {
    final items = status?['notifications'];
    final notifications = items is List ? items : [];
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Basel's Galaxy Companion", style: TextStyle(fontSize: 29, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Your phone status and notifications, close to your work.'),
      const SizedBox(height: 20),
      TextField(controller: token, obscureText: true, enableSuggestions: false,
        autocorrect: false, decoration: const InputDecoration(labelText: 'Companion access code')),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: busy || widget.serial == null ? null : read,
          icon: const Icon(Icons.refresh), label: const Text('Refresh my Galaxy')),
        OutlinedButton.icon(onPressed: widget.serial == null ? null : () => media(88),
          icon: const Icon(Icons.skip_previous), label: const Text('Previous')),
        OutlinedButton.icon(onPressed: widget.serial == null ? null : () => media(85),
          icon: const Icon(Icons.play_arrow), label: const Text('Play / pause')),
        OutlinedButton.icon(onPressed: widget.serial == null ? null : () => media(87),
          icon: const Icon(Icons.skip_next), label: const Text('Next')),
      ]),
      const SizedBox(height: 18),
      if (status != null) Text('Battery: ${status!['battery']}%   ·   Network: ${status!['network']}'),
      if (status != null && status!['notificationAccess'] != true)
        const Padding(padding: EdgeInsets.only(top: 12),
          child: Text('Notification access is off. Enable it in Basel Companion on your phone.')),
      const SizedBox(height: 12),
      if (status != null && notifications.isEmpty) const Text('No active notifications to show.'),
      for (final item in notifications)
        if (item is Map) ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text('${item['title'] ?? ''}'),
          subtitle: Text('${item['package'] ?? ''}\n${item['text'] ?? ''}')),
      const SizedBox(height: 12),
      Text(notice),
      const SizedBox(height: 8),
      const Text('The bridge runs locally through ADB while it is enabled on your phone.'),
    ]));
  }
}
