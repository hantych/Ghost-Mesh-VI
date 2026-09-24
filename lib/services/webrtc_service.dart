import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/io.dart';
import '../models/peer.dart';

typedef WRTCMessageCallback  = void Function(String peerId, Map<String, dynamic> data);
typedef WRTCPeerCallback     = void Function(Peer peer);
typedef WRTCPeerLostCallback = void Function(String peerId);

const _sigBase    = 'wss://0.peerjs.com/peerjs?key=peerjs&id=';
const _peersUrl   = 'https://0.peerjs.com/peerjs/peers';
const _gmPrefix   = 'gm-';
const _maxMsgBytes = 8192;
const _maxPeers   = 25; // security: cap concurrent peer connections
const _maxTextLen = 4096;
const _reconnDelay = Duration(seconds: 6);
const _discInterval = Duration(seconds: 30);

class WebRTCService {
  final WRTCMessageCallback  onMessage;
  final WRTCPeerCallback     onPeerFound;
  final WRTCPeerLostCallback onPeerLost;

  String _myId   = '';
  String _myName = '';
  bool   _hideFromRadar = false;

  IOWebSocketChannel? _ws;
  Timer? _pingTimer, _reconnTimer, _discTimer;
  bool   _wsConnected = false;

  final Map<String, RTCPeerConnection> _peerConns = {};
  final Map<String, RTCDataChannel>    _channels  = {};
  final Set<String>                    _knownPeers = {};
  final Map<String, _RateEntry>        _rateMap    = {};
  final Map<String, Timer>             _connTimeouts = {};

  WebRTCService({required this.onMessage, required this.onPeerFound, required this.onPeerLost});

  // ── Lifecycle ────────────────────────────────────────────────────────────
  Future<void> start(String myId, String myName) async {
    _myId   = myId.startsWith(_gmPrefix) ? myId : '$_gmPrefix$myId';
    _myName = myName;
    _connectSignaling();
    _startDiscovery();
  }

  void updatePrivacy({required bool hideFromRadar}) => _hideFromRadar = hideFromRadar;

