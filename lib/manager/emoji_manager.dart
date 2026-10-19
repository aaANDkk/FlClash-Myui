import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';

enum EmojiStyle {
  twEmoji(
    family: 'Twemoji',
    label: 'Twemoji',
  ),
  openMoji(
    family: 'OpenMoji',
    label: 'Openmoji',
  );

  final String family;
  final String label;

  const EmojiStyle({
    required this.family,
    required this.label,
  });
}

class EmojiManager {
  static final ValueNotifier<EmojiStyle> emojiStyleNotifier =
      ValueNotifier<EmojiStyle>(EmojiStyle.twEmoji);

  static EmojiStyle get currentStyle => emojiStyleNotifier.value;
  static String? get currentFamily => emojiStyleNotifier.value.family;

  static const String _prefKeyEmojiStyle = 'selected_emoji_style';

  /// Initializes emoji style preference and registers font licenses on app startup
  static Future<void> init() async {
    _registerLicenses();
    try {
      final prefs = await preferences.sharedPreferences;
      final saved = prefs?.getString(_prefKeyEmojiStyle);
      if (saved != null && saved.isNotEmpty) {
        final style = EmojiStyle.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => EmojiStyle.twEmoji,
        );
        emojiStyleNotifier.value = style;
      }
    } catch (e, stack) {
      commonPrint.log('EmojiManager.init failed: $e\n$stack');
    }
  }

  /// Register open-source font licenses
  static void _registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(
        ['OpenMoji'],
        '''
All emojis designed by OpenMoji – the open-source emoji and icon project.
Authors: HfG Schwäbisch Gmünd and contributors (https://openmoji.org)
License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
License URL: https://creativecommons.org/licenses/by-sa/4.0/
''',
      );
      yield const LicenseEntryWithLineBreaks(
        ['Twemoji'],
        '''
Twemoji Graphics & Font Assets
Copyright 2019 Twitter, Inc and other contributors
Copyright 2024 Twemoji contributors (https://github.com/jdecked/twemoji)
License: Creative Commons Attribution 4.0 International (CC-BY 4.0)
License URL: https://creativecommons.org/licenses/by/4.0/
''',
      );
    });
  }

  /// Sets active emoji style and saves preference
  static Future<void> setStyle(EmojiStyle style) async {
    if (emojiStyleNotifier.value == style) return;
    emojiStyleNotifier.value = style;
    try {
      final prefs = await preferences.sharedPreferences;
      await prefs?.setString(_prefKeyEmojiStyle, style.name);
    } catch (e, stack) {
      commonPrint.log('EmojiManager.setStyle failed: $e\n$stack');
    }
  }
}
