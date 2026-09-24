import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/peer.dart';
import '../models/message.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Peer peer;
  const ChatScreen({super.key, required this.peer});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller      = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode       = FocusNode();
  bool _ghostMode = false;
  int  _charCount = 0;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _ghostMode = p.ghostDefault;
    p.loadMessages(widget.peer.id);
    _controller.addListener(() => setState(() => _charCount = _controller.text.length));
  }

  @override
  void dispose() {
    _controller.dispose(); _scrollController.dispose(); _focusNode.dispose(); super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 4096) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Message too long (max 4096 chars)',
          style: TextStyle(fontFamily: 'monospace', color: context.ac.textPrimary)),
        backgroundColor: context.ac.surface,
      ));
      return;
    }
    context.read<AppProvider>().sendMessage(
      peerId: widget.peer.id, text: text, isGhost: _ghostMode);
    _controller.clear();
    if (context.read<AppProvider>().autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final messages  = provider.getMessages(widget.peer.id);
    final myId      = provider.myId;
    final peer      = provider.peers[widget.peer.id] ?? widget.peer;
    final c         = context.ac;
    final fontSize  = provider.fontScale.size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          if (provider.showAvatarInChat) ...[
            CircleAvatar(radius: 16, backgroundColor: c.accentFaint,
              child: Text(peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
                style: TextStyle(color: c.accent, fontSize: 13, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
          ],
          Text(peer.sourceEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(peer.name, style: TextStyle(color: c.accent, fontFamily: 'monospace', fontSize: 14)),
            Text(peer.isOnline ? '● ONLINE' : '○ OFFLINE',
              style: TextStyle(color: peer.isOnline ? c.online : c.offline,
                fontFamily: 'monospace', fontSize: 9)),
          ])),
        ]),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _ghostMode = !_ghostMode),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _ghostMode ? c.ghostAccent : c.border),
                borderRadius: BorderRadius.circular(4),
                color: _ghostMode ? c.ghostAccent.withOpacity(0.15) : Colors.transparent,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('👻', style: TextStyle(fontSize: 12, color: _ghostMode ? c.ghostAccent : c.textMuted)),
                const SizedBox(width: 4),
                Text('GHOST', style: TextStyle(color: _ghostMode ? c.ghostAccent : c.textMuted,
                  fontFamily: 'monospace', fontSize: 9)),
              ]),
            ),
          ),
        ],
      ),
      body: Column(children: [
        if (_ghostMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            color: c.ghostAccent.withOpacity(0.12),
            child: Text('👻 Ghost — messages vanish on disconnect',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.ghostAccent, fontFamily: 'monospace', fontSize: 10)),
          ),
        Expanded(child: _buildMessageList(messages, myId, c, fontSize, provider)),
        _buildInputBar(c, fontSize),
      ]),
    );
  }

  Widget _buildMessageList(List<Message> messages, String myId,
      AppColors c, double fontSize, AppProvider p) {
    return Stack(children: [
      // Chat background
      Positioned.fill(child: _buildBackground(c, p.chatBg)),
      if (messages.isEmpty)
        Center(child: Text('No messages yet.\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 13)))
      else
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isMe = msg.senderId == myId;
            // Group: show time header if >10min gap
            final showHeader = i == 0 ||
                messages[i].timestamp.difference(messages[i-1].timestamp).inMinutes > 10;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (showHeader)
                Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.read<AppProvider>().timeFormat.format(msg.timestamp),
                    style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 10)),
                )),
              _buildBubble(msg, isMe, c, fontSize, context.read<AppProvider>()),
            ]);
          },
        ),
    ]);
  }

  Widget _buildBackground(AppColors c, ChatBg bg) {
    switch (bg) {
      case ChatBg.defaultBg: return Container(color: c.bg);
      case ChatBg.grid:
        return Container(color: c.bg,
          child: CustomPaint(painter: _GridPainter(c.radarGrid)));
      case ChatBg.dots:
        return Container(color: c.bg,
          child: CustomPaint(painter: _DotsPainter(c.radarGrid)));
      case ChatBg.scanlines:
        return Container(color: c.bg,
          child: CustomPaint(painter: _ScanlinesPainter(c.radarGrid)));
    }
  }

  Widget _buildBubble(Message msg, bool isMe, AppColors c, double fontSize, AppProvider p) {
    final bs = p.bubbleStyle;

    Color bubbleColor;
    BorderRadius? radius;
    Border? border;
    BoxShadow? shadow;

    if (msg.isGhost) {
      bubbleColor = isMe ? c.ghostAccent.withOpacity(0.25) : c.ghostAccent.withOpacity(0.15);
    } else {
      bubbleColor = isMe ? c.bubbleMine : c.bubbleTheirs;
    }

    switch (bs) {
      case BubbleStyle.modern:
        radius = BorderRadius.only(
          topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18));
        shadow = BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2));
        break;
      case BubbleStyle.classic:
        radius = BorderRadius.only(
          topLeft: const Radius.circular(8), topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(isMe ? 8 : 2), bottomRight: Radius.circular(isMe ? 2 : 8));
        border = Border.all(color: msg.isGhost ? c.ghostAccent.withOpacity(0.5) : c.border);
        break;
      case BubbleStyle.minimal:
        bubbleColor = Colors.transparent;
        radius = BorderRadius.zero;
        border = Border(bottom: BorderSide(color: c.border, width: 0.5));
        break;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(bottom: p.compactMode ? 4 : 8),
        padding: bs == BubbleStyle.minimal
            ? const EdgeInsets.symmetric(vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor, borderRadius: radius, border: border,
          boxShadow: shadow != null ? [shadow] : null,
        ),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.isGhost && !p.compactMode)
              Text('👻 ghost', style: TextStyle(color: c.ghostAccent.withOpacity(0.7),
                fontSize: 9, fontFamily: 'monospace')),
            Text(msg.text, style: TextStyle(color: c.textPrimary, fontSize: fontSize)),
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(p.timeFormat.format(msg.timestamp),
                style: TextStyle(color: c.textMuted, fontFamily: 'monospace', fontSize: 9)),
              if (isMe) ...[
                const SizedBox(width: 4),
                _statusIcon(msg.status, c),
              ],
            ]),
          ]),
      ),
    );
  }

  Widget _statusIcon(MessageStatus s, AppColors c) {
    switch (s) {
      case MessageStatus.sending:   return Icon(Icons.access_time,  size: 10, color: c.textMuted);
      case MessageStatus.sent:      return Icon(Icons.check,        size: 10, color: c.accent);
      case MessageStatus.delivered: return Icon(Icons.done_all,     size: 10, color: c.accent);
    }
  }

  Widget _buildInputBar(AppColors c, double fontSize) {
    final charNearLimit = _charCount > 3500;
    // ✅ GBoard fix: SafeArea handles bottom inset, no manual viewInsets
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: c.surface, border: Border(top: BorderSide(color: c.border))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (charNearLimit)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$_charCount / 4096',
                  style: TextStyle(color: _charCount > 4000 ? Colors.red : c.textMuted,
                    fontFamily: 'monospace', fontSize: 9)),
              ]),
            ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _controller, focusNode: _focusNode,
                style: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: fontSize),
                maxLength: 4096, maxLines: 5, minLines: 1,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: _ghostMode ? '👻 Ghost message…' : 'Message…',
                  hintStyle: TextStyle(color: _ghostMode ? c.ghostAccent.withOpacity(0.5) : c.textMuted,
                    fontFamily: 'monospace', fontSize: fontSize - 1),
                  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _ghostMode ? c.ghostAccent : c.borderStrong, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _ghostMode ? c.ghostAccent.withOpacity(0.2) : c.accentFaint,
                  border: Border.all(color: _ghostMode ? c.ghostAccent : c.accent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.send, color: _ghostMode ? c.ghostAccent : c.accent, size: 20),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Background painters ────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = 0.5;
    for (double x = 0; x < s.width; x += 24) c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    for (double y = 0; y < s.height; y += 24) c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }
  @override bool shouldRepaint(_GridPainter o) => false;
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color;
    for (double x = 0; x < s.width; x += 20)
      for (double y = 0; y < s.height; y += 20)
        c.drawCircle(Offset(x, y), 1, p);
  }
  @override bool shouldRepaint(_DotsPainter o) => false;
}

class _ScanlinesPainter extends CustomPainter {
  final Color color;
  _ScanlinesPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (double y = 0; y < s.height; y += 8)
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }
  @override bool shouldRepaint(_ScanlinesPainter o) => false;
}
