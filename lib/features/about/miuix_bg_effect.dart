import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

class MiuixBgConfig {
  const MiuixBgConfig({
    required this.points,
    required this.colors1,
    required this.colors2,
    required this.colors3,
    required this.colorInterpPeriod,
    required this.lightOffset,
    required this.saturateOffset,
    required this.pointOffset,
  });

  final List<double> points;
  final List<double> colors1;
  final List<double> colors2;
  final List<double> colors3;
  final double colorInterpPeriod;
  final double lightOffset;
  final double saturateOffset;
  final double pointOffset;

  static const _defaultPoints = <double>[
    0.8, 0.2, 1.0,
    0.8, 0.9, 1.0,
    0.2, 0.9, 1.0,
    0.2, 0.2, 1.0,
  ];

  static const os3PhoneLight = MiuixBgConfig(
    points: _defaultPoints,
    colors1: [
      1.0, 0.9, 0.94, 1.0,
      1.0, 0.84, 0.89, 1.0,
      0.97, 0.73, 0.82, 1.0,
      0.64, 0.65, 0.98, 1.0,
    ],
    colors2: [
      0.58, 0.74, 1.0, 1.0,
      1.0, 0.9, 0.93, 1.0,
      0.74, 0.76, 1.0, 1.0,
      0.97, 0.77, 0.84, 1.0,
    ],
    colors3: [
      0.98, 0.86, 0.9, 1.0,
      0.6, 0.73, 0.98, 1.0,
      0.92, 0.93, 1.0, 1.0,
      0.56, 0.69, 1.0, 1.0,
    ],
    colorInterpPeriod: 5.0,
    lightOffset: 0.1,
    saturateOffset: 0.2,
    pointOffset: 0.2,
  );

  static const os3PhoneDark = MiuixBgConfig(
    points: _defaultPoints,
    colors1: [
      0.2, 0.06, 0.88, 0.4,
      0.3, 0.14, 0.55, 0.5,
      0.0, 0.64, 0.96, 0.5,
      0.11, 0.16, 0.83, 0.4,
    ],
    colors2: [
      0.07, 0.15, 0.79, 0.5,
      0.62, 0.21, 0.67, 0.5,
      0.06, 0.25, 0.84, 0.5,
      0.0, 0.2, 0.78, 0.5,
    ],
    colors3: [
      0.58, 0.3, 0.74, 0.4,
      0.27, 0.18, 0.6, 0.5,
      0.66, 0.26, 0.62, 0.5,
      0.12, 0.16, 0.7, 0.6,
    ],
    colorInterpPeriod: 8.0,
    lightOffset: 0.0,
    saturateOffset: 0.17,
    pointOffset: 0.4,
  );

  static const os3PadLight = MiuixBgConfig(
    points: _defaultPoints,
    colors1: [
      0.99, 0.77, 0.86, 1.0,
      0.74, 0.76, 1.0, 1.0,
      0.72, 0.74, 1.0, 1.0,
      0.98, 0.76, 0.8, 1.0,
    ],
    colors2: [
      0.66, 0.75, 1.0, 1.0,
      1.0, 0.86, 0.91, 1.0,
      0.74, 0.76, 1.0, 1.0,
      0.97, 0.77, 0.84, 1.0,
    ],
    colors3: [
      0.97, 0.79, 0.85, 1.0,
      0.65, 0.68, 0.98, 1.0,
      0.66, 0.77, 1.0, 1.0,
      0.72, 0.73, 0.98, 1.0,
    ],
    colorInterpPeriod: 7.0,
    lightOffset: 0.1,
    saturateOffset: 0.2,
    pointOffset: 0.2,
  );

