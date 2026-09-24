import 'dart:math';
import 'package:flutter/material.dart';
import '../models/peer.dart';
import '../theme/app_theme.dart';

class RadarPainter extends CustomPainter {
  final List<Peer> peers;
  final double     sweep;
  final AppColors  colors;
  final bool       showRssi;
  final bool       showNames;

  RadarPainter({
    required this.peers,
    required this.sweep,
    required this.colors,
    this.showRssi  = true,
    this.showNames = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = size.width  / 2 - 20;

    // ── Grid circles ─────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = colors.border;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 4, gridPaint);
    }

    // ── Cross hairs ───────────────────────────────────────────────────────────
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), gridPaint);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), gridPaint);

    // ── Sweep gradient ────────────────────────────────────────────────────────
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweep - 0.8,
        endAngle:   sweep,
        colors: [Colors.transparent, colors.accent.withOpacity(0.25)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, sweepPaint);

    // ── Sweep line ────────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = colors.accent.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * cos(sweep), cy + r * sin(sweep)),
      linePaint,
    );

    // ── Peer dots ─────────────────────────────────────────────────────────────
    for (final peer in peers) {
      final (px, py) = _peerPosition(peer, cx, cy, r);
      final isInternet = peer.source == PeerSource.internet;

      // Outer glow
      canvas.drawCircle(
        Offset(px, py), 7,
        Paint()..color = (isInternet ? colors.accentDim : colors.accent).withOpacity(0.2),
      );

      // Dot
      canvas.drawCircle(
        Offset(px, py), 4,
        Paint()..color = isInternet ? colors.accentDim : colors.accent,
      );

      // Source ring
      if (isInternet) {
        canvas.drawCircle(Offset(px, py), 6,
          Paint()
            ..color = colors.accentDim.withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      // Label
      if (showNames || showRssi) {
        final parts = <String>[];
        if (showNames) parts.add(peer.name.length > 12 ? '${peer.name.substring(0, 12)}…' : peer.name);
        if (showRssi && peer.rssi != null) parts.add('${peer.rssi} dBm');

        if (parts.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: parts.join('\n'),
              style: TextStyle(
                color: isInternet ? colors.accentDim : colors.accent,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          // Nudge label so it doesn't overlap the dot
          final lx = (px + 8).clamp(4.0, size.width - tp.width - 4);
          final ly = (py - 6).clamp(4.0, size.height - tp.height - 4);
          tp.paint(canvas, Offset(lx, ly));
        }
      }
    }

    // ── Centre dot ────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy), 4,
      Paint()..color = colors.accent,
    );
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()
        ..color = colors.accent.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  (double, double) _peerPosition(Peer peer, double cx, double cy, double r) {
    if (peer.rssi != null) {
      // RSSI -40 → near, -90 → far
      final normalized = ((-peer.rssi! - 40) / 50.0).clamp(0.0, 1.0);
      final dist  = normalized * r * 0.85 + r * 0.05;
      final angle = peer.id.hashCode % 360 * pi / 180;
      return (cx + dist * cos(angle), cy + dist * sin(angle));
    }
    // Internet peers placed in an outer ring at a fixed angle
    final angle = peer.id.hashCode % 360 * pi / 180;
    return (cx + r * 0.75 * cos(angle), cy + r * 0.75 * sin(angle));
  }

  @override
  bool shouldRepaint(RadarPainter old) =>
      old.sweep != sweep || old.peers != peers ||
      old.showRssi != showRssi || old.showNames != showNames;
}
