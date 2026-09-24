// Web stub — Bluetooth is not available in browsers.
import '../models/peer.dart';

typedef MessageCallback   = void Function(String peerId, Map<String, dynamic> data);
typedef PeerCallback      = void Function(Peer peer);
typedef PeerLostCallback  = void Function(String peerId);

class BluetoothMessagingService {
  final MessageCallback  onMessage;
  final PeerCallback     onPeerFound;
  final PeerLostCallback onPeerLost;

  String myId   = '';
  String myName = '';

  BluetoothMessagingService({
    required this.onMessage,
    required this.onPeerFound,
    required this.onPeerLost,
  });

  Future<void> start() async {}
  void updatePrivacy({required bool hideFromRadar}) {}
  Future<bool> sendMessage(String peerId, Map<String, dynamic> data) async => false;
  int?  getRssi(String peerId) => null;
  bool  isConnected(String peerId) => false;
  void  dispose() {}
}