  static const os3PadDark = MiuixBgConfig(
    points: _defaultPoints,
    colors1: [
      0.66, 0.26, 0.62, 0.4,
      0.06, 0.25, 0.84, 0.5,
      0.0, 0.64, 0.96, 0.5,
      0.14, 0.18, 0.55, 0.5,
    ],
    colors2: [
      0.07, 0.15, 0.79, 0.5,
      0.11, 0.16, 0.83, 0.5,
      0.06, 0.25, 0.84, 0.5,
      0.66, 0.26, 0.62, 0.5,
    ],
    colors3: [
      0.58, 0.3, 0.74, 0.5,
      0.11, 0.16, 0.83, 0.5,
      0.66, 0.26, 0.62, 0.5,
      0.27, 0.18, 0.6, 0.6,
    ],
    colorInterpPeriod: 7.0,
    lightOffset: 0.0,
    saturateOffset: 0.0,
    pointOffset: 0.2,
  );

  static MiuixBgConfig of({required bool isWide, required bool isDark}) {
    if (isWide) {
      return isDark ? os3PadDark : os3PadLight;
    }
    return isDark ? os3PhoneDark : os3PhoneLight;
  }
}

class MiuixBgEffectController extends ChangeNotifier {
  MiuixBgEffectController({required TickerProvider vsync}) : _vsync = vsync {
    _bgProgram = _cachedBgProgram;
    _titleProgram = _cachedTitleProgram;
    _ticker = _vsync.createTicker(_onTick);
    if (_bgProgram == null || _titleProgram == null) {
      _loadPrograms();
    }
  }

  static ui.FragmentProgram? _cachedBgProgram;
  static ui.FragmentProgram? _cachedTitleProgram;
  static Future<void>? _warmUpFuture;

  /// Preloads and compiles the About page shaders once per process so the
  /// first route push does not hitch waiting on shader compilation.
  static Future<void> warmUp() {
    if (_cachedBgProgram != null && _cachedTitleProgram != null) {
      return Future<void>.value();
    }
    return _warmUpFuture ??= () async {
      try {
        final results = await Future.wait([
          ui.FragmentProgram.fromAsset('shaders/about_bg.frag'),
          ui.FragmentProgram.fromAsset('shaders/about_title.frag'),
        ]);
        _cachedBgProgram = results[0];
        _cachedTitleProgram = results[1];
      } catch (_) {
        // Headless or software test environments without compiled shaders stay on fallback.
      } finally {
        _warmUpFuture = null;
      }
    }();
  }

