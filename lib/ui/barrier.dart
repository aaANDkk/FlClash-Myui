import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

/// The blur behind a modal barrier.
///
/// The sigma is constant: animating it rebuilt the filter on every frame, which
/// is what made sheets stutter on Windows. A desktop window is also many times
/// the pixels of a phone screen, so it takes a lighter blur.
class BarrierBlur extends StatelessWidget {
  const BarrierBlur({super.key});

  static double get sigma => system.isDesktop ? 2.0 : 5.0;

  @override
  Widget build(BuildContext context) {
    final sigma = BarrierBlur.sigma;
    return RepaintBoundary(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