  // ── Signaling ─────────────────────────────────────────────────────────────
  void _connectSignaling() {
    _ws?.sink.close();
    final url = '$_sigBase${Uri.encodeComponent(_myId)}&token=ghostmesh&version=1.1';
    try {
      _ws = IOWebSocketChannel.connect(Uri.parse(url),
          connectTimeout: const Duration(seconds: 10));
      _ws!.stream.listen(_handleSignal,
          onError: (_) => _schedReconnect(), onDone: () => _schedReconnect());
      _wsConnected = true;
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_wsConnected) try { _ws?.sink.add(jsonEncode({'type':'HEARTBEAT'})); } catch (_) {}
      });
    } catch (_) { _schedReconnect(); }
  }

  void _schedReconnect() {
    _wsConnected = false;
    _reconnTimer?.cancel();
    _reconnTimer = Timer(_reconnDelay, _connectSignaling);
  }

  void _handleSignal(dynamic raw) {
    if (raw is! String || raw.length > 16384) return;
    try {
      final msg  = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';
      switch (type) {
        case 'OPEN':     _startDiscovery(); break;
        case 'OFFER':    _handleOffer(msg); break;
        case 'ANSWER':   _handleAnswer(msg); break;
        case 'CANDIDATE':_handleCandidate(msg); break;
        case 'LEAVE': case 'EXPIRE':
          final src = msg['src'] as String? ?? '';
          if (src.isNotEmpty) _closePeer(src);
          break;
      }
    } catch (_) {}
  }

  // ── Discovery ─────────────────────────────────────────────────────────────
  void _startDiscovery() {
    _discTimer?.cancel();
    _discTimer = Timer.periodic(_discInterval, (_) => _discoverPeers());
    _discoverPeers();
  }

  Future<void> _discoverPeers() async {
    // Security: cap at max peers before trying new connections
    if (_peerConns.length >= _maxPeers) return;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req    = await client.getUrl(Uri.parse(_peersUrl));
      req.headers.set('Accept', 'application/json');
      final resp   = await req.close();
      if (resp.statusCode != 200) { client.close(); return; }
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      final list = jsonDecode(body) as List<dynamic>;
      for (final raw in list) {
        if (_peerConns.length >= _maxPeers) break;
        if (raw is! String) continue;
        // Security: strictly validate peer ID format
        if (!raw.startsWith(_gmPrefix)) continue;
        if (raw == _myId) continue;
        if (!RegExp(r'^gm-[a-zA-Z0-9\-]{8,64}$').hasMatch(raw)) continue;
        if (_channels.containsKey(raw) || _peerConns.containsKey(raw)) continue;
        await _initiateOffer(raw);
      }
    } catch (_) {}
  }

  // ── WebRTC Offer/Answer ───────────────────────────────────────────────────
  Future<void> _initiateOffer(String targetId) async {
    final pc = await _createPeerConn(targetId);
    final dc = await pc.createDataChannel('chat', RTCDataChannelInit()..ordered = true);
    _setupDataChannel(dc, targetId);

    _setupIceCandidates(pc, targetId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _sendSignal(targetId, 'OFFER', {
      'sdp': offer.sdp, 'type': offer.type,
      'metadata': {'id': _myId, 'name': _hideFromRadar ? 'Anonymous' : _myName},
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> msg) async {
    final src = msg['src'] as String? ?? '';
    if (!_isValidPeerId(src)) return;
    if (_peerConns.length >= _maxPeers) return; // security: reject if at limit

    final payload  = msg['payload'] as Map<String, dynamic>? ?? {};
    final sdp      = payload['sdp']  as String? ?? '';
    final type     = payload['type'] as String? ?? 'offer';
    final meta     = payload['metadata'] as Map<String, dynamic>? ?? {};
    final peerName = _sanitizeName(meta['name'] as String? ?? src);
    if (sdp.isEmpty) return;

    final pc = await _createPeerConn(src);
    pc.onDataChannel = (ch) => _setupDataChannel(ch, src);
    _setupIceCandidates(pc, src);

    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _sendSignal(src, 'ANSWER', {
      'sdp': answer.sdp, 'type': answer.type,
      'metadata': {'id': _myId, 'name': _hideFromRadar ? 'Anonymous' : _myName},
    });

    if (!_knownPeers.contains(src)) {
      _knownPeers.add(src);
      onPeerFound(Peer(id: src, name: peerName, source: PeerSource.internet, lastSeen: DateTime.now()));
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> msg) async {
    final src = msg['src'] as String? ?? '';
    if (!_isValidPeerId(src)) return;
    final payload  = msg['payload'] as Map<String, dynamic>? ?? {};
    final sdp      = payload['sdp']  as String? ?? '';
    final type     = payload['type'] as String? ?? 'answer';
    final meta     = payload['metadata'] as Map<String, dynamic>? ?? {};
    final peerName = _sanitizeName(meta['name'] as String? ?? src);
    if (sdp.isEmpty) return;

    final pc = _peerConns[src];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));

    if (!_knownPeers.contains(src)) {
      _knownPeers.add(src);
      onPeerFound(Peer(id: src, name: peerName, source: PeerSource.internet, lastSeen: DateTime.now()));
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> msg) async {
    final src     = msg['src'] as String? ?? '';
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};
    final cand    = payload['candidate']     as String? ?? '';
    final mid     = payload['sdpMid']        as String? ?? '';
    final idx     = payload['sdpMLineIndex'] as int?    ?? 0;
    if (src.isEmpty || cand.isEmpty) return;
    try { await _peerConns[src]?.addCandidate(RTCIceCandidate(cand, mid, idx)); } catch (_) {}
  }

  void _setupIceCandidates(RTCPeerConnection pc, String peerId) {
    pc.onIceCandidate = (c) {
      if (c.candidate != null) {
        _sendSignal(peerId, 'CANDIDATE', {
          'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMlineIndex,
        });
      }
    };
  }

  Future<RTCPeerConnection> _createPeerConn(String peerId) async {
    // Security: connection timeout — close if ICE doesn't complete in 30s
    _connTimeouts[peerId]?.cancel();
    _connTimeouts[peerId] = Timer(const Duration(seconds: 30), () {
      if (_channels[peerId] == null ||
          _channels[peerId]!.state != RTCDataChannelState.RTCDataChannelOpen) {
        _closePeer(peerId);
      }
    });

    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });

    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _closePeer(peerId);
      }
    };
    _peerConns[peerId] = pc;
    return pc;
  }

  void _setupDataChannel(RTCDataChannel dc, String peerId) {
    _channels[peerId] = dc;
    dc.onDataChannelState = (s) {
      if (s == RTCDataChannelState.RTCDataChannelOpen) {
        _connTimeouts[peerId]?.cancel();
        _knownPeers.add(peerId);
      } else if (s == RTCDataChannelState.RTCDataChannelClosed) {
        _closePeer(peerId);
      }
    };
    dc.onMessage = (m) {
      final raw = m.text;
      if (raw.length > _maxMsgBytes) return;
      if (!(_rateMap[peerId] ??= _RateEntry()).allow()) return;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _validateAndDispatch(peerId, data);
      } catch (_) {}
    };
  }

  void _validateAndDispatch(String peerId, Map<String, dynamic> data) {
    final type = data['type'];
    if (type is! String) return;

    // Security: enforce senderId = actual peerId (prevent impersonation)
    if (type == 'message') {
      data['sender_id'] = peerId; // override — trust the connection, not the payload
    }

    if (data['text'] is String && (data['text'] as String).length > _maxTextLen) return;
    if (data['id'] is! String?) return; // allow null or string only

    // Sanitize name fields
    for (final k in ['sender_name', 'name']) {
      if (data.containsKey(k) && data[k] is String) {
        data[k] = _sanitizeName(data[k] as String);
      }
    }
    onMessage(peerId, data);
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<bool> sendMessage(String peerId, Map<String, dynamic> data) async {
    final dc = _channels[peerId];
    if (dc == null || dc.state != RTCDataChannelState.RTCDataChannelOpen) return false;
    try {
      final encoded = jsonEncode(data);
      if (encoded.length > _maxMsgBytes) return false;
      dc.send(RTCDataChannelMessage(encoded));
      return true;
    } catch (_) { return false; }
  }

  void _sendSignal(String targetId, String type, Map<String, dynamic> payload) {
    if (!_wsConnected) return;
    try { _ws?.sink.add(jsonEncode({'type': type, 'dst': targetId, 'payload': payload})); }
    catch (_) {}
  }

  // ── Close ─────────────────────────────────────────────────────────────────
  void _closePeer(String peerId) {
    _connTimeouts[peerId]?.cancel();
    _connTimeouts.remove(peerId);
    _channels[peerId]?.close();
    _channels.remove(peerId);
    _peerConns[peerId]?.close();
    _peerConns.remove(peerId);
    if (_knownPeers.remove(peerId)) onPeerLost(peerId);
  }

  bool isConnected(String peerId) =>
      _channels[peerId]?.state == RTCDataChannelState.RTCDataChannelOpen;

  void dispose() {
    _pingTimer?.cancel(); _reconnTimer?.cancel(); _discTimer?.cancel();
    _connTimeouts.values.forEach((t) => t.cancel());
    _ws?.sink.close();
    for (final id in [..._peerConns.keys]) { _closePeer(id); }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isValidPeerId(String id) =>
      id.isNotEmpty && RegExp(r'^gm-[a-zA-Z0-9\-]{8,64}$').hasMatch(id);

  String _sanitizeName(String raw) =>
      raw.replaceAll(RegExp(r'[^\x20-\x7E\u0400-\u04FF]'), '').trim()
          .substring(0, raw.length.clamp(0, 64));
}

class _RateEntry {
  int _count = 0; DateTime _ws = DateTime.now();
  bool allow() {
    final now = DateTime.now();
    if (now.difference(_ws).inSeconds >= 10) { _count = 0; _ws = now; }
    if (_count >= 10) return false;
    _count++; return true;
  }
}