  static const double _noiseScale = 1.5;
  static const double _pointRadiusMulti = 1.0;
  static const double _minFrameDelta = 1.0 / 60.0;
  static final _stageSpring = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 35.0,
    ratio: 0.9,
  );

  final TickerProvider _vsync;
  late final Ticker _ticker;

  ui.FragmentProgram? _bgProgram;
  ui.FragmentProgram? _titleProgram;
  ui.FragmentShader? _bgShader;
  ui.FragmentShader? _titleShader;
  ui.FragmentShader? _logoShader;

  bool _disposed = false;
  bool _playing = false;
  double _animTime = 0.0;
  double _lastTickSeconds = 0.0;
  double _lastEmitSeconds = -1.0;

  double _colorStage = 0.0;
  double _stageClock = 0.0;
  int _stageTarget = 1;
  SpringSimulation? _stageSim;
  double _simStartTime = 0.0;
  double _colorInterpPeriod = 5.0;

  ui.FragmentShader? get bgShader {
    if (_bgShader != null) return _bgShader;
    final program = _bgProgram;
    if (program == null) return null;
    return _bgShader = program.fragmentShader();
  }

  ui.FragmentShader? get titleShader {
    if (_titleShader != null) return _titleShader;
    final program = _titleProgram;
    if (program == null) return null;
    return _titleShader = program.fragmentShader();
  }

  ui.FragmentShader? get logoShader {
    if (_logoShader != null) return _logoShader;
    final program = _titleProgram;
    if (program == null) return null;
    return _logoShader = program.fragmentShader();
  }

  Future<void> _loadPrograms() async {
    await warmUp();
    if (_disposed) return;
    if (_bgProgram == _cachedBgProgram && _titleProgram == _cachedTitleProgram) {
      return;
    }
    _bgProgram = _cachedBgProgram;
    _titleProgram = _cachedTitleProgram;
    notifyListeners();
  }

  void sync({required bool playing, required double colorInterpPeriod}) {
    _colorInterpPeriod = colorInterpPeriod;
    if (_playing == playing) return;
    _playing = playing;
    if (playing) {
      if (!_ticker.isActive) {
        _lastTickSeconds = 0.0;
        _lastEmitSeconds = -1.0;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void startIfNeeded() {
    if (_playing && !_ticker.isActive) {
      _lastTickSeconds = 0.0;
      _lastEmitSeconds = -1.0;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final nowSeconds = elapsed.inMicroseconds / 1_000_000.0;
    if (_lastTickSeconds == 0.0) {
      _lastTickSeconds = nowSeconds;
    }
    if (nowSeconds - _lastEmitSeconds < _minFrameDelta && _lastEmitSeconds >= 0) {
      return;
    }
    final dt = nowSeconds - _lastTickSeconds;
    _lastTickSeconds = nowSeconds;
    _lastEmitSeconds = nowSeconds;

    _animTime += dt;
    _stageClock += dt;

    final holdSeconds = _colorInterpPeriod * 0.5;
    if (_stageSim == null && _stageClock >= holdSeconds) {
      _stageSim = SpringSimulation(
        _stageSpring,
        _colorStage,
        _stageTarget.toDouble(),
        0.0,
      );
      _simStartTime = _stageClock;
    }
    final sim = _stageSim;
    if (sim != null) {
      final simElapsed = _stageClock - _simStartTime;
      _colorStage = sim.x(simElapsed);
      if (sim.isDone(simElapsed)) {
        _colorStage = _stageTarget.toDouble();
        _stageTarget += 1;
        _stageSim = null;
        _stageClock = 0.0;
      }
    }
    notifyListeners();
  }

  List<double> _interpColors(MiuixBgConfig preset) {
    final base = _colorStage.floor();
    final fraction = _colorStage - base;
    List<double> cycle(int index) => switch (index % 4) {
      1 => preset.colors1,
      3 => preset.colors3,
      _ => preset.colors2,
    };
    final start = cycle(base);
    final end = cycle(base + 1);
    return List<double>.generate(
      16,
      (i) => start[i] + (end[i] - start[i]) * fraction,
      growable: false,
    );
  }

  List<double> _boundFor(Size size) {
    final width = math.max(size.width, 1.0);
    final height = math.max(size.height, 1.0);
    final drawHeight = height * 0.8;
    final heightRatio = drawHeight / height;
    if (width <= height) {
      return [0.0, 1.0 - heightRatio, 1.0, heightRatio];
    }
    final aspectRatio = width / height;
    final contentCenterY = 1.0 - heightRatio / 2.0;
    return [0.0, contentCenterY - aspectRatio / 2.0, 1.0, aspectRatio];
  }

  List<double> _pointsAnim(MiuixBgConfig preset) {
    final result = List<double>.filled(8, 0.0);
    final offset = preset.pointOffset;
    for (var i = 0; i < 4; i++) {
      final srcX = preset.points[i * 3];
      final srcY = preset.points[i * 3 + 1];
      final animX = srcX + math.sin(_animTime + srcY) * offset;
      final animY = srcY + math.cos(_animTime + animX) * offset;
      result[i * 2] = animX;
      result[i * 2 + 1] = animY;
    }
    return result;
  }

  void applyBgUniforms(
    ui.FragmentShader shader, {
    required Size size,
    required MiuixBgConfig preset,
    required double alpha,
  }) {
    final bound = _boundFor(size);
    final anim = _pointsAnim(preset);
    final colors = _interpColors(preset);
    var idx = 0;
    void set(double v) => shader.setFloat(idx++, v);

    set(size.width);
    set(size.height);
    set(_animTime);
    for (final v in bound) {
      set(v);
    }
    set(0.0); // uTranslateY
    for (var i = 0; i < 12; i++) {
      set(preset.points[i]);
    }
    for (final v in anim) {
      set(v);
    }
    for (final v in colors) {
      set(v);
    }
    set(alpha);
    set(_noiseScale);
    set(_pointRadiusMulti);
    set(preset.saturateOffset);
    set(preset.lightOffset);
  }

  void applyTitleUniforms(
    ui.FragmentShader shader, {
    required Size backdropSize,
    required Offset titleOffset,
    required MiuixBgConfig preset,
    required Color surface,
    required bool isDark,
    required double alpha,
  }) {
    final bound = _boundFor(backdropSize);
    final anim = _pointsAnim(preset);
    final colors = _interpColors(preset);
    var idx = 0;
    void set(double v) => shader.setFloat(idx++, v);

    set(backdropSize.width);
    set(backdropSize.height);
    set(titleOffset.dx);
    set(titleOffset.dy);
    set(_animTime);
    for (final v in bound) {
      set(v);
    }
    set(0.0); // uTranslateY
    for (var i = 0; i < 12; i++) {
      set(preset.points[i]);
    }
    for (final v in anim) {
      set(v);
    }
    for (final v in colors) {
      set(v);
    }
    set(alpha);
    set(_noiseScale);
    set(_pointRadiusMulti);
    set(preset.saturateOffset);
    set(preset.lightOffset);
    set(surface.r);
    set(surface.g);
    set(surface.b);
    set(surface.a);
    set(isDark ? 1.0 : 0.0);
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    _bgShader?.dispose();
    _titleShader?.dispose();
    _logoShader?.dispose();
    super.dispose();
  }
}

class MiuixAboutBackdrop extends StatelessWidget {
  const MiuixAboutBackdrop({
    super.key,
    required this.backdropKey,
    required this.controller,
    required this.preset,
    required this.alpha,
  });

  final GlobalKey backdropKey;
  final MiuixBgEffectController controller;
  final MiuixBgConfig preset;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final surface = SurfaceLevel.page.colorOf(context.colorScheme);
    return RepaintBoundary(
      key: backdropKey,
      child: CustomPaint(
        painter: _MiuixBgPainter(
          controller: controller,
          preset: preset,
          surface: surface,
          alpha: alpha,
        ),
      ),
    );
  }
}

class _MiuixBgPainter extends CustomPainter {
  _MiuixBgPainter({
    required this.controller,
    required this.preset,
    required this.surface,
    required this.alpha,
  }) : super(repaint: controller);

  final MiuixBgEffectController controller;
  final MiuixBgConfig preset;
  final Color surface;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surface);
    if (alpha <= 0) return;
    final shader = controller.bgShader;
    if (shader != null) {
      controller.applyBgUniforms(
        shader,
        size: size,
        preset: preset,
        alpha: alpha,
      );
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      return;
    }
    // Fallback gradient matching the theme colors when runtime shaders are unavailable.
    final c0 = Color.from(
      alpha: preset.colors2[3] * alpha,
      red: preset.colors2[0],
      green: preset.colors2[1],
      blue: preset.colors2[2],
    );
    final c1 = Color.from(
      alpha: preset.colors2[11] * alpha,
      red: preset.colors2[8],
      green: preset.colors2[9],
      blue: preset.colors2[10],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.2, 0),
          Offset(size.width * 0.8, size.height * 0.7),
          [c0, c1, surface.withValues(alpha: 0)],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _MiuixBgPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.surface != surface ||
      oldDelegate.alpha != alpha ||
      oldDelegate.controller != controller;
}

class MiuixChromaticTitle extends StatelessWidget {
  const MiuixChromaticTitle({
    super.key,
    required this.text,
    required this.style,
    required this.backdropKey,
    required this.controller,
    required this.preset,
  });

  final String text;
  final TextStyle style;
  final GlobalKey backdropKey;
  final MiuixBgEffectController controller;
  final MiuixBgConfig preset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = SurfaceLevel.page.colorOf(colorScheme);
    // Paragraph ellipsis clips glyph ink before the mask's padding can help.
    const maskPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    Widget buildLabel(TextStyle textStyle) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: maskPadding,
        child: Text(
          text,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: textStyle,
        ),
      ),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final shader = controller.titleShader;
        if (shader == null) {
          return buildLabel(style);
        }
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final backdropBox =
                backdropKey.currentContext?.findRenderObject() as RenderBox?;
            final selfBox = context.findRenderObject() as RenderBox?;
            final backdropSize =
                backdropBox != null && backdropBox.hasSize
                    ? backdropBox.size
                    : bounds.size;
            var offset = Offset.zero;
            if (backdropBox != null &&
                backdropBox.hasSize &&
                selfBox != null &&
                selfBox.hasSize) {
              offset = selfBox.localToGlobal(
                Offset.zero,
                ancestor: backdropBox,
              );
            }
            controller.applyTitleUniforms(
              shader,
              backdropSize: backdropSize,
              titleOffset: offset,
              preset: preset,
              surface: surface,
              isDark: isDark,
              alpha: 1.0,
            );
            return shader;
          },
          child: CustomPaint(
            painter: const _TitleLayerBoundsPainter(),
            child: child,
          ),
        );
      },
      child: buildLabel(style.copyWith(color: const Color(0xFFFFFFFF))),
    );
  }
}

