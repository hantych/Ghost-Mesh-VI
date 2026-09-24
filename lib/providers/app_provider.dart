import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/peer.dart';
import '../models/message.dart';
import '../services/discovery_service.dart';
import '../theme/app_theme.dart';

class AppProvider extends ChangeNotifier {
  late DiscoveryService _discovery;

  // ── Identity ───────────────────────────────────────────────────────────────
  String get myId   => _initialized ? _discovery.myId   : '';
  String get myName => _initialized ? _discovery.myName : '';

  // ── Peers + messages ───────────────────────────────────────────────────────
  final Map<String, Peer>          _peers    = {};
  final Map<String, List<Message>> _messages = {};
  Map<String, Peer> get peers   => Map.unmodifiable(_peers);
  List<Peer>        get peerList => _peers.values.toList();

  bool _initialized = false;
  bool get initialized => _initialized;

  // ── Theme ──────────────────────────────────────────────────────────────────
  ThemeMode    _themeMode = ThemeMode.dark;
  AccentPreset _accent    = AccentPreset.green;
  ThemeMode    get themeMode => _themeMode;
  AccentPreset get accent    => _accent;
  ThemeData darkTheme(BuildContext ctx)  => AppTheme.dark(AppTheme.colorsFor(_accent, true));
  ThemeData lightTheme(BuildContext ctx) => AppTheme.light(AppTheme.colorsFor(_accent, false));

  // ── Appearance ─────────────────────────────────────────────────────────────
  FontScale    _fontScale       = FontScale.medium;
  BubbleStyle  _bubbleStyle     = BubbleStyle.classic;
  ChatBg       _chatBg          = ChatBg.defaultBg;
  TimeFormat   _timeFormat      = TimeFormat.h24;
  bool         _showAvatarInChat = true;
  bool         _compactMode     = false;

  FontScale   get fontScale       => _fontScale;
  BubbleStyle get bubbleStyle     => _bubbleStyle;
  ChatBg      get chatBg          => _chatBg;
  TimeFormat  get timeFormat      => _timeFormat;
  bool        get showAvatarInChat => _showAvatarInChat;
  bool        get compactMode     => _compactMode;

  // ── Radar settings ─────────────────────────────────────────────────────────
  bool       _showRssiOnRadar   = true;
  bool       _showNamesOnRadar  = true;
  bool       _showOfflinePeers  = true;
  RadarSpeed _radarSpeed        = RadarSpeed.medium;
  PeerSort   _peerSort          = PeerSort.signal;
  int        _scanIntervalSecs  = 15;

  bool       get showRssiOnRadar  => _showRssiOnRadar;
  bool       get showNamesOnRadar => _showNamesOnRadar;
  bool       get showOfflinePeers => _showOfflinePeers;
  RadarSpeed get radarSpeed       => _radarSpeed;
  PeerSort   get peerSort         => _peerSort;
  int        get scanIntervalSecs => _scanIntervalSecs;

  List<Peer> get sortedPeerList {
    final list = _showOfflinePeers
        ? _peers.values.toList()
        : _peers.values.where((p) => p.isOnline).toList();
    switch (_peerSort) {
      case PeerSort.name:     list.sort((a, b) => a.name.compareTo(b.name)); break;
      case PeerSort.signal:   list.sort((a, b) => (b.rssi).compareTo(a.rssi)); break;
      case PeerSort.lastSeen: list.sort((a, b) => b.lastSeen.compareTo(a.lastSeen)); break;
    }
    return list;
  }

  // ── Privacy ────────────────────────────────────────────────────────────────
  bool             _ghostDefault           = false;
  bool             _hideFromRadar          = false;
  bool             _autoDeleteOnDisconnect = true;
  AutoDeleteTimer  _autoDeleteTimer        = AutoDeleteTimer.never;

  bool            get ghostDefault           => _ghostDefault;
  bool            get hideFromRadar          => _hideFromRadar;
  bool            get autoDeleteOnDisconnect => _autoDeleteOnDisconnect;
  AutoDeleteTimer get autoDeleteTimer        => _autoDeleteTimer;

