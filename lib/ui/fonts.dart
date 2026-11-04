import 'package:flutter/widgets.dart';

/// The fonts FlClash bundles, declared in its `pubspec.yaml`.
enum FontFamily {
  twEmoji('Twemoji'),
  openMoji('OpenMoji'),
  mapleMono('MapleMono'),
  jetBrainsMono('MapleMono');

  final String value;

  const FontFamily(this.value);
}

extension FontFamilyTextStyle on TextStyle {
  TextStyle get toMapleMono => copyWith(fontFamily: FontFamily.mapleMono.value);

  TextStyle get toJetBrainsMono => toMapleMono;
}
