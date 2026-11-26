import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/drag_back.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/motion.dart';
import 'package:prism_ui/sheet_navigator.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/theme_data.dart';
import 'package:prism_ui/route_scope.dart';

/// iOS 27 pushes and pops a page on a critically damped spring of 0.3 s that
/// sets off at nine times its distance a second, as measured on the simulator.
final _pushSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 300),
);
const _pushSpeed = 9.0;
const _settleTolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

/// For what reads a route's duration rather than following its animation.
Duration _settlingTimeOf(SpringDescription spring, double launchSpeed) {
  final simulation = SpringSimulation(
    spring,
    0,
    1,
    launchSpeed,
    tolerance: _settleTolerance,
  );
  var milliseconds = 0;
  while (!simulation.isDone(milliseconds / 1000)) {
    milliseconds++;
  }
  return Duration(milliseconds: milliseconds);
}

const _coveredSlide = 0.3;
const _coveredDim = Color.from(alpha: 0.1, red: 0, green: 0, blue: 0);

/// UIKit's zoom shrinks the page it covers toward its center by 34.667 dp of
/// width, to no less than 80%, and dims it.
const _recededShrinkWidth = 34.667;
const _recededMinScale = 0.8;
const _recededDim = Color.from(alpha: 0.15, red: 0, green: 0, blue: 0);

double _recededShrinkOf(Size size) =>
    math.min(1 - _recededMinScale, _recededShrinkWidth / size.width);

/// What a 4% black Gaussian of sigma 12 casts past the card's leading edge.
const _cardShadowSigma = 12.0;
const _cardShadowStops = [0.0, 1 / 6, 1 / 3, 1 / 2, 2 / 3, 1.0];
final _cardShadowColors = [
  for (final share in const [0.5, 0.3085, 0.1587, 0.0668, 0.0228, 0.0])
    Color.from(alpha: 0.04 * share, red: 0, green: 0, blue: 0),
];

Rect _scaleTowardCenter(Rect rect, Size size, double scale) {
  final center = size.center(Offset.zero);
  return Rect.fromLTRB(
    center.dx + (rect.left - center.dx) * scale,
    center.dy + (rect.top - center.dy) * scale,
    center.dx + (rect.right - center.dx) * scale,
    center.dy + (rect.bottom - center.dy) * scale,
  );
}

Rect recededRect(Rect rect, Size size, double covered) =>
    _scaleTowardCenter(rect, size, 1 - _recededShrinkOf(size) * covered);

Rect unrecededRect(Rect rect, Size size, double covered) =>
    _scaleTowardCenter(rect, size, 1 / (1 - _recededShrinkOf(size) * covered));

var _measuringAtRest = false;

T measureAtRest<T>(T Function() measure) {
  final measuring = _measuringAtRest;
  _measuringAtRest = true;
  try {
    return measure();
  } finally {
    _measuringAtRest = measuring;
  }
}

bool get isMeasuringAtRest => _measuringAtRest;

/// How a route moves its page's bar items: [lifted] out of a snapshot of the
/// page, [moving] while the page moves under a bar that holds still.
typedef BarItemsMotion = ({
  bool lifted,
  bool moving,
  bool shown,
  double? tracking,
});

/// The display's corners where the platform reports them, which Android does
/// from API 31; elsewhere a moving page stays square.
BorderRadius displayRadiusOf(BuildContext context) =>
    MediaQuery.displayCornerRadiiOf(context) ?? BorderRadius.zero;

/// The [ModalRoute.delegatedTransition] of every card route. Sharing it keeps
/// Flutter from wrapping one's page in another's transition, which would move
/// the page to a new parent and rebuild all of it; any other route under a
/// card route stays still.
Widget? _cardRouteMotion(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  bool allowSnapshotting,
  Widget? child,
) => null;

