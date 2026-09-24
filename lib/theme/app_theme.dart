import 'package:flutter/material.dart';

enum AccentPreset { green, cyan, purple, red, orange, blue }
enum FontScale    { small, medium, large, xlarge }
enum BubbleStyle  { modern, classic, minimal }
enum ChatBg       { defaultBg, grid, dots, scanlines }
enum TimeFormat   { h24, h12 }
enum AutoDeleteTimer { never, hour1, hour24, day7 }
enum RadarSpeed   { slow, medium, fast }
enum PeerSort     { name, signal, lastSeen }

extension AccentLabel on AccentPreset {
  String get label => const {
    AccentPreset.green:  '🟢  Matrix Green',
    AccentPreset.cyan:   '🔵  Cyber Cyan',
    AccentPreset.purple: '🟣  Cosmos Purple',
    AccentPreset.red:    '🔴  Crimson Red',
    AccentPreset.orange: '🟠  Ember Orange',
    AccentPreset.blue:   '💙  Arctic Blue',
  }[this]!;
}

extension FontScaleExt on FontScale {
  String get label => const {FontScale.small: 'Small',FontScale.medium: 'Medium',
    FontScale.large: 'Large',FontScale.xlarge: 'XLarge'}[this]!;
  double get size  => const {FontScale.small:12.0,FontScale.medium:14.0,FontScale.large:16.0,FontScale.xlarge:18.0}[this]!;
}
extension BubbleExt on BubbleStyle {
  String get label => const {BubbleStyle.modern:'Modern (rounded)',BubbleStyle.classic:'Classic (sharp)',BubbleStyle.minimal:'Minimal (flat)'}[this]!;
}
extension ChatBgExt on ChatBg {
  String get label => const {ChatBg.defaultBg:'Default',ChatBg.grid:'Grid',ChatBg.dots:'Dots',ChatBg.scanlines:'Scanlines'}[this]!;
}
extension TimeFormatExt on TimeFormat {
  String get label => this == TimeFormat.h24 ? '24-hour' : '12-hour';
  String format(DateTime dt) {
    if (this == TimeFormat.h12) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      return '${h.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
extension AutoDeleteExt on AutoDeleteTimer {
  String get label => const {AutoDeleteTimer.never:'Never',AutoDeleteTimer.hour1:'1 hour',AutoDeleteTimer.hour24:'24 hours',AutoDeleteTimer.day7:'7 days'}[this]!;
}
extension RadarSpeedExt on RadarSpeed {
  String get label => const {RadarSpeed.slow:'Slow',RadarSpeed.medium:'Medium',RadarSpeed.fast:'Fast'}[this]!;
  Duration get dur  => const {RadarSpeed.slow:Duration(seconds:5),RadarSpeed.medium:Duration(seconds:3),RadarSpeed.fast:Duration(milliseconds:1500)}[this]!;
}
extension PeerSortExt on PeerSort {
  String get label => const {PeerSort.name:'By name',PeerSort.signal:'By signal',PeerSort.lastSeen:'By last seen'}[this]!;
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,required this.accentDim,required this.accentFaint,
    required this.bg,required this.surface,required this.surfaceAlt,
    required this.border,required this.borderStrong,
    required this.textPrimary,required this.textSecondary,required this.textMuted,
    required this.bubbleMine,required this.bubbleTheirs,
    required this.ghostAccent,required this.online,required this.offline,
    required this.radarGrid,
  });
  final Color accent,accentDim,accentFaint;
  final Color bg,surface,surfaceAlt;
  final Color border,borderStrong;
  final Color textPrimary,textSecondary,textMuted;
  final Color bubbleMine,bubbleTheirs;
  final Color ghostAccent,online,offline;
  final Color radarGrid;

