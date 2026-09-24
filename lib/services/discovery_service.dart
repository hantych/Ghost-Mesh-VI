import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/peer.dart';
import '../models/message.dart';
import 'bluetooth_service.dart';
import 'webrtc_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';

typedef DiscoveryPeerCallback     = void Function(Peer peer);
typedef DiscoveryPeerLostCallback = void Function(String peerId);
typedef DiscoveryMessageCallback  = void Function(String peerId, Message message);

class DiscoveryService {
  final DiscoveryPeerCallback     onPeerFound;
  final DiscoveryPeerLostCallback onPeerLost;
  final DiscoveryMessageCallback  onMessageReceived;
  final bool autoDeleteOnDisconnect;

  late BluetoothMessagingService _bt;
  late WebRTCService             _webrtc;
  final StorageService           _storage       = StorageService();
  final NotificationService      _notifications = NotificationService();

  String myId   = '';
  String myName = '';

  final Map<String, List<String>> _ghostMessages = {};

  DiscoveryService({
    required this.onPeerFound, required this.onPeerLost,
    required this.onMessageReceived, this.autoDeleteOnDisconnect = true,
  });

  Future<void> init() async {
    await _notifications.init();
    final prefs = await SharedPreferences.getInstance();

    String storedId = prefs.getString('my_id') ?? '';
    if (!storedId.startsWith('gm-')) {
      storedId = 'gm-${storedId.isEmpty ? const Uuid().v4() : storedId}';
      await prefs.setString('my_id', storedId);
    }
    myId = storedId;

    final savedName = prefs.getString('my_name');
    myName = (savedName != null && savedName.isNotEmpty) ? savedName : await _detectName();
    await prefs.setString('my_name', myName);
    Message.setMyId(myId);

    _bt = BluetoothMessagingService(
      onMessage:   _handleMsg, onPeerFound: _handlePeerFound, onPeerLost: _handlePeerLost);
    _bt.myId   = myId;
    _bt.myName = myName;

    _webrtc = WebRTCService(
      onMessage:   _handleMsg, onPeerFound: _handlePeerFound, onPeerLost: _handlePeerLost);

    if (!kIsWeb) await _bt.start();
    await _webrtc.start(myId, myName);
  }

  Future<String> _detectName() async {
    if (kIsWeb) return 'Ghost Web';
    try { return (await DeviceInfoPlugin().androidInfo).model; } catch (_) { return 'Ghost Device'; }
  }

  void updatePrivacy({required bool hideFromRadar}) {
    _bt.updatePrivacy(hideFromRadar: hideFromRadar);
    _webrtc.updatePrivacy(hideFromRadar: hideFromRadar);
  }

  void updateScanInterval(int secs) {
    // Restart scanning with new interval
    if (!kIsWeb) {
      _bt.setScanInterval(secs);
    }
  }

  void _handlePeerFound(Peer peer) => onPeerFound(peer);

  void _handlePeerLost(String peerId) {
    if (autoDeleteOnDisconnect) _deleteGhostMessages(peerId);
    onPeerLost(peerId);
  }

  void _handleMsg(String peerId, Map<String, dynamic> data) {
    final type = data['type'];
    if (type is! String) return;
    switch (type) {
      case 'message':    _handleChatMsg(peerId, data); break;
      case 'ack':
        final id = data['id'];
        if (id is String) _storage.updateMessageStatus(id, MessageStatus.delivered);
        break;
      case 'ghost_delete':
        final id = data['id'];
        if (id is String) _storage.deleteMessageById(id);
        break;
    }
  }

  void _handleChatMsg(String peerId, Map<String, dynamic> data) {
    final id        = data['id'];
    // Security: sender_id is ALWAYS overridden by the actual peer connection ID
    // This prevents impersonation attacks
    final senderId  = peerId; // enforced — ignore data['sender_id']
    final text      = data['text'];
    final timestamp = data['timestamp'];
    if (id is! String || text is! String || timestamp is! int) return;
    if (id.length > 64 || text.length > 4096) return;

    final isGhost = data['is_ghost'] == true;
    final msg = Message(
      id: id, chatId: peerId, senderId: senderId, text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      status: MessageStatus.delivered, isGhost: isGhost,
    );
    _storage.insertMessage(msg);
    if (isGhost) _ghostMessages.putIfAbsent(peerId, () => []).add(id);
    _webrtc.sendMessage(peerId, {'type': 'ack', 'id': id});
    onMessageReceived(peerId, msg);

    final senderName = data['sender_name'];
    _notifications.showMessageNotification(
      senderName: senderName is String ? senderName : peerId,
      message:    text.length > 80 ? '${text.substring(0, 80)}…' : text,
      chatId:     peerId,
    );
  }

  Future<Message?> sendMessage({
    required String peerId, required String text, bool isGhost = false,
  }) async {
    final safeText = text.length > 4096 ? text.substring(0, 4096) : text;
    final msg = Message(
      id: const Uuid().v4(), chatId: peerId, senderId: myId,
      text: safeText, timestamp: DateTime.now(),
      status: MessageStatus.sending, isGhost: isGhost,
    );
    await _storage.insertMessage(msg);
    if (isGhost) _ghostMessages.putIfAbsent(peerId, () => []).add(msg.id);

    final wire = msg.toWire()..['sender_name'] = myName;
    final sent = await _webrtc.sendMessage(peerId, wire);
    if (sent) {
      await _storage.updateMessageStatus(msg.id, MessageStatus.sent);
      return msg.copyWith(status: MessageStatus.sent);
    }
    return msg;
  }

  Future<void> _deleteGhostMessages(String peerId) async {
    final ids = _ghostMessages.remove(peerId);
    if (ids == null || ids.isEmpty) return;
    for (final id in ids) {
      await _storage.deleteMessageById(id);
      _webrtc.sendMessage(peerId, {'type': 'ghost_delete', 'id': id});
    }
  }

  Future<void> clearAllHistory()             => _storage.clearAll();
  Future<List<Message>> getMessages(String c) => _storage.getMessages(c);
  int?  getBluetoothRssi(String peerId)       => _bt.getRssi(peerId);
  bool  isWebRTCConnected(String peerId)       => _webrtc.isConnected(peerId);

  Future<void> setMyName(String name) async {
    myName = name; _bt.myName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_name', name);
  }

  void dispose() { _bt.dispose(); _webrtc.dispose(); }
}

extension MessageCopyWith on Message {
  Message copyWith({String? id,String? chatId,String? senderId,String? text,DateTime? timestamp,MessageStatus? status,bool? isGhost,bool? isDeleted}) => Message(id:id??this.id,chatId:chatId??this.chatId,senderId:senderId??this.senderId,text:text??this.text,timestamp:timestamp??this.timestamp,status:status??this.status,isGhost:isGhost??this.isGhost,isDeleted:isDeleted??this.isDeleted);
}