/// iOS 27's navigation push.
mixin CardRouteMixin<T> on ModalRoute<T> {
  BorderRadius cardRadiusOf(BuildContext context) => displayRadiusOf(context);

  Color settledFillOf(Color surface) => surface;

  @protected
  SpringDescription get openSpring => _pushSpring;

  @protected
  SpringDescription get closeSpring => _pushSpring;

  /// The speed a spring from rest sets off at, as a multiple of its distance
  /// a second.
  @protected
  double get openLaunchSpeed => _pushSpeed;

  @protected
  double get closeLaunchSpeed => _pushSpeed;

  /// Whether this route shrinks the page it covers, as iOS's zoom does,
  /// rather than sliding it back.
  @protected
  bool get recedesCovered => false;

  final _coveredByZoom = ValueNotifier(false);
  final _coveredByOpaque = ValueNotifier(false);

  final _barItems = ValueNotifier<BarItemsMotion>((
    lifted: false,
    moving: false,
    shown: true,
    tracking: null,
  ));

  ValueListenable<BarItemsMotion> get barItems => _barItems;

  CardRouteMixin<dynamic>? _next;

  final _coveringOverdrag = ValueNotifier(0.0);
  ValueListenable<double>? _nextOverdrag;
  Animation<double>? _nextSecondary;
  ValueListenable<bool>? _userGesture;

  void _copyOverdrag() => _coveringOverdrag.value = _nextOverdrag?.value ?? 0;

  void _syncCoveredByOpaque() {
    final next = _next;
    _coveredByOpaque.value =
        next != null &&
        next.opaque &&
        !next.recedesCovered &&
        (_nextSecondary?.isDismissed ?? true);
  }

  void _handleNextSecondaryStatus(AnimationStatus _) => _syncCoveredByOpaque();

  bool get _isDragBackActive => switch (this) {
    final DragBackRouteMixin<T> route => route.isDragBackActive,
    _ => false,
  };

  ValueListenable<double> get _overdrag => switch (this) {
    final DragBackRouteMixin<T> route => route.dragBackOverdrag,
    _ => const AlwaysStoppedAnimation(0.0),
  };

  /// How far a drag back of this route shows the bar items under it.
  @protected
  double? get barItemsUncovering => null;

  /// Whether [animation]'s card has moved in and not yet moved back out.
  @protected
  bool hasCome(Animation<double> animation) => switch (animation.status) {
    AnimationStatus.forward => animation.value > 0,
    AnimationStatus.reverse => animation.value == 1,
    AnimationStatus.completed => true,
    AnimationStatus.dismissed => false,
  };

  /// iOS's bar items hold still while a push moves the pages under them.
  @protected
  BarItemsMotion computeBarItems() {
    final secondary = secondaryAnimation!;
    if (_coveredByZoom.value && !secondary.isDismissed) {
      return (
        lifted: true,
        moving: true,
        shown: !hasCome(secondary),
        tracking: _next?.barItemsUncovering,
      );
    }
    final animation = this.animation!;
    return (
      lifted: false,
      moving:
          animation.isAnimating ||
          secondary.isAnimating ||
          (!recedesCovered && _isDragBackActive),
      shown: hasCome(animation) && !hasCome(secondary),
      tracking: null,
    );
  }

  @protected
  void updateBarItems() => _barItems.value = computeBarItems();

  // Impeller redraws a moving page in full each frame.
  final _motionSnapshot = SnapshotController();
  Animation<double>? _sheetCover;
  var _glass = false;

  // Only a page going out of view is drawn from its snapshot. One coming into
  // view stays live, as a frozen picture of it would show what it held when
  // last covered, such as a press still fading out, until it settles.
  void _updateMotionSnapshot() {
    final animation = this.animation!;
    final secondary = secondaryAnimation!;
    final dragged = navigator?.userGestureInProgress ?? false;
    // Under a moving sheet the page holds still behind the scrim, while glass
    // would sample a picture of it.
    final underMovingSheet =
        !_glass && (_sheetCover?.status.isAnimating ?? false);
    _motionSnapshot.allowSnapshotting =
        underMovingSheet ||
        (_coveredByZoom.value
            ? animation.isCompleted && secondary.isAnimating
            : (secondary.status == AnimationStatus.forward && !dragged) ||
                  (!recedesCovered &&
                      ((animation.status.isAnimating &&
                              (animation.status == AnimationStatus.reverse ||
                                  dragged)) ||
                          _isDragBackActive)));
  }

  void retakeSnapshot() {
    if (!_motionSnapshot.allowSnapshotting) {
      return;
    }
    _motionSnapshot.allowSnapshotting = false;
    _updateMotionSnapshot();
  }

  void _handleStatus(AnimationStatus _) {
    updateBarItems();
    _updateMotionSnapshot();
  }

  void _handleSheetCoverStatus(AnimationStatus _) => _updateMotionSnapshot();

  void _handleUserGesture() {
    updateBarItems();
    _updateMotionSnapshot();
  }

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      _settlingTimeOf(openSpring, openLaunchSpeed);

  @override
  Duration get reverseTransitionDuration =>
      _settlingTimeOf(closeSpring, closeLaunchSpeed);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _cardRouteMotion;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is CardRouteMixin;

  // The navigator announces a route pushed over this one while it pops.
  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    final next = isActive ? nextRoute : null;
    _next = next is CardRouteMixin ? next : null;
    _nextOverdrag?.removeListener(_copyOverdrag);
    _nextOverdrag = switch (next) {
      final DragBackRouteMixin<dynamic> route => route.dragBackOverdrag,
      _ => null,
    };
    _nextOverdrag?.addListener(_copyOverdrag);
    _copyOverdrag();
    _nextSecondary?.removeStatusListener(_handleNextSecondaryStatus);
    _nextSecondary = _next?.secondaryAnimation;
    _nextSecondary?.addStatusListener(_handleNextSecondaryStatus);
    if (next is CardRouteMixin) {
      _coveredByZoom.value = next.recedesCovered;
    }
    _syncCoveredByOpaque();
    super.didChangeNext(next);
    retakeSnapshot();
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    retakeSnapshot();
  }

  @override
  void install() {
    super.install();
    animation!
      ..addListener(updateBarItems)
      ..addStatusListener(_handleStatus);
    secondaryAnimation!
      ..addListener(updateBarItems)
      ..addStatusListener(_handleStatus);
    _coveredByZoom
      ..addListener(_updateMotionSnapshot)
      ..addListener(updateBarItems);
    _userGesture = navigator?.userGestureInProgressNotifier
      ?..addListener(_handleUserGesture);
    _sheetCover = sheetCoverOfRoute(this)
      ..addStatusListener(_handleSheetCoverStatus);
  }

  @override
  void dispose() {
    animation!
      ..removeListener(updateBarItems)
      ..removeStatusListener(_handleStatus);
    secondaryAnimation!
      ..removeListener(updateBarItems)
      ..removeStatusListener(_handleStatus);
    _userGesture?.removeListener(_handleUserGesture);
    _sheetCover?.removeStatusListener(_handleSheetCoverStatus);
    _nextOverdrag?.removeListener(_copyOverdrag);
    _nextSecondary?.removeStatusListener(_handleNextSecondaryStatus);
    _coveringOverdrag.dispose();
    _coveredByZoom.dispose();
    _coveredByOpaque.dispose();
    _barItems.dispose();
    _motionSnapshot.dispose();
    super.dispose();
  }

  Widget _snapshotWhileMoving(BuildContext context, Widget child) {
    _glass = LiquidGlassScope.of(context);
    _updateMotionSnapshot();
    // The snapshot has no host over it, so one within takes the page's panes
    // for it, and they come out as glass rather than a flat tint.
    return SnapshotWidget(
      controller: _motionSnapshot,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: LiquidGlassHost(
        enabled: LiquidGlassScope.of(context),
        child: child,
      ),
    );
  }

  @protected
  TickerFuture settleTo(double target, {double? velocity}) {
    final controller = this.controller!;
    final from = controller.value;
    final opens = target == 1;
    final simulation = SpringSimulation(
      opens ? openSpring : closeSpring,
      from,
      target,
      velocity ??
          (target - from) * (opens ? openLaunchSpeed : closeLaunchSpeed),
      tolerance: _settleTolerance,
      snapToEnd: true,
    );
    final settle = ArrivingSimulation(simulation, end: target);
    return opens
        ? controller.animateWith(settle)
        : controller.animateBackWith(settle);
  }

  @override
  TickerFuture didPush() {
    super.didPush();
    return settleTo(1);
  }

  @override
  bool didPop(T? result) {
    final controller = this.controller!;
    final velocity = controller.isAnimating ? controller.velocity : null;
    final popped = super.didPop(result);
    // A pop that only drops a local history entry, such as a search layer,
    // leaves the route in place.
    if (!popped) {
      return false;
    }
    // A drag back lets go with its own spring.
    if (this case DragBackRouteMixin<T>(isDragBackActive: true)) {
      return popped;
    }
    if (!controller.isDismissed) {
      settleTo(0, velocity: velocity);
    }
    return popped;
  }

  @protected
  Widget coveredTransition(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _CardTransition(
      animation: kAlwaysCompleteAnimation,
      secondaryAnimation: secondaryAnimation,
      overdrag: const AlwaysStoppedAnimation(0.0),
      coveringOverdrag: _coveringOverdrag,
      radius: cardRadiusOf(context),
      settledFill: Colors.transparent,
      receding: _coveredByZoom,
      coveredByOpaque: _coveredByOpaque,
      glass: LiquidGlassScope.of(context),
      child: _snapshotWhileMoving(context, child),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = _CardTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      overdrag: _overdrag,
      coveringOverdrag: _coveringOverdrag,
      radius: cardRadiusOf(context),
      settledFill: settledFillOf(
        SurfaceLevel.page.colorOf(ColorScheme.of(context)),
      ),
      receding: _coveredByZoom,
      coveredByOpaque: _coveredByOpaque,
      glass: LiquidGlassScope.of(context),
      child: _snapshotWhileMoving(context, child),
    );
    return switch (this) {
      final DragBackRouteMixin<T> route => route.dragBackDetector(transition),
      _ => transition,
    };
  }
}