  // ── Chat ───────────────────────────────────────────────────────────────────
  bool _soundOnMessage    = false; // can't easily play sound in Flutter without package
  bool _autoScroll        = true;
  bool _notificationsEnabled = true;

  bool get soundOnMessage       => _soundOnMessage;
  bool get autoScroll           => _autoScroll;
  bool get notificationsEnabled => _notificationsEnabled;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadPrefs();
    _discovery = DiscoveryService(
      onPeerFound:       _onPeerFound,
      onPeerLost:        _onPeerLost,
      onMessageReceived: _onMessageReceived,
      autoDeleteOnDisconnect: _autoDeleteOnDisconnect,
    );
    await _discovery.init();
    _discovery.updatePrivacy(hideFromRadar: _hideFromRadar);
    _discovery.updateScanInterval(_scanIntervalSecs);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _themeMode       = ThemeMode.values[(p.getInt('theme_mode')    ?? 1).clamp(0, 2)];
    _accent          = AccentPreset.values[(p.getInt('accent')     ?? 0).clamp(0, 5)];
    _fontScale       = FontScale.values[(p.getInt('font_scale')    ?? 1).clamp(0, 3)];
    _bubbleStyle     = BubbleStyle.values[(p.getInt('bubble')      ?? 1).clamp(0, 2)];
    _chatBg          = ChatBg.values[(p.getInt('chat_bg')          ?? 0).clamp(0, 3)];
    _timeFormat      = TimeFormat.values[(p.getInt('time_fmt')     ?? 0).clamp(0, 1)];
    _showAvatarInChat = p.getBool('show_avatar')   ?? true;
    _compactMode      = p.getBool('compact')       ?? false;
    _showRssiOnRadar  = p.getBool('show_rssi')     ?? true;
    _showNamesOnRadar = p.getBool('show_names')    ?? true;
    _showOfflinePeers = p.getBool('show_offline')  ?? true;
    _radarSpeed       = RadarSpeed.values[(p.getInt('radar_speed') ?? 1).clamp(0, 2)];
    _peerSort         = PeerSort.values[(p.getInt('peer_sort')     ?? 1).clamp(0, 2)];
    _scanIntervalSecs = p.getInt('scan_secs')      ?? 15;
    _ghostDefault     = p.getBool('ghost_default') ?? false;
    _hideFromRadar    = p.getBool('hide_radar')    ?? false;
    _autoDeleteOnDisconnect = p.getBool('auto_del')  ?? true;
    _autoDeleteTimer  = AutoDeleteTimer.values[(p.getInt('auto_del_t') ?? 0).clamp(0, 3)];
    _notificationsEnabled = p.getBool('notifs')    ?? true;
    _autoScroll       = p.getBool('auto_scroll')   ?? true;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme_mode',   _themeMode.index);
    await p.setInt('accent',       _accent.index);
    await p.setInt('font_scale',   _fontScale.index);
    await p.setInt('bubble',       _bubbleStyle.index);
    await p.setInt('chat_bg',      _chatBg.index);
    await p.setInt('time_fmt',     _timeFormat.index);
    await p.setBool('show_avatar', _showAvatarInChat);
    await p.setBool('compact',     _compactMode);
    await p.setBool('show_rssi',   _showRssiOnRadar);
    await p.setBool('show_names',  _showNamesOnRadar);
    await p.setBool('show_offline',_showOfflinePeers);
    await p.setInt('radar_speed',  _radarSpeed.index);
    await p.setInt('peer_sort',    _peerSort.index);
    await p.setInt('scan_secs',    _scanIntervalSecs);
    await p.setBool('ghost_default', _ghostDefault);
    await p.setBool('hide_radar',  _hideFromRadar);
    await p.setBool('auto_del',    _autoDeleteOnDisconnect);
    await p.setInt('auto_del_t',   _autoDeleteTimer.index);
    await p.setBool('notifs',      _notificationsEnabled);
    await p.setBool('auto_scroll', _autoScroll);
  }

  // ── Peer callbacks ─────────────────────────────────────────────────────────
  void _onPeerFound(Peer peer)     { _peers[peer.id] = peer; notifyListeners(); }
  void _onPeerLost(String peerId)  {
    final p = _peers[peerId];
    if (p != null) _peers[peerId] = p.copyWith(isOnline: false);
    notifyListeners();
  }
  void _onMessageReceived(String peerId, Message msg) {
    if (!_notificationsEnabled) return;
    _messages.putIfAbsent(peerId, () => []);
    if (!_messages[peerId]!.any((m) => m.id == msg.id)) _messages[peerId]!.add(msg);
    notifyListeners();
  }

  Future<void> loadMessages(String peerId) async {
    _messages[peerId] = await _discovery.getMessages(peerId);
    notifyListeners();
  }

  List<Message> getMessages(String peerId) =>
      (_messages[peerId] ?? []).where((m) => !m.isDeleted).toList();

  Future<void> sendMessage({required String peerId, required String text, bool isGhost = false}) async {
    final msg = await _discovery.sendMessage(peerId: peerId, text: text, isGhost: isGhost);
    if (msg != null) {
      _messages.putIfAbsent(peerId, () => []);
      if (!_messages[peerId]!.any((m) => m.id == msg.id)) _messages[peerId]!.add(msg);
      notifyListeners();
    }
  }

  Future<void> clearAllHistory() async {
    await _discovery.clearAllHistory(); _messages.clear(); notifyListeners();
  }

  int? getBluetoothRssi(String peerId) => kIsWeb ? null : _discovery.getBluetoothRssi(peerId);

  // ── Setters ────────────────────────────────────────────────────────────────
  Future<void> setMyName(String n) async { await _discovery.setMyName(n); notifyListeners(); }

  void _set(void Function() fn) { fn(); notifyListeners(); _save(); }

  Future<void> setThemeMode(ThemeMode v)      async => _set(() => _themeMode = v);
  Future<void> setAccent(AccentPreset v)       async => _set(() => _accent = v);
  Future<void> setFontScale(FontScale v)       async => _set(() => _fontScale = v);
  Future<void> setBubbleStyle(BubbleStyle v)   async => _set(() => _bubbleStyle = v);
  Future<void> setChatBg(ChatBg v)             async => _set(() => _chatBg = v);
  Future<void> setTimeFormat(TimeFormat v)     async => _set(() => _timeFormat = v);
  Future<void> setShowAvatarInChat(bool v)     async => _set(() => _showAvatarInChat = v);
  Future<void> setCompactMode(bool v)          async => _set(() => _compactMode = v);
  Future<void> setShowRssiOnRadar(bool v)      async => _set(() => _showRssiOnRadar = v);
  Future<void> setShowNamesOnRadar(bool v)     async => _set(() => _showNamesOnRadar = v);
  Future<void> setShowOfflinePeers(bool v)     async => _set(() => _showOfflinePeers = v);
  Future<void> setRadarSpeed(RadarSpeed v)     async { _set(() => _radarSpeed = v); }
  Future<void> setPeerSort(PeerSort v)         async => _set(() => _peerSort = v);
  Future<void> setScanInterval(int v)          async {
    _set(() => _scanIntervalSecs = v);
    if (_initialized) _discovery.updateScanInterval(v);
  }
  Future<void> setGhostDefault(bool v)        async => _set(() => _ghostDefault = v);
  Future<void> setHideFromRadar(bool v)       async {
    _set(() => _hideFromRadar = v);
    if (_initialized) _discovery.updatePrivacy(hideFromRadar: v);
  }
  Future<void> setAutoDeleteOnDisconnect(bool v) async => _set(() => _autoDeleteOnDisconnect = v);
  Future<void> setAutoDeleteTimer(AutoDeleteTimer v) async => _set(() => _autoDeleteTimer = v);
  Future<void> setNotificationsEnabled(bool v) async => _set(() => _notificationsEnabled = v);
  Future<void> setAutoScroll(bool v)          async => _set(() => _autoScroll = v);

  @override
  void dispose() { _discovery.dispose(); super.dispose(); }
}
