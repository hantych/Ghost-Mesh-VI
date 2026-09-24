enum PeerSource { bluetooth, internet }

class Peer {
  final String id;
  final String name;
  final PeerSource source;
  final int rssi; // BLE signal strength (negative dBm), 0 for internet peers
  final DateTime lastSeen;
  bool isOnline;

  Peer({
    required this.id,
    required this.name,
    required this.source,
    this.rssi = 0,
    required this.lastSeen,
    this.isOnline = true,
  });

  Peer copyWith({
    String? id,
    String? name,
    PeerSource? source,
    int? rssi,
    DateTime? lastSeen,
    bool? isOnline,
  }) {
    return Peer(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// Normalized distance 0.0 (very close) to 1.0 (far / internet)
  /// RSSI ranges from about -30 (very close) to -100 (max range)
  double get normalizedDistance {
    if (source == PeerSource.internet) return 1.0;
    // Clamp rssi between -100 and -30
    final clamped = rssi.clamp(-100, -30);
    // Map -30 -> 0.05, -100 -> 0.85
    return ((clamped + 30) / (-100 + 30)).abs() * 0.80 + 0.05;
  }

  String get sourceEmoji => source == PeerSource.bluetooth ? '🔵' : '🌐';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Peer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
