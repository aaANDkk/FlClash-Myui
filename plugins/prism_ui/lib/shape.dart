import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/input_border.dart';

abstract final class AppCorner {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;

  /// UIAlertController's corner on iOS 27, rounder than a sheet's.
  static const double alert = 34;
  static const double full = 1000;

  static double fit(double shortestSide) {
    final limit = shortestSide / 3;
    if (limit >= xxl) return xxl;
    if (limit >= xl) return xl;
    if (limit >= lg) return lg;
    if (limit >= md) return md;
    if (limit >= sm) return sm;
    if (limit >= xs) return xs;
    return none;
  }
}

abstract final class AppRadius {
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius xs = BorderRadius.all(
    Radius.circular(AppCorner.xs),
  );
  static const BorderRadius sm = BorderRadius.all(
    Radius.circular(AppCorner.sm),
  );
  static const BorderRadius md = BorderRadius.all(
    Radius.circular(AppCorner.md),
  );
  static const BorderRadius lg = BorderRadius.all(
    Radius.circular(AppCorner.lg),
  );
  static const BorderRadius xl = BorderRadius.all(
    Radius.circular(AppCorner.xl),
  );
  static const BorderRadius xxl = BorderRadius.all(
    Radius.circular(AppCorner.xxl),
  );
  static const BorderRadius full = BorderRadius.all(
    Radius.circular(AppCorner.full),
  );

  static BorderRadius all(double corner) => BorderRadius.circular(corner);

  static BorderRadius top(double corner) =>
      BorderRadius.vertical(top: Radius.circular(corner));

  static BorderRadius vertical({
    double top = AppCorner.none,
    double bottom = AppCorner.none,
  }) => BorderRadius.vertical(
    top: Radius.circular(top),
    bottom: Radius.circular(bottom),
  );
}


bool get _isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
  _ => false,
};

/// Rounded superellipse that renders true continuous corners on desktop (Skia).
///
/// On mobile (Android/iOS), Impeller natively accelerates
/// [Canvas.drawRSuperellipse], so this border delegates all painting to the
/// official implementation. On desktop Skia falls back to plain rounded
/// rectangles; this border caches the analytical superellipse path instead.
class SuperellipseBorder extends RoundedSuperellipseBorder {
  const SuperellipseBorder({super.side, super.borderRadius});

  static final Map<Object, Path> _pathSizeCache = <Object, Path>{};
  static const int _pathCacheLimit = 256;

  Path _getPathForSize(Size size, TextDirection? textDirection) {
    final key = Object.hash(size, borderRadius, textDirection);
    final cached = _pathSizeCache[key];
    if (cached != null) {
      return cached;
    }
    final path = super.getOuterPath(
      Offset.zero & size,
      textDirection: textDirection,
    );
    if (_pathSizeCache.length >= _pathCacheLimit) {
      _pathSizeCache.remove(_pathSizeCache.keys.first);
    }
    _pathSizeCache[key] = path;
    return path;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (!_isDesktop) {
      return super.getOuterPath(rect, textDirection: textDirection);
    }
    final localPath = _getPathForSize(rect.size, textDirection);
    return rect.topLeft == Offset.zero
        ? localPath
        : localPath.shift(rect.topLeft);
  }

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    if (!_isDesktop) {
      super.paintInterior(canvas, rect, paint, textDirection: textDirection);
      return;
    }
    final localPath = _getPathForSize(rect.size, textDirection);
    if (rect.topLeft == Offset.zero) {
      canvas.drawPath(localPath, paint);
    } else {
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.drawPath(localPath, paint);
      canvas.restore();
    }
  }

  @override
  SuperellipseBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SuperellipseBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return SuperellipseBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    final res = super.lerpFrom(a, t);
    return res is RoundedSuperellipseBorder
        ? SuperellipseBorder(side: res.side, borderRadius: res.borderRadius)
        : res;
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    final res = super.lerpTo(b, t);
    return res is RoundedSuperellipseBorder
        ? SuperellipseBorder(side: res.side, borderRadius: res.borderRadius)
        : res;
  }
}

abstract final class AppShape {
  static const SuperellipseBorder none = SuperellipseBorder();
  static const SuperellipseBorder xs = SuperellipseBorder(
    borderRadius: AppRadius.xs,
  );
  static const SuperellipseBorder sm = SuperellipseBorder(
    borderRadius: AppRadius.sm,
  );
  static const SuperellipseBorder md = SuperellipseBorder(
    borderRadius: AppRadius.md,
  );
  static const SuperellipseBorder lg = SuperellipseBorder(
    borderRadius: AppRadius.lg,
  );
  static const SuperellipseBorder xl = SuperellipseBorder(
    borderRadius: AppRadius.xl,
  );
  static const SuperellipseBorder xxl = SuperellipseBorder(
    borderRadius: AppRadius.xxl,
  );
  static const RoundedSuperellipseBorder full = RoundedSuperellipseBorder(
    borderRadius: AppRadius.full,
  );
  static const CircleBorder circle = CircleBorder();
  static const AppInputBorder input = AppInputBorder();

  static SuperellipseBorder all(double corner) =>
      SuperellipseBorder(borderRadius: AppRadius.all(corner));

  static SuperellipseBorder top(double corner) =>
      SuperellipseBorder(borderRadius: AppRadius.top(corner));

  static SuperellipseBorder vertical({
    double top = AppCorner.none,
    double bottom = AppCorner.none,
  }) => SuperellipseBorder(
    borderRadius: AppRadius.vertical(top: top, bottom: bottom),
  );

  static SuperellipseBorder of(BorderRadius borderRadius) =>
      SuperellipseBorder(borderRadius: borderRadius);
}

class AppInputBorder extends InputBorder {
  const AppInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = AppRadius.md,
  });

  final BorderRadius borderRadius;

  SuperellipseBorder get _shape =>
      SuperellipseBorder(borderRadius: borderRadius, side: borderSide);

  @override
  bool get isOutline => true;

  @override
  bool get preferPaintInterior => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  AppInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) {
    return AppInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  AppInputBorder scale(double t) {
    return AppInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => _shape.paintInterior(canvas, rect, paint, textDirection: textDirection);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is AppInputBorder) {
      return AppInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is AppInputBorder) {
      return AppInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _shape.paint(canvas, rect, textDirection: textDirection);
}
