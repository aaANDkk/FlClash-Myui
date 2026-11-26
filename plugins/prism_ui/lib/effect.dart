import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/inherited.dart';
import 'package:prism_ui/surface.dart';

Widget commonProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (_, Widget? child) {
      final double animValue = Curves.easeInOut.transform(animation.value);
      final double scale = lerpDouble(1, 1.02, animValue)!;
      // The lifted row leaves the page, and its text style, for the overlay.
      return ProxyDecoratorProvider(
        isProxyDecorator: true,
        lift: animValue,
        child: Surface.transparent(
          child: Transform.scale(scale: scale, child: child),
        ),
      );
    },
    child: child,
  );
}