class HomeRoute<T> extends PageRoute<T> with CardRouteMixin<T> {
  HomeRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Color settledFillOf(Color surface) => Colors.transparent;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: scopePageRoute(this, builder(context)),
    );
  }
}

// Continuous superellipse curves leave the straight edge within ~1.85 radii.
const _superellipseReach = 1.85;
// Extra width past the covering edge for glass blur kernels on covered pages.
const _glassBlurMargin = 56.0;

/// Moves the page by painting alone, so it is neither rebuilt nor laid out
/// again while it moves.
class _CardTransition extends SingleChildRenderObjectWidget {
  const _CardTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.overdrag,
    required this.coveringOverdrag,
    required this.radius,
    required this.settledFill,
    required this.receding,
    required this.coveredByOpaque,
    required this.glass,
    super.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  /// How far a drag has pulled the page, and the page over it, past rest.
  final ValueListenable<double> overdrag;
  final ValueListenable<double> coveringOverdrag;
  final BorderRadius radius;
  final Color settledFill;
  final ValueListenable<bool> receding;
  final ValueListenable<bool> coveredByOpaque;
  final bool glass;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return _RenderCardTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      overdrag: overdrag,
      coveringOverdrag: coveringOverdrag,
      radius: radius,
      settledFill: settledFill,
      receding: receding,
      coveredByOpaque: coveredByOpaque,
      glass: glass,
      surface: SurfaceLevel.page.colorOf(colorScheme),
      backdrop: colorScheme.surfaceContainerLowest,
      shadow: colorScheme.brightness == Brightness.light,
      textDirection: Directionality.of(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCardTransition renderObject,
  ) {
    final colorScheme = ColorScheme.of(context);
    renderObject
      ..animation = animation
      ..secondaryAnimation = secondaryAnimation
      ..overdrag = overdrag
      ..coveringOverdrag = coveringOverdrag
      ..radius = radius
      ..settledFill = settledFill
      ..receding = receding
      ..coveredByOpaque = coveredByOpaque
      ..glass = glass
      ..surface = SurfaceLevel.page.colorOf(colorScheme)
      ..backdrop = colorScheme.surfaceContainerLowest
      ..shadow = colorScheme.brightness == Brightness.light
      ..textDirection = Directionality.of(context)
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderCardTransition extends RenderProxyBox {
  _RenderCardTransition({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required ValueListenable<double> overdrag,
    required ValueListenable<double> coveringOverdrag,
    required BorderRadius radius,
    required Color settledFill,
    required ValueListenable<bool> receding,
    required ValueListenable<bool> coveredByOpaque,
    required bool glass,
    required Color surface,
    required Color backdrop,
    required bool shadow,
    required TextDirection textDirection,
    required double devicePixelRatio,
  }) : _animation = animation,
       _secondaryAnimation = secondaryAnimation,
       _overdrag = overdrag,
       _coveringOverdrag = coveringOverdrag,
       _radius = radius,
       _settledFill = settledFill,
       _receding = receding,
       _coveredByOpaque = coveredByOpaque,
       _glass = glass,
       _surface = surface,
       _backdrop = backdrop,
       _shadow = shadow,
       _textDirection = textDirection,
       _devicePixelRatio = devicePixelRatio;

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) {
      return;
    }
    if (attached) {
      _unlisten();
    }
    _animation = value;
    if (attached) {
      _listen();
    }
    markNeedsPaint();
  }

