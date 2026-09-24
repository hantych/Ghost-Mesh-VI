import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/peer.dart';

const String kGmPrefix     = 'GM:';
const int    kNameExpirySecs = 35;

typedef MessageCallback   = void Function(String peerId, Map<String, dynamic> data);
typedef PeerCallback      = void Function(Peer peer);
typedef PeerLostCallback  = void Function(String peerId);

class BluetoothMessagingService {
  final MessageCallback   onMessage;
  final PeerCallback      onPeerFound;
  final PeerLostCallback  onPeerLost;

  String myId   = '';
  String myName = '';
  bool   _hideFromRadar = false;

  final Map<String, int>      _rssiMap  = {};
  final Map<String, DateTime> _lastSeen = {};
  // Debounce: last RSSI sent for each peer
  final Map<String, int>      _lastRssiSent = {};

  StreamSubscription<List<ScanResult>>?      _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  Timer? _scanTimer;
  Timer? _expiryTimer;

  int _scanIntervalSecs = 15; // configurable

  BluetoothMessagingService({
    required this.onMessage,
    required this.onPeerFound,
    required this.onPeerLost,
  });

  String get _localName {
    // Security: truncate name to 20 chars to stay within BLE ad limits
    final safeName = (_hideFromRadar ? 'Anonymous' : myName)
        .replaceAll(':', '_') // prevent name injection via colon
        .substring(0, myName.length.clamp(0, 20));
    final shortId = myId.length >= 11 ? myId.substring(3, 11) : myId;
    return '$kGmPrefix$shortId:$safeName';
  }

  void setScanInterval(int secs) { _scanIntervalSecs = secs; }

  void _startAdvertising() {
    try {
      FlutterBluePlus.startAdvertising(
        localName: _localName,
        timeout:   const Duration(minutes: 10),
      );
    } catch (_) {}
  }

  void _stopAdvertising() { try { FlutterBluePlus.stopAdvertising(); } catch (_) {} }

  Future<void> start() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) return;

    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startAdvertising();
        _startScanning();
        _startExpiryWatcher();
      } else {
        _stopAdvertising();
        _stopScanning();
      }
    });

    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
      _startAdvertising();
      _startScanning();
      _startExpiryWatcher();
    }
  }

  void updatePrivacy({required bool hideFromRadar}) {
    _hideFromRadar = hideFromRadar;
    _stopAdvertising();
    _startAdvertising();
  }

  void _startScanning() {
    _scanTimer?.cancel();
    _doScan();
    _scanTimer = Timer.periodic(Duration(seconds: _scanIntervalSecs), (_) => _doScan());
  }

  void _stopScanning() {
    _scanTimer?.cancel();
    try { FlutterBluePlus.stopScan(); } catch (_) {}
  }

  void _doScan() async {
    try { await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10)); }
    catch (_) { return; }

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final rawName = r.advertisementData.localName.isNotEmpty
            ? r.advertisementData.localName : r.device.platformName;
        if (!rawName.startsWith(kGmPrefix)) continue;

        // Security-safe parsing: only split on first TWO colons
        // Format: GM:<8charId>:<displayName>
        // A name can contain colons — so we limit splits to 2
        final afterPrefix = rawName.substring(kGmPrefix.length);
        final colonIdx = afterPrefix.indexOf(':');
        if (colonIdx < 0) continue;

        final advertisedShortId = afterPrefix.substring(0, colonIdx);
        final peerName = afterPrefix.substring(colonIdx + 1)
            .replaceAll(RegExp(r'[^\x20-\x7E\u0400-\u04FF]'), '').trim();

        // Skip our own advertisement leaking back
        final myShortId = myId.length >= 11 ? myId.substring(3, 11) : myId;
        if (advertisedShortId == myShortId) continue;

        final peerId = r.device.remoteId.str;
        final rssi   = r.rssi;

        _rssiMap[peerId]  = rssi;
        _lastSeen[peerId] = DateTime.now();

        // Debounce: only notify if RSSI changed by > 3 dBm or peer is new
        final lastRssi = _lastRssiSent[peerId];
        if (lastRssi != null && (rssi - lastRssi).abs() < 3) continue;
        _lastRssiSent[peerId] = rssi;

        onPeerFound(Peer(
          id:       peerId,
          name:     peerName.isNotEmpty ? peerName : 'Ghost ${advertisedShortId.substring(0, advertisedShortId.length.clamp(0, 6))}',
          source:   PeerSource.bluetooth,
          rssi:     rssi,
          lastSeen: DateTime.now(),
        ));
      }
    });
  }

  void _startExpiryWatcher() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final expired = <String>[];
      _lastSeen.forEach((id, t) {
        if (now.difference(t).inSeconds > kNameExpirySecs) expired.add(id);
      });
      for (final id in expired) {
        _lastSeen.remove(id);
        _rssiMap.remove(id);
        _lastRssiSent.remove(id);
        onPeerLost(id);
      }
    });
  }

  int?  getRssi(String peerId)       => _rssiMap[peerId];
  bool  isConnected(String peerId)   => _lastSeen.containsKey(peerId);
  Future<bool> sendMessage(String peerId, Map<String, dynamic> data) async => false;

  void dispose() {
    _stopAdvertising();
    _stopScanning();
    _scanTimer?.cancel();
    _expiryTimer?.cancel();
    _scanSub?.cancel();
    _adapterSub?.cancel();
  }
}
