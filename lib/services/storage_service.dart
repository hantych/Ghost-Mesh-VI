import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';

class StorageService {
  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'ghost_mesh.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE messages (
            id          TEXT PRIMARY KEY,
            chat_id     TEXT NOT NULL,
            sender_id   TEXT NOT NULL,
            text        TEXT NOT NULL,
            timestamp   INTEGER NOT NULL,
            status      INTEGER NOT NULL DEFAULT 0,
            is_ghost    INTEGER NOT NULL DEFAULT 0,
            is_deleted  INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_chat ON messages(chat_id, timestamp)');
      },
      onUpgrade: (db, oldV, newV) async {
        // v1 → v2: no schema change, just reserved for future use
      },
    );
  }

  Future<void> insertMessage(Message msg) async {
    final db = await _database;
    await db.insert(
      'messages',
      {
        'id':         msg.id,
        'chat_id':    msg.chatId,
        'sender_id':  msg.senderId,
        'text':       msg.text,
        'timestamp':  msg.timestamp.millisecondsSinceEpoch,
        'status':     msg.status.index,
        'is_ghost':   msg.isGhost  ? 1 : 0,
        'is_deleted': msg.isDeleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Message>> getMessages(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'messages',
      where: 'chat_id = ? AND is_deleted = 0',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final db = await _database;
    await db.update('messages', {'status': status.index},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMessageById(String id) async {
    final db = await _database;
    await db.update('messages', {'is_deleted': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-delete all messages (clear history).
  Future<void> clearAll() async {
    final db = await _database;
    await db.update('messages', {'is_deleted': 1});
  }

  Message _rowToMessage(Map<String, dynamic> row) => Message(
    id:        row['id'] as String,
    chatId:    row['chat_id'] as String,
    senderId:  row['sender_id'] as String,
    text:      row['text'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    status:    MessageStatus.values[(row['status'] as int)
        .clamp(0, MessageStatus.values.length - 1)],
    isGhost:   (row['is_ghost']   as int) == 1,
    isDeleted: (row['is_deleted'] as int) == 1,
  );
}

  /// Soft-delete all messages in a specific chat.
  Future<void> clearChatMessages(String chatId) async {
    final db = await _database;
    await db.update('messages', {'is_deleted': 1},
        where: 'chat_id = ?', whereArgs: [chatId]);
  }
