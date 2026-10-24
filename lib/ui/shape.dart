import 'dart:math' as math;
import 'dart:ui' show ClipOp, lerpDouble;

import 'package:fl_clash/common/system.dart';
import 'package:material_ui/material_ui.dart';

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

/// Rounded superellipse that renders true continuous corners on desktop (Skia).
///
/// On mobile (Android/iOS), Impeller natively accelerates [Canvas.drawRSuperellipse].
/// On desktop (Windows/macOS/Linux), Skia falls back to plain rounded rectangles;
/// this border caches the analytical superellipse path by [rect.size] to provide
/// smooth iOS-style continuous corners on desktop without performance overhead.
class SuperellipseBorder extends RoundedSuperellipseBorder {
  const SuperellipseBorder({super.side, super.borderRadius});

  static final Map<Object, Path> _pathCache = <Object, Path>{};

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    if (!system.isDesktop) {
      super.paintInterior(canvas, rect, paint, textDirection: textDirection);
      return;
    }
    final key = Object.hash(rect.size, borderRadius, textDirection);
    var path = _pathCache[key];
    if (path == null) {
      path = super.getOuterPath(Offset.zero & rect.size, textDirection: textDirection);
      if (_pathCache.length < 128) {
        _pathCache[key] = path;
      }
    }
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.drawPath(path, paint);
    canvas.restore();
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
  static const SuperellipseBorder full = SuperellipseBorder(
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
    this.gapPadding = 4.0,
  });

  final BorderRadius borderRadius;
  final double gapPadding;

  RoundedSuperellipseBorder get _shape =>
      RoundedSuperellipseBorder(borderRadius: borderRadius, side: borderSide);

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
    double? gapPadding,
  }) {
    return AppInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      gapPadding: gapPadding ?? this.gapPadding,
    );
  }

  @override
  AppInputBorder scale(double t) {
    return AppInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
      gapPadding: gapPadding * t,
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
        gapPadding: a.gapPadding,
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
        gapPadding: b.gapPadding,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final outline = rect.deflate(borderSide.width / 2);
    if (gapStart == null || gapExtent <= 0.0 || gapPercentage == 0.0) {
      _shape.paint(canvas, rect, textDirection: textDirection);
      return;
    }
    final extent = lerpDouble(
      0.0,
      gapExtent + gapPadding * 2.0,
      gapPercentage,
    )!;
    final start = switch (textDirection ?? TextDirection.ltr) {
      TextDirection.rtl => gapStart + gapPadding - extent,
      TextDirection.ltr => gapStart - gapPadding,
    };
    final radii = borderRadius.resolve(textDirection);
    final left = outline.left + math.max(0.0, start);
    final depth =
        math.max(radii.topLeft.y, radii.topRight.y) + borderSide.width;
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          left,
          outline.top - borderSide.width,
          left + extent,
          outline.top + depth,
        ),
        clipOp: ClipOp.difference,
      );
    _shape.paint(canvas, rect, textDirection: textDirection);
    canvas.restore();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppInputBorder &&
        other.borderSide == borderSide &&
        other.borderRadius == borderRadius &&
        other.gapPadding == gapPadding;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius, gapPadding);
}

extension AppShapeThemeExt on ThemeData {
  ThemeData get withAppShapes => copyWith(
    cardTheme: cardTheme.copyWith(shape: AppShape.md),
    dialogTheme: dialogTheme.copyWith(shape: AppShape.all(AppCorner.alert)),
    bottomSheetTheme: bottomSheetTheme.copyWith(
      shape: AppShape.top(AppCorner.xxl),
    ),
    snackBarTheme: snackBarTheme.copyWith(shape: AppShape.xs),
    tooltipTheme: tooltipTheme.copyWith(
      // A decoration replaces Material's tooltip colours too, so restate them.
      decoration: ShapeDecoration(
        shape: AppShape.xs,
        color: switch (brightness) {
          Brightness.dark => Colors.white.withAlpha(230),
          Brightness.light => Colors.grey[700]!.withAlpha(230),
        },
      ),
    ),
    chipTheme: chipTheme.copyWith(shape: AppShape.sm),
    popupMenuTheme: popupMenuTheme.copyWith(shape: AppShape.md),
    menuTheme: MenuThemeData(
      style: (menuTheme.style ?? const MenuStyle()).copyWith(
        shape: const WidgetStatePropertyAll(AppShape.md),
      ),
    ),
    inputDecorationTheme: inputDecorationTheme.copyWith(border: AppShape.input),
    floatingActionButtonTheme: floatingActionButtonTheme.copyWith(
      shape: AppShape.md,
    ),
    navigationBarTheme: navigationBarTheme.copyWith(
      indicatorShape: AppShape.full,
    ),
    navigationRailTheme: navigationRailTheme.copyWith(
      indicatorShape: AppShape.full,
    ),
    progressIndicatorTheme: progressIndicatorTheme.copyWith(
      borderRadius: AppRadius.full,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: filledButtonTheme.style?.merge(_pillButton) ?? _pillButton,
    ),
    textButtonTheme: TextButtonThemeData(
      style: textButtonTheme.style?.merge(_pillButton) ?? _pillButton,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlinedButtonTheme.style?.merge(_pillButton) ?? _pillButton,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: elevatedButtonTheme.style?.merge(_pillButton) ?? _pillButton,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: iconButtonTheme.style?.merge(_pillButton) ?? _pillButton,
    ),
  );
}

const _pillButton = ButtonStyle(shape: WidgetStatePropertyAll(AppShape.full));
