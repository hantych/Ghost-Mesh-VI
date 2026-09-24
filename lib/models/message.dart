enum MessageStatus { sending, sent, delivered }

class Message {
  final String id;
  final String chatId;     // peerId of the other party
  final String senderId;   // our ID or peer ID
  final String text;
  final DateTime timestamp;
  MessageStatus status;
  final bool isGhost;      // ghost message - deleted when out of range
  bool isDeleted;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.isGhost = false,
    this.isDeleted = false,
  });

  bool get isMine => senderId == _myId;
  static String _myId = '';
  static void setMyId(String id) => _myId = id;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.index,
      'is_ghost': isGhost ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.values[map['status'] as int],
      isGhost: (map['is_ghost'] as int) == 1,
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }

  /// Wire format for sending over BT / WebRTC
  Map<String, dynamic> toWire() {
    return {
      'type': 'message',
      'id': id,
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_ghost': isGhost,
    };
  }
}
