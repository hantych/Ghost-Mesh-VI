import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  int _tab = 0;

  static const _tabs = ['APPEARANCE', 'RADAR', 'CHAT', 'PRIVACY', 'IDENTITY', 'ABOUT'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: context.read<AppProvider>().myName);
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = context.ac;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context)),
        title: Text('SETTINGS', style: TextStyle(color: c.accent,
          fontFamily: 'monospace', fontSize: 16, letterSpacing: 4)),
      ),
      body: Column(children: [
        // Tab bar
        Container(
          color: c.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: List.generate(_tabs.length, (i) => GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: _tab == i ? c.accent : Colors.transparent, width: 2))),
                child: Text(_tabs[i], style: TextStyle(
                  color: _tab == i ? c.accent : c.textMuted,
                  fontFamily: 'monospace', fontSize: 10, letterSpacing: 1)),
              ),
            ))),
          ),
        ),
        Divider(height: 1, color: c.border),
        Expanded(child: _buildTab(p, c)),
      ]),
    );
  }

  Widget _buildTab(AppProvider p, AppColors c) {
    switch (_tab) {
      case 0: return _appearance(p, c);
      case 1: return _radar(p, c);
      case 2: return _chat(p, c);
      case 3: return _privacy(p, c);
      case 4: return _identity(p, c);
      case 5: return _about(p, c);
      default: return const SizedBox.shrink();
    }
  }

  // ── APPEARANCE ─────────────────────────────────────────────────────────────
  Widget _appearance(AppProvider p, AppColors c) => _list([
    _sec('THEME', c),
    _row3(context, [ThemeMode.system, ThemeMode.dark, ThemeMode.light],
      (m) => m == ThemeMode.system ? 'AUTO' : m == ThemeMode.dark ? 'DARK' : 'LIGHT',
      (m) => p.themeMode == m, (m) => p.setThemeMode(m), c),

    _sec('ACCENT COLOR', c),
    ...AccentPreset.values.map((preset) {
      final sel  = p.accent == preset;
      final preC = AppTheme.colorsFor(preset, p.themeMode != ThemeMode.light);
      return _tap(
        onTap: () => p.setAccent(preset),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? preC.accentFaint : Colors.transparent,
            border: Border.all(color: sel ? preC.accent : c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: preC.accent, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(preset.label, style: TextStyle(color: sel ? preC.accent : c.textSecondary, fontFamily: 'monospace', fontSize: 12)),
            const Spacer(),
            if (sel) Icon(Icons.check, size: 14, color: preC.accent),
          ]),
        ),
      );
    }),

    _sec('FONT SIZE', c),
    _row4(context, FontScale.values, (v) => v.label.split(' ').first,
      (v) => p.fontScale == v, (v) => p.setFontScale(v), c),

    _sec('MESSAGE BUBBLES', c),
    _segmented(BubbleStyle.values, (v) => v.label.split(' ').first,
      (v) => p.bubbleStyle == v, (v) => p.setBubbleStyle(v), c),

    _sec('CHAT BACKGROUND', c),
    _row4(context, ChatBg.values, (v) => v.label,
      (v) => p.chatBg == v, (v) => p.setChatBg(v), c),

    _sec('TIME FORMAT', c),
    _row2(context, TimeFormat.values, (v) => v.label,
      (v) => p.timeFormat == v, (v) => p.setTimeFormat(v), c),

    _sec('OTHER', c),
    _toggle('Show avatar in chat', p.showAvatarInChat, p.setShowAvatarInChat, c),
    _toggle('Compact mode', p.compactMode, p.setCompactMode, c),
  ]);

  // ── RADAR ──────────────────────────────────────────────────────────────────
  Widget _radar(AppProvider p, AppColors c) => _list([
    _sec('DISPLAY', c),
    _toggle('Show peer names',           p.showNamesOnRadar,  p.setShowNamesOnRadar, c),
    _toggle('Show RSSI signal strength', p.showRssiOnRadar,   p.setShowRssiOnRadar, c),
    _toggle('Show offline peers in list',p.showOfflinePeers,  p.setShowOfflinePeers, c),

    _sec('RADAR SWEEP SPEED', c),
    _segmented(RadarSpeed.values, (v) => v.label,
      (v) => p.radarSpeed == v, (v) => p.setRadarSpeed(v), c),

    _sec('PEER LIST SORT ORDER', c),
    _segmented(PeerSort.values, (v) => v.label,
      (v) => p.peerSort == v, (v) => p.setPeerSort(v), c),

    _sec('BLUETOOTH SCAN INTERVAL', c),
    _infoRow('Current', '${p.scanIntervalSecs}s — lower = more battery', c),
    Slider(
      value: p.scanIntervalSecs.toDouble(),
      min: 10, max: 60, divisions: 10,
      activeColor: c.accent, inactiveColor: c.surfaceAlt,
      label: '${p.scanIntervalSecs}s',
      onChanged: (v) => p.setScanInterval(v.round()),
    ),
  ]);

  // ── CHAT ──────────────────────────────────────────────────────────────────
  Widget _chat(AppProvider p, AppColors c) => _list([
    _sec('BEHAVIOR', c),
    _toggle('Auto-scroll on new message', p.autoScroll, p.setAutoScroll, c),
    _toggle('Notifications', p.notificationsEnabled, p.setNotificationsEnabled, c),

    _sec('GHOST MODE', c),
    _toggle('Ghost mode by default', p.ghostDefault, p.setGhostDefault, c,
      subtitle: 'New chats open with ghost mode on'),

    _sec('AUTO-DELETE TIMER', c),
    _infoHint('Delete all messages in a chat after this time', c),
    _segmented(AutoDeleteTimer.values, (v) => v.label,
      (v) => p.autoDeleteTimer == v, (v) => p.setAutoDeleteTimer(v), c),

    _sec('DATA', c),
    _dangerBtn('Clear all message history', Icons.delete_outline, c, () => _confirmClear(p, c)),
  ]);

  // ── PRIVACY ────────────────────────────────────────────────────────────────
  Widget _privacy(AppProvider p, AppColors c) => _list([
    _sec('RADAR VISIBILITY', c),
    _toggle('Hide from radar', p.hideFromRadar, p.setHideFromRadar, c,
      subtitle: 'Advertise as "Anonymous" over Bluetooth'),

    _sec('GHOST MESSAGES', c),
    _toggle('Auto-delete ghost messages on disconnect', p.autoDeleteOnDisconnect, p.setAutoDeleteOnDisconnect, c),

    _sec('INFO', c),
    _infoCard('Ghost Mesh is a fully P2P messenger. No server stores your messages. BLE radar uses your device Bluetooth only in app-foreground or with the notification permission.', c),
  ]);

  // ── IDENTITY ──────────────────────────────────────────────────────────────
  Widget _identity(AppProvider p, AppColors c) => _list([
    _sec('YOUR GHOST ID', c),
    _tap(onTap: () {
      Clipboard.setData(ClipboardData(text: p.myId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ID copied', style: TextStyle(fontFamily: 'monospace', color: c.textPrimary)),
        backgroundColor: c.surface, duration: const Duration(seconds: 1)));
    }, child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Text(p.myId, style: TextStyle(color: c.accent, fontFamily: 'monospace', fontSize: 11))),
        Icon(Icons.copy, size: 14, color: c.textMuted),
      ]),
    )),
    const SizedBox(height: 4),
    Text('Tap to copy and share with friends',
      style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 10)),

    const SizedBox(height: 16),
    _sec('DISPLAY NAME', c),
    Row(children: [
      Expanded(child: _textField(_nameCtrl, 'Your name', c)),
      const SizedBox(width: 8),
      _iconBtn(Icons.check, c, onTap: () async {
        final n = _nameCtrl.text.trim();
        if (n.isEmpty) return;
        await p.setMyName(n);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Name updated', style: TextStyle(fontFamily: 'monospace', color: c.textPrimary)),
          backgroundColor: c.surface));
      }),
    ]),
  ]);

  // ── ABOUT ──────────────────────────────────────────────────────────────────
  Widget _about(AppProvider p, AppColors c) => _list([
    _sec('APP', c),
    _infoRow('Version',   'Ghost Mesh Offline v3.0', c),
    _infoRow('Mode',      'Bluetooth BLE + WebRTC P2P', c),
    _infoRow('Server',    'None (fully decentralized)', c),
    _infoRow('Accounts',  'Not required', c),
    _infoRow('Encryption','None (plain WebRTC)', c),
    const SizedBox(height: 12),
    _infoCard(
      '📡 Bluetooth (BLE): discovers devices in ~50m range. Uses local name prefix "GM:" for identification.\n\n'
      '🌐 WebRTC P2P: connects over the internet without a dedicated server. Uses public PeerJS signaling (peerjs.com) — no messages stored there.\n\n'
      '👻 Ghost mode: messages vanish when both devices go out of range.',
      c),
  ]);

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _list(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: children);

  Widget _sec(String t, AppColors c) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(t, style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 9, letterSpacing: 2.5)));

  Widget _toggle(String title, bool val, void Function(bool) onChanged, AppColors c, {String? subtitle}) =>
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: 12)),
        if (subtitle != null) Text(subtitle, style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 9)),
      ])),
      Switch(value: val, onChanged: onChanged, activeColor: c.accent,
        inactiveThumbColor: c.textMuted, inactiveTrackColor: c.surfaceAlt),
    ]);

  Widget _row2<T>(BuildContext ctx, List<T> vals, String Function(T) label,
    bool Function(T) sel, void Function(T) onTap, AppColors c) =>
    Row(children: vals.map((v) => Expanded(child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(onTap: () => onTap(v), child: _pill(label(v), sel(v), c)),
    ))).toList());

  Widget _row3<T>(BuildContext ctx, List<T> vals, String Function(T) label,
    bool Function(T) sel, void Function(T) onTap, AppColors c) =>
    Row(children: vals.map((v) => Expanded(child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(onTap: () => onTap(v), child: _pill(label(v), sel(v), c)),
    ))).toList());

  Widget _row4<T>(BuildContext ctx, List<T> vals, String Function(T) label,
    bool Function(T) sel, void Function(T) onTap, AppColors c) =>
    Wrap(spacing: 6, runSpacing: 6, children: vals.map((v) => GestureDetector(
      onTap: () => onTap(v), child: _pill(label(v), sel(v), c))).toList());

  Widget _segmented<T>(List<T> vals, String Function(T) label,
    bool Function(T) sel, void Function(T) onTap, AppColors c) =>
    Wrap(spacing: 6, runSpacing: 6, children: vals.map((v) => GestureDetector(
      onTap: () => onTap(v), child: _pill(label(v), sel(v), c))).toList());

  Widget _pill(String label, bool selected, AppColors c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: selected ? c.accentFaint : Colors.transparent,
      border: Border.all(color: selected ? c.accent : c.border),
      borderRadius: BorderRadius.circular(6)),
    child: Text(label, textAlign: TextAlign.center,
      style: TextStyle(color: selected ? c.accent : c.textMuted,
        fontFamily: 'monospace', fontSize: 10,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal)));

  Widget _infoRow(String k, String v, AppColors c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 11)),
      Text(v, style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 11)),
    ]));

  Widget _infoHint(String t, AppColors c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 9)));

  Widget _infoCard(String t, AppColors c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 10, height: 1.6)));

  Widget _dangerBtn(String label, IconData icon, AppColors c, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: Colors.red.shade400, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: Colors.red.shade400, fontFamily: 'monospace', fontSize: 12)),
      ])));

  Widget _tap({required Widget child, required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap, child: child);

  Widget _textField(TextEditingController ctrl, String hint, AppColors c) =>
    TextField(controller: ctrl,
      style: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: c.textMuted, fontFamily: 'monospace'),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: c.accent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true));

  Widget _iconBtn(IconData icon, AppColors c, {required VoidCallback onTap}) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.accentFaint, border: Border.all(color: c.accent), borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, color: c.accent, size: 18)));

  Future<void> _confirmClear(AppProvider p, AppColors c) async {
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      backgroundColor: c.surface,
      title: Text('Clear history?', style: TextStyle(color: c.textPrimary, fontFamily: 'monospace')),
      content: Text('All local messages will be deleted permanently.', style: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 12)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Cancel', style: TextStyle(color: c.textMuted, fontFamily: 'monospace'))),
        TextButton(onPressed: () => Navigator.pop(d, true),  child: Text('Delete', style: TextStyle(color: Colors.red.shade400, fontFamily: 'monospace'))),
      ]));
    if (ok == true) { await p.clearAllHistory(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('History cleared', style: TextStyle(fontFamily: 'monospace', color: c.textPrimary)), backgroundColor: c.surface)); }
  }
}