  @override AppColors copyWith({Color? accent,Color? accentDim,Color? accentFaint,Color? bg,Color? surface,Color? surfaceAlt,Color? border,Color? borderStrong,Color? textPrimary,Color? textSecondary,Color? textMuted,Color? bubbleMine,Color? bubbleTheirs,Color? ghostAccent,Color? online,Color? offline,Color? radarGrid}) => AppColors(accent:accent??this.accent,accentDim:accentDim??this.accentDim,accentFaint:accentFaint??this.accentFaint,bg:bg??this.bg,surface:surface??this.surface,surfaceAlt:surfaceAlt??this.surfaceAlt,border:border??this.border,borderStrong:borderStrong??this.borderStrong,textPrimary:textPrimary??this.textPrimary,textSecondary:textSecondary??this.textSecondary,textMuted:textMuted??this.textMuted,bubbleMine:bubbleMine??this.bubbleMine,bubbleTheirs:bubbleTheirs??this.bubbleTheirs,ghostAccent:ghostAccent??this.ghostAccent,online:online??this.online,offline:offline??this.offline,radarGrid:radarGrid??this.radarGrid);
  @override AppColors lerp(AppColors? o,double t) { if(o==null)return this; Color l(Color a,Color b)=>Color.lerp(a,b,t)!; return AppColors(accent:l(accent,o.accent),accentDim:l(accentDim,o.accentDim),accentFaint:l(accentFaint,o.accentFaint),bg:l(bg,o.bg),surface:l(surface,o.surface),surfaceAlt:l(surfaceAlt,o.surfaceAlt),border:l(border,o.border),borderStrong:l(borderStrong,o.borderStrong),textPrimary:l(textPrimary,o.textPrimary),textSecondary:l(textSecondary,o.textSecondary),textMuted:l(textMuted,o.textMuted),bubbleMine:l(bubbleMine,o.bubbleMine),bubbleTheirs:l(bubbleTheirs,o.bubbleTheirs),ghostAccent:l(ghostAccent,o.ghostAccent),online:l(online,o.online),offline:l(offline,o.offline),radarGrid:l(radarGrid,o.radarGrid)); }
}

