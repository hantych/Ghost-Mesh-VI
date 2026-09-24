import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/radar_painter.dart';
import '../theme/app_theme.dart';
import '../models/peer.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});
  @override State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepCtrl;

  @override
  void initState() {
    super.initState();
    _updateSweepSpeed(context.read<AppProvider>().radarSpeed);
  }

  void _updateSweepSpeed(RadarSpeed speed) {
    if (_sweepCtrl.isAnimating) _sweepCtrl.stop();
    _sweepCtrl = AnimationController(vsync: this, duration: speed.dur)..repeat();
  }

  @override
  void dispose() { _sweepCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c        = context.ac;

    // React to radar speed changes
    if (_sweepCtrl.duration != provider.radarSpeed.dur) {
      _updateSweepSpeed(provider.radarSpeed);
    }

    final onlinePeers = provider.peerList.where((p) => p.isOnline).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface, elevation: 0,
        title: Row(children: [
          Text('◎ ', style: TextStyle(color: c.accent, fontSize: 20)),
          Text('GHOST MESH', style: TextStyle(color: c.accent, fontFamily: 'monospace',
            fontSize: 16, letterSpacing: 4)),
        ]),
        actions: [
          if (onlinePeers.isNotEmpty)
            Center(child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.accentFaint, border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${onlinePeers.length} IN RANGE',
                style: TextStyle(color: c.accent, fontFamily: 'monospace', fontSize: 9)),
            )),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: c.textSecondary),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, __) => CustomPaint(
              painter: RadarPainter(
                peers:     onlinePeers,
                sweep:     _sweepCtrl.value * 2 * pi,
                colors:    c,
                showRssi:  provider.showRssiOnRadar,
                showNames: provider.showNamesOnRadar,
              ),
              child: Container(),
            ),
          ),
        ),
        _buildPeerList(c, provider),
      ]),
    );
  }

  Widget _buildPeerList(AppColors c, AppProvider provider) {
    final peers = provider.sortedPeerList;
    if (peers.isEmpty) {
      return Container(height: 110, alignment: Alignment.center, child:
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('scanning for nearby devices…',
            style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 11)),
          const SizedBox(height: 4),
          Text('make sure Bluetooth is on',
            style: TextStyle(color: c.textMuted.withOpacity(0.5), fontFamily: 'monospace', fontSize: 9)),
        ]));
    }
    return Container(
      constraints: BoxConstraints(maxHeight: provider.compactMode ? 140 : 200),
      decoration: BoxDecoration(
        color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: provider.compactMode ? 2 : 4),
        itemCount: peers.length,
        itemBuilder: (_, i) {
          final peer = peers[i];
          final rssi = provider.getBluetoothRssi(peer.id);
          return ListTile(
            dense: provider.compactMode,
            leading: provider.showAvatarInChat
                ? CircleAvatar(radius: 16, backgroundColor: c.accentFaint,
                    child: Text(peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                      style: TextStyle(color: c.accent, fontSize: 12)))
                : Text(peer.sourceEmoji, style: const TextStyle(fontSize: 18)),
            title: Text(peer.name, style: TextStyle(color: c.textPrimary,
              fontFamily: 'monospace', fontSize: provider.fontScale.size - 1)),
            subtitle: Text(
              peer.isOnline ? (rssi != null ? '$rssi dBm' : peer.source == PeerSource.bluetooth ? 'BLE' : 'P2P') : 'OFFLINE',
              style: TextStyle(color: peer.isOnline ? c.textMuted : c.offline,
                fontFamily: 'monospace', fontSize: 9)),
            trailing: peer.isOnline ? Icon(Icons.chevron_right, color: c.textMuted, size: 18) : null,
            onTap: peer.isOnline
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)))
                : null,
          );
        },
      ),
    );
  }
}
