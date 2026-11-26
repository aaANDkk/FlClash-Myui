import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/navigator.dart';
import 'package:prism_ui/sheet_navigator.dart';
import 'package:prism_ui/route_scope.dart';

class _RouteMotion {
  _RouteMotion(BuildContext context)
    : _animations = [
        for (final route in routesCarrying(context)) ...[
          ?route.animation,
          ?route.secondaryAnimation,
        ],
        sheetCoverOf(context),
      ],
      _gestures = [
        for (final route in routesCarrying(context))
          ?route.navigator?.userGestureInProgressNotifier,
      ];

  final List<Animation<double>> _animations;
  final List<ValueListenable<bool>> _gestures;

  bool get isMoving =>
      _animations.any((animation) => animation.isAnimating) ||
      _gestures.any((gesture) => gesture.value);

  bool get isUnderway =>
      _animations.any(
        (animation) => animation.isAnimating && animation.value > 0,
      ) ||
      _gestures.any((gesture) => gesture.value);

  void addListener(AnimationStatusListener onStatus, VoidCallback onGesture) {
    for (final animation in _animations) {
      animation.addStatusListener(onStatus);
    }
    for (final gesture in _gestures) {
      gesture.addListener(onGesture);
    }
  }

  void removeListener(
    AnimationStatusListener onStatus,
    VoidCallback onGesture,
  ) {
    for (final animation in _animations) {
      animation.removeStatusListener(onStatus);
    }
    for (final gesture in _gestures) {
      gesture.removeListener(onGesture);
    }
  }
}

/// Whether a route transition or a drag moves this page or covers it.
bool isRouteMoving(BuildContext context) => _RouteMotion(context).isMoving;

/// Holds list refreshes while the page's route is pushed, popped, covered,
/// uncovered or dragged back, and replays the latest one once it settles.
mixin RouteMotionHoldMixin<T extends StatefulWidget> on State<T> {
  ModalRoute<Object?>? _route;
  _RouteMotion? _motion;
  VoidCallback? _heldUpdate;
  var _settleRun = 0;
  var _settling = false;

  void updateWhenRouteSettled(VoidCallback update) {
    if (_settling || (_motion?.isMoving ?? false)) {
      _heldUpdate = update;
      return;
    }
    _heldUpdate = null;
    update();
  }

  /// Applies at once while [ArrivalHold] keeps the push at value zero.
  void showFirstContent(VoidCallback update) {
    if (_settling || (_motion?.isUnderway ?? false)) {
      _heldUpdate = update;
      return;
    }
    _heldUpdate = null;
    update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = routeOf(context);
    if (_motion != null && identical(route, _route)) {
      return;
    }
    _detach();
    _route = route;
    _motion = _RouteMotion(context)..addListener(_handleStatus, _releaseHeld);
  }

  @override
  void dispose() {
    _detach();
    _heldUpdate = null;
    super.dispose();
  }

  void _detach() {
    _motion?.removeListener(_handleStatus, _releaseHeld);
    _motion = null;
  }

  void _handleStatus(AnimationStatus _) => _releaseHeld();

  void _releaseHeld() {
    if (!mounted || (_motion?.isMoving ?? false)) {
      return;
    }
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle &&
        scheduler.transientCallbackCount == 0) {
      _applyHeld();
      return;
    }
    unawaited(_settle());
  }

  Future<void> _settle() async {
    final run = ++_settleRun;
    _settling = true;
    // What the route's stop starts ticks only from the next frame on.
    await SchedulerBinding.instance.endOfFrame;
    await whenNothingAnimates();
    if (run != _settleRun || !mounted) {
      return;
    }
    _settling = false;
    if (!(_motion?.isMoving ?? false)) {
      _applyHeld();
    }
  }

  void _applyHeld() {
    _settleRun++;
    _settling = false;
    final update = _heldUpdate;
    if (update == null) {
      return;
    }
    _heldUpdate = null;
    update();
  }
}

/// Calls [didSettleRoute] once the route that brought the page in has settled.
mixin RouteSettledMixin<T extends StatefulWidget> on State<T> {
  var _settleScheduled = false;
  var _routeSettled = false;

  bool get routeSettled => _routeSettled;

  @protected
  void didSettleRoute();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settleScheduled) {
      return;
    }
    _settleScheduled = true;
    unawaited(_settle());
  }

  Future<void> _settle() async {
    await whenRouteSettled(context);
    if (!mounted) {
      return;
    }
    _routeSettled = true;
    didSettleRoute();
  }
}

class ArrivalCacheExtentBuilder extends StatefulWidget {
  const ArrivalCacheExtentBuilder({super.key, required this.builder});

  final Widget Function(ScrollCacheExtent? cacheExtent) builder;

  @override
  State<ArrivalCacheExtentBuilder> createState() =>
      _ArrivalCacheExtentBuilderState();
}

class _ArrivalCacheExtentBuilderState extends State<ArrivalCacheExtentBuilder>
    with ArrivalCacheExtentMixin<ArrivalCacheExtentBuilder> {
  @override
  Widget build(BuildContext context) => widget.builder(arrivalCacheExtent);
}

/// A list's cache extent: none until its route settles, then widened by steps.
mixin ArrivalCacheExtentMixin<T extends StatefulWidget> on State<T> {
  static const _steps = <ScrollCacheExtent?>[
    ScrollCacheExtent.pixels(0),
    ScrollCacheExtent.pixels(120),
    null,
  ];

  var _widenScheduled = false;
  var _step = 0;

  ScrollCacheExtent? get arrivalCacheExtent => _steps[_step];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_widenScheduled) {
      return;
    }
    _widenScheduled = true;
    unawaited(_widen());
  }

  Future<void> _widen() async {
    await whenRouteSettled(context);
    if (!mounted) {
      return;
    }
    await whenNothingAnimates();
    for (var step = 1; step < _steps.length; step++) {
      if (!mounted) {
        return;
      }
      setState(() => _step = step);
      if (step + 1 < _steps.length) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }
  }
}

/// Builds [child] a frame after itself, to split a first screen over frames.
class NextFrame extends StatefulWidget {
  const NextFrame({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  const NextFrame.sliver({super.key, required this.child})
    : placeholder = const SliverToBoxAdapter();

  final Widget child;
  final Widget placeholder;

  @override
  State<NextFrame> createState() => _NextFrameState();
}

class _NextFrameState extends State<NextFrame> {
  var _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _shown = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      _shown ? widget.child : widget.placeholder;
}

const _stillnessLimit = Duration(milliseconds: 500);

/// Gives up after [_stillnessLimit], as a ticker may never stop; [besides]
/// counts the tickers the caller runs itself, such as its spinner's.
Future<void> whenNothingAnimates({int besides = 0}) async {
  final scheduler = SchedulerBinding.instance;
  final waited = Stopwatch()..start();
  while (scheduler.transientCallbackCount > besides &&
      waited.elapsed < _stillnessLimit) {
    await scheduler.endOfFrame;
  }
}