  Animation<double> _secondaryAnimation;
  set secondaryAnimation(Animation<double> value) {
    if (identical(value, _secondaryAnimation)) {
      return;
    }
    if (attached) {
      _unlisten();
    }
    _secondaryAnimation = value;
    if (attached) {
      _listen();
    }
    markNeedsPaint();
  }

  ValueListenable<double> _overdrag;
  set overdrag(ValueListenable<double> value) {
    if (identical(value, _overdrag)) {
      return;
    }
    if (attached) {
      _overdrag.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _overdrag = value;
    markNeedsPaint();
  }

  ValueListenable<double> _coveringOverdrag;
  set coveringOverdrag(ValueListenable<double> value) {
    if (identical(value, _coveringOverdrag)) {
      return;
    }
    if (attached) {
      _coveringOverdrag.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _coveringOverdrag = value;
    markNeedsPaint();
  }

  BorderRadius _radius;
  set radius(BorderRadius value) {
    if (value == _radius) {
      return;
    }
    _radius = value;
    markNeedsPaint();
  }

  Color _settledFill;
  set settledFill(Color value) {
    if (value == _settledFill) {
      return;
    }
    _settledFill = value;
    markNeedsPaint();
  }

  ValueListenable<bool> _receding;
  set receding(ValueListenable<bool> value) {
    if (identical(value, _receding)) {
      return;
    }
    if (attached) {
      _receding.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _receding = value;
    markNeedsPaint();
  }

  ValueListenable<bool> _coveredByOpaque;
  set coveredByOpaque(ValueListenable<bool> value) {
    if (identical(value, _coveredByOpaque)) {
      return;
    }
    if (attached) {
      _coveredByOpaque.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _coveredByOpaque = value;
    markNeedsPaint();
  }

  bool _glass;
  set glass(bool value) {
    if (value == _glass) {
      return;
    }
    _glass = value;
    markNeedsPaint();
  }

  Color _surface;
  set surface(Color value) {
    if (value == _surface) {
      return;
    }
    _surface = value;
    markNeedsPaint();
  }

  Color _backdrop;
  set backdrop(Color value) {
    if (value == _backdrop) {
      return;
    }
    _backdrop = value;
    markNeedsPaint();
  }

  bool _shadow;
  set shadow(bool value) {
    if (value == _shadow) {
      return;
    }
    _shadow = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) {
      return;
    }
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  final _visibleClipLayer = LayerHandle<ClipRectLayer>();
  final _clipLayer = LayerHandle<ClipRSuperellipseLayer>();
  final _transformLayer = LayerHandle<TransformLayer>();

  bool get _moving =>
      !_animation.isCompleted || !_secondaryAnimation.isDismissed;

  bool get _recedes => _receding.value;

  double get _covered => _secondaryAnimation.value + _coveringOverdrag.value;

  double get _dx {
    final width = size.width;
    final slide = _recedes ? 0.0 : _coveredSlide * width * _covered;
    final dx = (1 - _animation.value - _overdrag.value) * width - slide;
    // On whole physical pixels a snapshot is drawn as sharp as the page.
    final snapped =
        (dx * _devicePixelRatio).roundToDouble() / _devicePixelRatio;
    return _textDirection == TextDirection.rtl ? -snapped : snapped;
  }

  Rect get _card {
    final page = Offset.zero & size;
    final card = _recedes
        ? recededRect(page, size, _secondaryAnimation.value)
        : page;
    return card.shift(Offset(_dx, 0));
  }

  Matrix4 _childTransform(Rect card) {
    final scale = card.width / size.width;
    return Matrix4.translationValues(card.left, card.top, 0)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _handleStatus(AnimationStatus _) => markNeedsSemanticsUpdate();

  void _listen() {
    for (final animation in [_animation, _secondaryAnimation]) {
      animation
        ..addListener(markNeedsPaint)
        ..addStatusListener(_handleStatus);
    }
    _receding.addListener(markNeedsPaint);
    _coveredByOpaque.addListener(markNeedsPaint);
    _overdrag.addListener(markNeedsPaint);
    _coveringOverdrag.addListener(markNeedsPaint);
  }

  void _unlisten() {
    for (final animation in [_animation, _secondaryAnimation]) {
      animation
        ..removeListener(markNeedsPaint)
        ..removeStatusListener(_handleStatus);
    }
    _receding.removeListener(markNeedsPaint);
    _coveredByOpaque.removeListener(markNeedsPaint);
    _overdrag.removeListener(markNeedsPaint);
    _coveringOverdrag.removeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _visibleClipLayer.layer = null;
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  ({Rect strip, List<Rect> trailingCorners})? _uncoveredRegions(
    double covered,
    Rect card,
  ) {
    if (!_coveredByOpaque.value ||
        _recedes ||
        !_animation.isCompleted ||
        covered <= 0 ||
        covered >= 1 ||
        size.isEmpty) {
      return null;
    }
    final coverSpan =
        ((1 - covered) * size.width * _devicePixelRatio).roundToDouble() /
        _devicePixelRatio;
    if (coverSpan <= 0) {
      return null;
    }
    final rtl = _textDirection == TextDirection.rtl;
    final leadingCorner = rtl
        ? math.max(_radius.topRight.x, _radius.bottomRight.x)
        : math.max(_radius.topLeft.x, _radius.bottomLeft.x);
    final trailingTop = rtl ? _radius.topLeft : _radius.topRight;
    final trailingBottom = rtl ? _radius.bottomLeft : _radius.bottomRight;
    final trailingCorner = math.max(trailingTop.x, trailingBottom.x);
    final leadingReach =
        math.min(size.width / 2, leadingCorner * _superellipseReach) +
        (_glass ? _glassBlurMargin : 1.0);
    final trailingReach = trailingCorner > 0
        ? math.min(size.width / 2, trailingCorner * _superellipseReach) + 1.0
        : 0.0;

    List<Rect> cornersIn(double left, double right) {
      final topH = math.min(
        size.height / 2,
        trailingTop.y * _superellipseReach + 1,
      );
      final botH = math.min(
        size.height / 2,
        trailingBottom.y * _superellipseReach + 1,
      );
      return [
        if (trailingTop.x > 0 && trailingTop.y > 0)
          Rect.fromLTRB(left, 0, right, topH),
        if (trailingBottom.x > 0 && trailingBottom.y > 0)
          Rect.fromLTRB(left, size.height - botH, right, size.height),
      ];
    }

    if (rtl) {
      final left = size.width - coverSpan - leadingReach;
      if (left <= 0) {
        return null;
      }
      final trailingEnd = trailingReach - coverSpan;
      if (trailingEnd > 0 && card.left < trailingEnd) {
        return null;
      }
      return (
        strip: Rect.fromLTRB(
          math.min(size.width, left),
          0,
          size.width,
          size.height,
        ),
        trailingCorners: trailingEnd > 0 ? cornersIn(0, trailingEnd) : const [],
      );
    }

    final right = coverSpan + leadingReach;
    if (right >= size.width) {
      return null;
    }
    final trailingStart = size.width + coverSpan - trailingReach;
    if (trailingStart < size.width && card.right > trailingStart) {
      return null;
    }
    return (
      strip: Rect.fromLTRB(0, 0, math.max(0.0, right), size.height),
      trailingCorners: trailingStart < size.width
          ? cornersIn(trailingStart, size.width)
          : const [],
    );
  }

  bool _insideCardInterior(Rect rect, Rect card) {
    final leftInset = math.min(
      card.width / 2,
      math.max(_radius.topLeft.x, _radius.bottomLeft.x) * _superellipseReach,
    );
    final rightInset = math.min(
      card.width / 2,
      math.max(_radius.topRight.x, _radius.bottomRight.x) * _superellipseReach,
    );
    return rect.left >= card.left + leftInset &&
        rect.right <= card.right - rightInset &&
        rect.top >= card.top &&
        rect.bottom <= card.bottom;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      return;
    }
    if (!_moving) {
      _visibleClipLayer.layer = null;
      _clipLayer.layer = null;
      _transformLayer.layer = null;
      if (_settledFill.a > 0) {
        context.canvas.drawRect(offset & size, Paint()..color = _settledFill);
      }
      context.paintChild(child, offset);
      return;
    }
    final covered = _covered;
    final recedes = _recedes;
    final card = _card;
    final uncovered = _uncoveredRegions(covered, card);
    final visible = uncovered?.strip;
    final insideInterior =
        visible != null && _insideCardInterior(visible, card);

    void paintTransition(PaintingContext context, Offset offset) {
      // A card leaving while still covered, as in a second pop before the first
      // has ended, has the page below it beside it, not the empty backdrop.
      if (covered > 0 && _animation.isCompleted && !insideInterior) {
        final screen = offset & size;
        if (recedes) {
          context.canvas.drawRect(screen, Paint()..color = _surface);
        } else {
          _paintBesideCard(context.canvas, screen, card.shift(offset));
        }
      }
      if (_shadow && !_animation.isCompleted) {
        _paintShadow(context.canvas, card.shift(offset));
      }
      void paintCard(PaintingContext context, Offset offset) {
        context.canvas.drawRect(card.shift(offset), Paint()..color = _surface);
        if (card.width == size.width) {
          _transformLayer.layer = null;
          context.paintChild(child, offset + card.topLeft);
          return;
        }
        _transformLayer.layer = context.pushTransform(
          needsCompositing,
          offset,
          _childTransform(card),
          (context, offset) => context.paintChild(child, offset),
          oldLayer: _transformLayer.layer,
        );
      }

      // iOS shrinks the content of a page under a zoom but keeps its
      // background, so a receding page has no corners of its own.
      if (_radius == BorderRadius.zero ||
          (recedes && _animation.isCompleted) ||
          insideInterior) {
        _clipLayer.layer = null;
        paintCard(context, offset);
      } else {
        _clipLayer.layer = context.pushClipRSuperellipse(
          needsCompositing,
          offset,
          card,
          _radius.toRSuperellipse(card),
          paintCard,
          oldLayer: _clipLayer.layer,
        );
      }
      if (covered > 0) {
        final dim = recedes ? _recededDim : _coveredDim;
        context.canvas.drawRect(
          (visible ?? (Offset.zero & size)).shift(offset),
          Paint()..color = dim.withValues(alpha: dim.a * math.min(covered, 1)),
        );
      }
    }

    if (uncovered != null) {
      final trailingCorners = uncovered.trailingCorners;
      if (trailingCorners.isNotEmpty) {
        final dim = _coveredDim.withValues(
          alpha: _coveredDim.a * math.min(covered, 1),
        );
        final fill = Paint()..color = Color.alphaBlend(dim, _backdrop);
        for (final corner in trailingCorners) {
          context.canvas.drawRect(corner.shift(offset), fill);
        }
      }
      _visibleClipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        uncovered.strip,
        paintTransition,
        clipBehavior: Clip.hardEdge,
        oldLayer: _visibleClipLayer.layer,
      );
      return;
    }
    _visibleClipLayer.layer = null;
    paintTransition(context, offset);
  }

  void _paintShadow(Canvas canvas, Rect card) {
    final rtl = _textDirection == TextDirection.rtl;
    final edge = rtl ? card.right : card.left;
    final end = edge + (rtl ? 3 : -3) * _cardShadowSigma;
    final top = card.top + (rtl ? _radius.topRight.y : _radius.topLeft.y);
    final bottom =
        card.bottom - (rtl ? _radius.bottomRight.y : _radius.bottomLeft.y);
    if (bottom <= top) {
      return;
    }
    canvas.drawRect(
      Rect.fromLTRB(math.min(edge, end), top, math.max(edge, end), bottom),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(edge, 0),
          Offset(end, 0),
          _cardShadowColors,
          _cardShadowStops,
        ),
    );
  }

  /// Only the uncovered strip and corners take the backdrop; each piece reaches
  /// a pixel under the card so its antialiased edge stays off the root.
  void _paintBesideCard(Canvas canvas, Rect screen, Rect card) {
    final paint = Paint()..color = _backdrop;
    final radius = _radius;
    for (final rect in [
      Rect.fromLTRB(screen.left, screen.top, card.left + 1, screen.bottom),
      Rect.fromLTRB(card.right - 1, screen.top, screen.right, screen.bottom),
      Rect.fromLTWH(
        card.left,
        card.top,
        radius.topLeft.x + 1,
        radius.topLeft.y + 1,
      ),
      Rect.fromLTRB(
        card.right - radius.topRight.x - 1,
        card.top,
        card.right,
        card.top + radius.topRight.y + 1,
      ),
      Rect.fromLTRB(
        card.left,
        card.bottom - radius.bottomLeft.y - 1,
        card.left + radius.bottomLeft.x + 1,
        card.bottom,
      ),
      Rect.fromLTRB(
        card.right - radius.bottomRight.x - 1,
        card.bottom - radius.bottomRight.y - 1,
        card.right,
        card.bottom,
      ),
    ]) {
      final visible = rect.intersect(screen);
      if (!visible.isEmpty) {
        canvas.drawRect(visible, paint);
      }
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_moving && !_measuringAtRest) {
      transform.multiply(_childTransform(_card));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: _moving ? _childTransform(_card) : null,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