class MiuixChromaticLogo extends StatelessWidget {
  const MiuixChromaticLogo({
    super.key,
    required this.assetPath,
    required this.size,
    required this.backdropKey,
    required this.controller,
    required this.preset,
  });

  final String assetPath;
  final double size;
  final GlobalKey backdropKey;
  final MiuixBgEffectController controller;
  final MiuixBgConfig preset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = SurfaceLevel.page.colorOf(colorScheme);
    const maskPadding = EdgeInsets.all(4);
    Widget buildSvg(Color tint) => Padding(
      padding: maskPadding,
      child: SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final shader = controller.logoShader;
        if (shader == null) {
          return buildSvg(colorScheme.onSurface);
        }
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final backdropBox =
                backdropKey.currentContext?.findRenderObject() as RenderBox?;
            final selfBox = context.findRenderObject() as RenderBox?;
            final backdropSize = backdropBox != null && backdropBox.hasSize
                ? backdropBox.size
                : bounds.size;
            var offset = Offset.zero;
            if (backdropBox != null &&
                backdropBox.hasSize &&
                selfBox != null &&
                selfBox.hasSize) {
              offset = selfBox.localToGlobal(
                Offset.zero,
                ancestor: backdropBox,
              );
            }
            controller.applyTitleUniforms(
              shader,
              backdropSize: backdropSize,
              titleOffset: offset,
              preset: preset,
              surface: surface,
              isDark: isDark,
              alpha: 1.0,
            );
            return shader;
          },
          child: CustomPaint(
            painter: const _TitleLayerBoundsPainter(),
            child: child,
          ),
        );
      },
      child: buildSvg(const Color(0xFFFFFFFF)),
    );
  }
}

class _TitleLayerBoundsPainter extends CustomPainter {
  const _TitleLayerBoundsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Padding alone does not expand display-list ink bounds. Some hinted fonts
    // report undersized glyph bounds, clipping ShaderMask/Opacity layers:
    // https://github.com/flutter/flutter/issues/161721
    // A transparent src draw clears this fresh mask layer and records its full
    // padded bounds. srcOver would be a no-op and could be discarded instead.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0x00000000)
        ..blendMode = BlendMode.src,
    );
  }

  @override
  bool shouldRepaint(covariant _TitleLayerBoundsPainter oldDelegate) => false;
}
