import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_theme.dart';

/// Colors for one reading surface. Mirrors the web reader's themes
/// (`THEMES` in worldstories_f StoryReader) so a story looks the same on
/// both.
@immutable
final class ReaderTheme {
  const ReaderTheme({
    required this.key,
    required this.label,
    required this.background,
    required this.border,
    required this.text,
    required this.heading,
    required this.link,
    required this.isDark,
    this.isCustom = false,
  });

  final String key;
  final String label;
  final Color background;
  final Color border;
  final Color text;
  final Color heading;
  final Color link;
  final bool isDark;
  final bool isCustom;

  Map<String, Object> toJson() => {
    'key': key,
    'label': label,
    'bgColor': colorToHex(background),
    'borderColor': colorToHex(border),
    'textColor': colorToHex(text),
    'linkColor': colorToHex(link),
    'isDark': isDark,
  };

  /// Custom themes use the web's storage shape. Text and link colors are
  /// re-checked on load, so a theme saved before contrast validation still
  /// reads well.
  static ReaderTheme? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final label = json['label'];
    final background = hexToColor(json['bgColor']);
    if (key is! String || label is! String || background == null) return null;
    final text = ensureAccessibleTextColor(
      hexToColor(json['textColor']) ?? _lightFallback,
      background,
    );
    return ReaderTheme(
      key: key,
      label: label,
      background: background,
      border: hexToColor(json['borderColor']) ?? background,
      text: text,
      heading: text,
      link: ensureAccessibleTextColor(
        hexToColor(json['linkColor']) ?? text,
        background,
      ),
      isDark: json['isDark'] == true,
      isCustom: true,
    );
  }
}

const readerBuiltInThemes = <ReaderTheme>[
  ReaderTheme(
    key: 'parchment',
    label: 'Parchment',
    background: Color(0xFFF4EDE0),
    border: Color(0xFFDECFB8),
    text: Color(0xFF404040),
    heading: Color(0xFF171717),
    link: Color(0xFF171717),
    isDark: false,
  ),
  ReaderTheme(
    key: 'sepia',
    label: 'Sepia',
    background: Color(0xFFEFE3CF),
    border: Color(0xFFD7C2A2),
    text: Color(0xFF404040),
    heading: Color(0xFF171717),
    link: Color(0xFF171717),
    isDark: false,
  ),
  ReaderTheme(
    key: 'mist',
    label: 'Mist',
    background: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    text: Color(0xFF334155),
    heading: Color(0xFF0F172A),
    link: Color(0xFF0F172A),
    isDark: false,
  ),
  ReaderTheme(
    key: 'night',
    label: 'Night',
    background: Color(0xFF1B2230),
    border: Color(0xFF303A4D),
    text: Color(0xFFCBD5E1),
    heading: Color(0xFFE2E8F0),
    link: Color(0xFF93C5FD),
    isDark: true,
  ),
];

/// A reading font. [googleFamily] is fetched through google_fonts; null means
/// the app's own sans-serif. Web fonts that are only system fonts on desktop
/// (Georgia, Times, Helvetica) use the metric-compatible open fonts the web
/// reader already lists as their fallbacks.
@immutable
final class ReaderFont {
  const ReaderFont(this.key, this.label, this.googleFamily);

  final String key;
  final String label;
  final String? googleFamily;

  /// Applies this font to [style], keeping Devanagari (Nepali/Hindi) text
  /// readable whichever Latin font is chosen.
  TextStyle apply(TextStyle style) {
    final base = googleFamily == null
        ? style
        : GoogleFonts.getFont(googleFamily!, textStyle: style);
    return base.copyWith(fontFamilyFallback: const ['NotoSansDevanagari']);
  }
}

const readerFonts = <ReaderFont>[
  ReaderFont('literata', 'Literata', 'Literata'),
  ReaderFont('georgia', 'Georgia', 'Gelasio'),
  ReaderFont('times', 'Times', 'Tinos'),
  ReaderFont('garamond', 'Garamond', 'EB Garamond'),
  ReaderFont('merriweather', 'Merriweather', 'Merriweather'),
  ReaderFont('helvetica', 'Helvetica', 'Arimo'),
  ReaderFont('system', 'Sans', null),
  ReaderFont('caveat', 'Caveat', 'Caveat'),
  ReaderFont('dancing_script', 'Dancing Script', 'Dancing Script'),
  ReaderFont('patrick_hand', 'Patrick Hand', 'Patrick Hand'),
  ReaderFont('indie_flower', 'Indie Flower', 'Indie Flower'),
  ReaderFont('shadows_into_light', 'Shadows Into Light', 'Shadows Into Light'),
  ReaderFont('mono', 'Mono', 'IBM Plex Mono'),
  ReaderFont('jetbrains_mono', 'JetBrains Mono', 'JetBrains Mono'),
  ReaderFont('source_code_pro', 'Source Code Pro', 'Source Code Pro'),
];

