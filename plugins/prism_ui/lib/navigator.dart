import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/deferred_push.dart';
import 'package:prism_ui/drag_back.dart';
import 'package:prism_ui/keyboard_inset_hold.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:prism_ui/page_transition.dart';
import 'package:prism_ui/route_scope.dart';
import 'package:prism_ui/sheet_navigator.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class BaseNavigator {
  static PageRoute<T> _routeOf<T>(BuildContext context, Widget child) {
    if (!context.isMobileView) {
      return FadePageRoute(builder: (context) => child);
    }
    return CardPageRoute(builder: (context) => child);
  }

  /// The mobile layout drops a home page's navigator, pages and all, so a
  /// desktop page left open reopens in the mobile form while its opener stays.
  static Future<T?> push<T>(BuildContext context, Widget child) {
    final navigator = Navigator.of(context);
    if (context.isMobileView) {
      return navigator.push<T>(_routeOf(context, child));
    }
    final completer = Completer<T?>();
    var popped = false;
    void reopenIfDropped() {
      if (popped) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        completer.complete(context.mounted ? push<T>(context, child) : null);
      });
    }

    final route = FadePageRoute<T>(
      builder: (_) => _DropWatch(onDropped: reopenIfDropped, child: child),
    );
    unawaited(
      navigator.push<T>(route).then((value) {
        popped = true;
        completer.complete(value);
      }),
    );
    return completer.future;
  }
}

class _DropWatch extends StatefulWidget {
  const _DropWatch({required this.onDropped, required this.child});

  final VoidCallback onDropped;
  final Widget child;

  @override
  State<_DropWatch> createState() => _DropWatchState();
}

class _DropWatchState extends State<_DropWatch> {
  @override
  void dispose() {
    widget.onDropped();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The route of the page [context] is on and, for a page in a sheet, the
/// routes of the sheets carrying it.
Iterable<ModalRoute<Object?>> routesCarrying(BuildContext context) sync* {
  var route = routeOf(context);
  while (route != null) {
    yield route;
    final navigator = route.navigator;
    if (navigator == null ||
        !navigator.mounted ||
        navigator.widget is! SheetPagesNavigator) {
      return;
    }
    route = routeOf(navigator.context);
  }
}

Future<void> whenRouteSettled(BuildContext context) async {
  final routes = routesCarrying(context).toList();
  for (final route in routes) {
    await _whenSettled(route);
  }
}

bool isRouteArriving(BuildContext context) => routesCarrying(
  context,
).any((route) => route.offstage || (route.animation?.isAnimating ?? false));

/// Completes once the route [context] is on stops moving under the route
/// above it, as while that route still leaves after its pop.
Future<void> whenRouteUncovered(BuildContext context) async {
  final animation = ModalRoute.of(context)?.secondaryAnimation;
  if (animation != null) {
    await _whenStill(animation);
  }
}

Future<void> _whenSettled(ModalRoute<Object?> route) async {
  // HeroController builds a pushed route offstage for its first frame, with
  // the animation pinned to completed, so it only tells the truth after that.
  while (route.offstage && route.isActive) {
    await SchedulerBinding.instance.endOfFrame;
  }
  final animation = route.animation;
  if (animation != null) {
    await _whenStill(animation);
  }
}

Future<void> _whenStill(Animation<double> animation) {
  if (!animation.isAnimating) {
    return Future.value();
  }
  final completer = Completer<void>();
  void handleStatus(AnimationStatus status) {
    if (status.isAnimating) {
      return;
    }
    animation.removeStatusListener(handleStatus);
    completer.complete();
  }

  animation.addStatusListener(handleStatus);
  return completer.future;
}

/// A navigator's first page: it never animates itself, and a card route pushed
/// over it drives how it recedes through its delegated transition.
class RootPage<T> extends Page<T> {
  final Widget child;

  const RootPage({required this.child, super.key, super.name});

  @override
  Route<T> createRoute(BuildContext context) => _RootPageRoute<T>(page: this);
}

class _RootPageRoute<T> extends PageRoute<T> {
  _RootPageRoute({required RootPage<T> page}) : super(settings: page);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is ModalRoute<dynamic> &&
      nextRoute.delegatedTransition != null &&
      (nextRoute is! PageRoute<dynamic> || !nextRoute.fullscreenDialog);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _StillUnderSheet(
        cover: sheetCoverOfRoute(this),
        child: scopePageRoute(this, (settings as RootPage<T>).child),
      ),
    );
  }
}

/// A card route's snapshot under a moving sheet, for a page that has none.
class _StillUnderSheet extends StatefulWidget {
  const _StillUnderSheet({required this.cover, required this.child});

  final Animation<double> cover;
  final Widget child;

  @override
  State<_StillUnderSheet> createState() => _StillUnderSheetState();
}

class _StillUnderSheetState extends State<_StillUnderSheet> {
  final _snapshot = SnapshotController();
  var _glass = false;

  @override
  void initState() {
    super.initState();
    widget.cover.addStatusListener(_update);
  }

  @override
  void didUpdateWidget(_StillUnderSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover) {
      oldWidget.cover.removeStatusListener(_update);
      widget.cover.addStatusListener(_update);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _glass = LiquidGlassScope.of(context);
  }

  void _update(AnimationStatus status) {
    _snapshot.allowSnapshotting = !_glass && status.isAnimating;
  }

  @override
  void dispose() {
    widget.cover.removeStatusListener(_update);
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _update(widget.cover.status);
    return SnapshotWidget(
      controller: _snapshot,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: widget.child,
    );
  }
}

class FadePageRoute<T> extends PageRoute<T>
    with DragBackRouteMixin<T>, DeferredPushRouteMixin<T> {
  final Widget Function(BuildContext context) builder;

  FadePageRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: KeyboardInsetHold(child: scopePageRoute(this, builder(context))),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return dragBackDetector(
      isDragBackActive
          ? dragBackSlide(context, animation, child)
          : FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
}

class CardPageRoute<T> extends PageRoute<T>
    with DragBackRouteMixin<T>, DeferredPushRouteMixin<T>, CardRouteMixin<T> {
  final Widget Function(BuildContext context) builder;

  CardPageRoute({required this.builder, super.settings});

  // HeroController would hold the first frame offstage. Painted at rest off
  // screen instead, the page takes its costly first paint and snapshots there
  // rather than in the first frames it moves in.
  @override
  set offstage(bool value) {}

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: KeyboardInsetHold(child: scopePageRoute(this, builder(context))),
    );
  }
}
