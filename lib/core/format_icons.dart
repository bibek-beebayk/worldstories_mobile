import 'package:flutter/material.dart';

/// The one icon per story format, shared by every screen that shows a format
/// (library mode chips, story detail pills and chapter rows, home sections),
/// so a format always looks the same across the app.
abstract final class FormatIcons {
  static const read = Icons.chrome_reader_mode_outlined;
  static const listen = Icons.headphones_outlined;
  static const readAlong = Icons.record_voice_over_outlined;
  static const watch = Icons.play_circle_outline;
  static const quickRead = Icons.bolt_outlined;
}

/// The one accent color per story format, used alongside [FormatIcons]
/// (story option pills, continue-where-you-left-off cards) so each format
/// is color coded the same way everywhere.
abstract final class FormatColors {
  static const read = Color(0xFFED405A);
  static const listen = Color(0xFF7C3AED);
  static const readAlong = Color(0xFF0D9488);
  static const watch = Color(0xFFEA580C);
}