@immutable
final class ReaderAppearance {
  const ReaderAppearance({
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.fontKey = defaultFont,
    this.themeKey = defaultTheme,
    this.customThemes = const [],
    this.paged = false,
  });

  static const fontSizeMin = 14.0;
  static const fontSizeMax = 30.0;

  /// Pinch zoom may go past the buttons' max, as on the web reader.
  static const pinchFontSizeMax = 42.0;
  static const lineHeightMin = 1.4;
  static const lineHeightMax = 2.2;
  static const defaultFontSize = 18.0;
  static const defaultLineHeight = 1.8;
  static const defaultFont = 'literata';
  static const defaultTheme = 'parchment';

  final double fontSize;
  final double lineHeight;
  final String fontKey;
  final String themeKey;
  final List<ReaderTheme> customThemes;

  /// Page-by-page (swipe) layout instead of one continuous scroll.
  final bool paged;

  /// Built-ins first, then custom themes newest first, as on the web.
  List<ReaderTheme> get themes => [...readerBuiltInThemes, ...customThemes];

  ReaderTheme get theme => themes.firstWhere(
    (item) => item.key == themeKey,
    orElse: () => readerBuiltInThemes.first,
  );

  ReaderFont get font => readerFonts.firstWhere(
    (item) => item.key == fontKey,
    orElse: () => readerFonts.first,
  );

  ReaderAppearance copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontKey,
    String? themeKey,
    List<ReaderTheme>? customThemes,
    bool? paged,
  }) => ReaderAppearance(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    fontKey: fontKey ?? this.fontKey,
    themeKey: themeKey ?? this.themeKey,
    customThemes: customThemes ?? this.customThemes,
    paged: paged ?? this.paged,
  );
}

final readerAppearanceProvider =
    NotifierProvider<ReaderAppearanceController, ReaderAppearance>(
      ReaderAppearanceController.new,
    );

/// Reader appearance shared by the app's text readers, persisted on device.
/// Uses the web reader's storage key names so the two stay recognisable.
class ReaderAppearanceController extends Notifier<ReaderAppearance> {
  static const _keyFont = 'reader_font';
  static const _keyTheme = 'reader_theme';
  static const _keyCustomThemes = 'reader_custom_themes';
  static const _keyFontSize = 'reader_font_size';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyLayout = 'reader_layout';

