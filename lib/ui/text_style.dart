import 'package:material_ui/material_ui.dart';

import 'color.dart';

enum FontFamily {
  twEmoji('Twemoji'),
  openMoji('OpenMoji'),
  mapleMono('MapleMono'),
  jetBrainsMono('MapleMono');

  final String value;

  const FontFamily(this.value);
}

extension TextStyleExtension on TextStyle {
  TextStyle get toLight => copyWith(color: color?.opacity80);

  TextStyle get toLighter => copyWith(color: color?.opacity60);

  TextStyle get toMapleMono =>
      copyWith(fontFamily: FontFamily.mapleMono.value);

  TextStyle get toJetBrainsMono => toMapleMono;

  TextStyle get toTabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