// Palettes
const _dGreen = AppColors(accent:Color(0xFF00FF41),accentDim:Color(0xFF00A828),accentFaint:Color(0xFF1A4A1A),bg:Color(0xFF080F08),surface:Color(0xFF0A1A0A),surfaceAlt:Color(0xFF0D220D),border:Color(0x3300FF41),borderStrong:Color(0xFF00FF41),textPrimary:Color(0xFFCCFFCC),textSecondary:Color(0xFF88CC88),textMuted:Color(0xFF336633),bubbleMine:Color(0xFF1A4A1A),bubbleTheirs:Color(0xFF0D1F0D),ghostAccent:Color(0xFFCE93D8),online:Color(0xFF00FF41),offline:Color(0xFF556655),radarGrid:Color(0x2200FF41));
const _lGreen = AppColors(accent:Color(0xFF1B7A30),accentDim:Color(0xFF2E9E48),accentFaint:Color(0xFFD4F5D4),bg:Color(0xFFF0FAF0),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFE8F5E8),border:Color(0x441B7A30),borderStrong:Color(0xFF1B7A30),textPrimary:Color(0xFF0D3D1A),textSecondary:Color(0xFF336633),textMuted:Color(0xFF7BAF7B),bubbleMine:Color(0xFFD4F5D4),bubbleTheirs:Color(0xFFEEFAEE),ghostAccent:Color(0xFF9C27B0),online:Color(0xFF1B7A30),offline:Color(0xFF9E9E9E),radarGrid:Color(0x221B7A30));
const _dCyan  = AppColors(accent:Color(0xFF00E5FF),accentDim:Color(0xFF0097A7),accentFaint:Color(0xFF00253A),bg:Color(0xFF040D14),surface:Color(0xFF071525),surfaceAlt:Color(0xFF0A1E30),border:Color(0x3300E5FF),borderStrong:Color(0xFF00E5FF),textPrimary:Color(0xFFB0F0FF),textSecondary:Color(0xFF64B5C4),textMuted:Color(0xFF1A4A5A),bubbleMine:Color(0xFF003344),bubbleTheirs:Color(0xFF001F2E),ghostAccent:Color(0xFFFF8A80),online:Color(0xFF00E5FF),offline:Color(0xFF4A6670),radarGrid:Color(0x2200E5FF));
const _lCyan  = AppColors(accent:Color(0xFF0076A8),accentDim:Color(0xFF0097CC),accentFaint:Color(0xFFD0EEFF),bg:Color(0xFFF0F9FF),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFE0F4FF),border:Color(0x440076A8),borderStrong:Color(0xFF0076A8),textPrimary:Color(0xFF003755),textSecondary:Color(0xFF005580),textMuted:Color(0xFF6699AA),bubbleMine:Color(0xFFD0EEFF),bubbleTheirs:Color(0xFFEAF6FF),ghostAccent:Color(0xFFD32F2F),online:Color(0xFF0076A8),offline:Color(0xFF9E9E9E),radarGrid:Color(0x220076A8));
const _dPurp  = AppColors(accent:Color(0xFFBB86FC),accentDim:Color(0xFF7C4DFF),accentFaint:Color(0xFF2A1550),bg:Color(0xFF0C0814),surface:Color(0xFF140E24),surfaceAlt:Color(0xFF1C1430),border:Color(0x44BB86FC),borderStrong:Color(0xFFBB86FC),textPrimary:Color(0xFFEADDFF),textSecondary:Color(0xFFAA88DD),textMuted:Color(0xFF5A3A8A),bubbleMine:Color(0xFF2A1550),bubbleTheirs:Color(0xFF1A0D38),ghostAccent:Color(0xFF80DEEA),online:Color(0xFFBB86FC),offline:Color(0xFF6A5A7A),radarGrid:Color(0x22BB86FC));
const _lPurp  = AppColors(accent:Color(0xFF6200EA),accentDim:Color(0xFF9C27B0),accentFaint:Color(0xFFEDE7F6),bg:Color(0xFFF8F4FF),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFF0E8FF),border:Color(0x446200EA),borderStrong:Color(0xFF6200EA),textPrimary:Color(0xFF1A0050),textSecondary:Color(0xFF5500AA),textMuted:Color(0xFFAA88CC),bubbleMine:Color(0xFFEDE7F6),bubbleTheirs:Color(0xFFF8F4FF),ghostAccent:Color(0xFF00838F),online:Color(0xFF6200EA),offline:Color(0xFF9E9E9E),radarGrid:Color(0x226200EA));
const _dRed   = AppColors(accent:Color(0xFFFF5252),accentDim:Color(0xFFD32F2F),accentFaint:Color(0xFF3A0A0A),bg:Color(0xFF120606),surface:Color(0xFF1E0A0A),surfaceAlt:Color(0xFF2A0F0F),border:Color(0x44FF5252),borderStrong:Color(0xFFFF5252),textPrimary:Color(0xFFFFCDD2),textSecondary:Color(0xFFEF9A9A),textMuted:Color(0xFF8A3A3A),bubbleMine:Color(0xFF3A0A0A),bubbleTheirs:Color(0xFF220606),ghostAccent:Color(0xFF80CBC4),online:Color(0xFFFF5252),offline:Color(0xFF7A4A4A),radarGrid:Color(0x22FF5252));
const _lRed   = AppColors(accent:Color(0xFFC62828),accentDim:Color(0xFFE53935),accentFaint:Color(0xFFFFEBEE),bg:Color(0xFFFFF5F5),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFFFE8E8),border:Color(0x44C62828),borderStrong:Color(0xFFC62828),textPrimary:Color(0xFF4A0000),textSecondary:Color(0xFF8A2020),textMuted:Color(0xFFCC7777),bubbleMine:Color(0xFFFFEBEE),bubbleTheirs:Color(0xFFFFF5F5),ghostAccent:Color(0xFF00796B),online:Color(0xFFC62828),offline:Color(0xFF9E9E9E),radarGrid:Color(0x22C62828));
const _dOran  = AppColors(accent:Color(0xFFFF9100),accentDim:Color(0xFFE65100),accentFaint:Color(0xFF3A1A00),bg:Color(0xFF120A00),surface:Color(0xFF1E1200),surfaceAlt:Color(0xFF2A1A00),border:Color(0x44FF9100),borderStrong:Color(0xFFFF9100),textPrimary:Color(0xFFFFE0B2),textSecondary:Color(0xFFFFCC80),textMuted:Color(0xFF8A5500),bubbleMine:Color(0xFF3A1A00),bubbleTheirs:Color(0xFF220E00),ghostAccent:Color(0xFF80D8FF),online:Color(0xFFFF9100),offline:Color(0xFF7A5500),radarGrid:Color(0x22FF9100));
const _lOran  = AppColors(accent:Color(0xFFE65100),accentDim:Color(0xFFF57C00),accentFaint:Color(0xFFFFF3E0),bg:Color(0xFFFFFBF5),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFFFF0D4),border:Color(0x44E65100),borderStrong:Color(0xFFE65100),textPrimary:Color(0xFF3E1200),textSecondary:Color(0xFF8A3500),textMuted:Color(0xFFCC8844),bubbleMine:Color(0xFFFFF3E0),bubbleTheirs:Color(0xFFFFFBF5),ghostAccent:Color(0xFF0277BD),online:Color(0xFFE65100),offline:Color(0xFF9E9E9E),radarGrid:Color(0x22E65100));
const _dBlue  = AppColors(accent:Color(0xFF448AFF),accentDim:Color(0xFF1565C0),accentFaint:Color(0xFF0A1A3A),bg:Color(0xFF060D1A),surface:Color(0xFF0A1528),surfaceAlt:Color(0xFF0F1E38),border:Color(0x44448AFF),borderStrong:Color(0xFF448AFF),textPrimary:Color(0xFFBBDEFB),textSecondary:Color(0xFF82B1FF),textMuted:Color(0xFF1A3A6A),bubbleMine:Color(0xFF0A1A3A),bubbleTheirs:Color(0xFF060D1A),ghostAccent:Color(0xFFFFAB40),online:Color(0xFF448AFF),offline:Color(0xFF3A4A7A),radarGrid:Color(0x22448AFF));
const _lBlue  = AppColors(accent:Color(0xFF1565C0),accentDim:Color(0xFF1976D2),accentFaint:Color(0xFFE3F2FD),bg:Color(0xFFF5F9FF),surface:Color(0xFFFFFFFF),surfaceAlt:Color(0xFFE8F4FD),border:Color(0x441565C0),borderStrong:Color(0xFF1565C0),textPrimary:Color(0xFF0A2540),textSecondary:Color(0xFF1A4A8A),textMuted:Color(0xFF5599CC),bubbleMine:Color(0xFFE3F2FD),bubbleTheirs:Color(0xFFF5F9FF),ghostAccent:Color(0xFFFF6D00),online:Color(0xFF1565C0),offline:Color(0xFF9E9E9E),radarGrid:Color(0x221565C0));

