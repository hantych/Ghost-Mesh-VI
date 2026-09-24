import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/app_provider.dart';
import 'screens/radar_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const GhostMeshApp(),
    ),
  );
}

class GhostMeshApp extends StatelessWidget {
  const GhostMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark   = provider.themeMode == ThemeMode.dark ||
        (provider.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor:                   Colors.transparent,
        statusBarIconBrightness:          isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:         isDark ? const Color(0xFF080F08) : const Color(0xFFF0FAF0),
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ));
    }

    return MaterialApp(
      title: 'Ghost Mesh',
      debugShowCheckedModeBanner: false,
      themeMode: provider.themeMode,
      theme:     provider.lightTheme(context),
      darkTheme: provider.darkTheme(context),
      home: const _PermissionsGate(),
    );
  }
}

// ─── Permission gate ──────────────────────────────────────────────────────────
enum _PermsState { checking, granted, denied, permanentlyDenied }

class _PermissionsGate extends StatefulWidget {
  const _PermissionsGate();
  @override State<_PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<_PermissionsGate> {
  _PermsState _state  = _PermsState.checking;
  String _statusMsg   = 'Requesting permissions…';
  bool   _appReady    = false;

  @override
  void initState() {
    super.initState();
    // On web, skip permissions entirely
    if (kIsWeb) {
      _launchApp();
    } else {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() { _state = _PermsState.checking; _statusMsg = 'Requesting permissions…'; });

    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.notification,
    ].request();

    final anyPermanent = statuses.values.any((s) => s == PermissionStatus.permanentlyDenied);
    final anyDenied    = statuses.values.any((s) => s == PermissionStatus.denied);

    if (anyPermanent) {
      setState(() {
        _state     = _PermsState.permanentlyDenied;
        _statusMsg = 'Permissions permanently denied.\nOpen system settings to enable them.';
      });
      return;
    }

    if (anyDenied) {
      setState(() { _state = _PermsState.denied;
        _statusMsg = 'Some permissions denied.\nBluetooth mesh may not work.'; });
      await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) _launchApp();
  }

  Future<void> _launchApp() async {
    await context.read<AppProvider>().init();
    if (mounted) setState(() => _appReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_appReady && provider.initialized) return const RadarScreen();

    final c = context.ac;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                builder: (_, s, ch) => Transform.scale(scale: s, child: ch),
                child: Text('◎',
                  style: TextStyle(color: c.accent, fontSize: 88)),
              ),
              const SizedBox(height: 20),
              Text('GHOST MESH',
                style: TextStyle(color: c.accent, fontFamily: 'monospace',
                  fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('P2P · NO ACCOUNTS · NO SERVERS',
                style: TextStyle(color: c.textMuted, fontFamily: 'monospace',
                  fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 48),

              if (_state == _PermsState.checking)
                SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),

              if (_state == _PermsState.permanentlyDenied) ...[
                Icon(Icons.lock_outline, color: c.accentDim, size: 36),
                const SizedBox(height: 12),
                Text(_statusMsg, textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary,
                    fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('OPEN SETTINGS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent, foregroundColor: c.bg,
                    textStyle: const TextStyle(fontFamily: 'monospace',
                      fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  onPressed: openAppSettings,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _launchApp,
                  child: Text('Continue without BT (WebRTC P2P)',
                    style: TextStyle(color: c.textMuted,
                      fontFamily: 'monospace', fontSize: 11)),
                ),
              ],

              if (_state == _PermsState.denied) ...[
                Icon(Icons.warning_amber_outlined, color: c.accentDim, size: 32),
                const SizedBox(height: 10),
                Text(_statusMsg, textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary,
                    fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _requestPermissions,
                  child: Text('RETRY',
                    style: TextStyle(color: c.accent, fontFamily: 'monospace',
                      fontSize: 12, letterSpacing: 2)),
                ),
              ],

              if (_state == _PermsState.checking) ...[
                const SizedBox(height: 16),
                Text(_statusMsg, textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted,
                    fontFamily: 'monospace', fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