  @override
  ReaderAppearance build() {
    _load();
    return const ReaderAppearance();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var custom = const <ReaderTheme>[];
      final rawCustom = prefs.getString(_keyCustomThemes);
      if (rawCustom != null) {
        final decoded = jsonDecode(rawCustom);
        if (decoded is List) {
          custom = decoded.map(ReaderTheme.fromJson).nonNulls.toList();
        }
      }
      final loaded = ReaderAppearance(
        fontSize: _clampSize(
          prefs.getDouble(_keyFontSize) ?? ReaderAppearance.defaultFontSize,
        ),
        lineHeight: _clampLineHeight(
          prefs.getDouble(_keyLineHeight) ?? ReaderAppearance.defaultLineHeight,
        ),
        fontKey: prefs.getString(_keyFont) ?? ReaderAppearance.defaultFont,
        themeKey: prefs.getString(_keyTheme) ?? ReaderAppearance.defaultTheme,
        customThemes: custom,
        paged: prefs.getString(_keyLayout) == 'paged',
      );
      // A deleted/unknown theme falls back to the default.
      state = loaded.themes.any((item) => item.key == loaded.themeKey)
          ? loaded
          : loaded.copyWith(themeKey: ReaderAppearance.defaultTheme);
    } catch (_) {
      // Corrupt or unavailable storage: keep defaults.
    }
  }

  Future<void> _save(void Function(SharedPreferences prefs) write) async {
    try {
      write(await SharedPreferences.getInstance());
    } catch (_) {
      // Preferences are a convenience; the in-memory state still applies.
    }
  }

  static double _clampSize(double value) => value
      .clamp(ReaderAppearance.fontSizeMin, ReaderAppearance.pinchFontSizeMax)
      .roundToDouble();

  static double _clampLineHeight(double value) =>
      (value.clamp(
                ReaderAppearance.lineHeightMin,
                ReaderAppearance.lineHeightMax,
              ) *
              10)
          .round() /
      10;

  /// Buttons stay within the regular range; [allowPinchRange] lets pinch
  /// zoom reach the larger web maximum.
  void setFontSize(double value, {bool allowPinchRange = false}) {
    final max = allowPinchRange
        ? ReaderAppearance.pinchFontSizeMax
        : math.max(ReaderAppearance.fontSizeMax, state.fontSize);
    final next = value.clamp(ReaderAppearance.fontSizeMin, max).roundToDouble();
    if (next == state.fontSize) return;
    state = state.copyWith(fontSize: next);
    _save((prefs) => prefs.setDouble(_keyFontSize, next));
  }

  void setLineHeight(double value) {
    final next = _clampLineHeight(value);
    if (next == state.lineHeight) return;
    state = state.copyWith(lineHeight: next);
    _save((prefs) => prefs.setDouble(_keyLineHeight, next));
  }

  void setPaged(bool paged) {
    state = state.copyWith(paged: paged);
    _save((prefs) => prefs.setString(_keyLayout, paged ? 'paged' : 'scroll'));
  }

  void setFont(String key) {
    state = state.copyWith(fontKey: key);
    _save((prefs) => prefs.setString(_keyFont, key));
  }

  void setTheme(String key) {
    state = state.copyWith(themeKey: key);
    _save((prefs) => prefs.setString(_keyTheme, key));
  }

  /// Saves a custom theme, selects it and returns its key.
  String createCustomTheme({
    required String name,
    required Color background,
    required Color border,
    required Color text,
    required Color link,
    required bool isDark,
  }) {
    final trimmed = name.trim();
    final theme = ReaderTheme(
      key: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      label: trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed,
      background: background,
      border: border,
      text: text,
      heading: text,
      link: link,
      isDark: isDark,
      isCustom: true,
    );
    final custom = [theme, ...state.customThemes];
    state = state.copyWith(customThemes: custom, themeKey: theme.key);
    _save((prefs) {
      prefs.setString(
        _keyCustomThemes,
        jsonEncode([for (final item in custom) item.toJson()]),
      );
      prefs.setString(_keyTheme, theme.key);
    });
    return theme.key;
  }

  void deleteCustomTheme(String key) {
    final custom = [
      for (final item in state.customThemes)
        if (item.key != key) item,
    ];
    final themeKey = state.themeKey == key
        ? ReaderAppearance.defaultTheme
        : state.themeKey;
    state = state.copyWith(customThemes: custom, themeKey: themeKey);
    _save((prefs) {
      prefs.setString(
        _keyCustomThemes,
        jsonEncode([for (final item in custom) item.toJson()]),
      );
      prefs.setString(_keyTheme, themeKey);
    });
  }
}

// Contrast helpers, matching worldstories_f/src/lib/readerContrast.ts.

const _lightFallback = Color(0xFFF8FAFC);
const _darkFallback = Color(0xFF111827);

double colorContrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

bool hasAccessibleTextContrast(
  Color foreground,
  Color background, {
  double minimum = 4.5,
}) => colorContrastRatio(foreground, background) >= minimum;

Color ensureAccessibleTextColor(Color requested, Color background) {
  if (hasAccessibleTextContrast(requested, background)) return requested;
  return colorContrastRatio(_lightFallback, background) >=
          colorContrastRatio(_darkFallback, background)
      ? _lightFallback
      : _darkFallback;
}

String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

Color? hexToColor(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  var hex = match.group(1)!;
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// Glass surface for floating reader chrome, like the web's
/// `READER_GLASS_PANEL_CLASS`: a primary-tinted gradient over the theme.
BoxDecoration readerGlassDecoration(
  ReaderTheme theme, {
  BorderRadius? radius,
}) => BoxDecoration(
  borderRadius: radius,
  border: Border.all(
    color: theme.isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
  ),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.alphaBlend(
        AppTheme.primary.withValues(alpha: 0.10),
        theme.isDark ? const Color(0xF21B2230) : const Color(0xF2FFFFFF),
      ),
      theme.isDark ? const Color(0x991B2230) : const Color(0x99FFFFFF),
    ],
  ),
  boxShadow: const [
    BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4)),
  ],
);