class AppTheme {
  static AppColors colorsFor(AccentPreset p, bool isDark) {
    switch (p) {
      case AccentPreset.green:  return isDark ? _dGreen : _lGreen;
      case AccentPreset.cyan:   return isDark ? _dCyan  : _lCyan;
      case AccentPreset.purple: return isDark ? _dPurp  : _lPurp;
      case AccentPreset.red:    return isDark ? _dRed   : _lRed;
      case AccentPreset.orange: return isDark ? _dOran  : _lOran;
      case AccentPreset.blue:   return isDark ? _dBlue  : _lBlue;
    }
  }

  static ThemeData dark(AppColors c)  => _build(c, Brightness.dark);
  static ThemeData light(AppColors c) => _build(c, Brightness.light);

  static ThemeData _build(AppColors c, Brightness b) => ThemeData(
    brightness: b, scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(brightness: b, primary: c.accent, secondary: c.accentDim,
      surface: c.surface, error: const Color(0xFFCF6679),
      onPrimary: c.bg, onSecondary: c.bg, onSurface: c.textPrimary, onError: Colors.white),
    fontFamily: 'monospace', extensions: [c],
    appBarTheme: AppBarTheme(backgroundColor: c.surface, elevation: 0, foregroundColor: c.textPrimary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accentFaint : c.surfaceAlt),
    ),
    dividerColor: c.border,
    snackBarTheme: SnackBarThemeData(backgroundColor: c.surface,
        contentTextStyle: TextStyle(color: c.textPrimary, fontFamily: 'monospace')),
    dialogTheme: DialogTheme(backgroundColor: c.surface,
        titleTextStyle: TextStyle(color: c.textPrimary, fontFamily: 'monospace', fontSize: 16),
        contentTextStyle: TextStyle(color: c.textSecondary, fontFamily: 'monospace', fontSize: 13)),
  );
}

extension AppColorsX on BuildContext {
  AppColors get ac => Theme.of(this).extension<AppColors>()!;
}
