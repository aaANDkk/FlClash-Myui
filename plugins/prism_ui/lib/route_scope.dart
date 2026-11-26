import 'package:flutter/widgets.dart';

/// Marks [page] as built by [route], for [routeOf].
Widget scopePageRoute(ModalRoute<Object?> route, Widget page) =>
    _PageRouteScope(route: route, child: page);

/// The route of the page [context] is on, as [ModalRoute.of] finds it. Under a
/// route that marks its page with [scopePageRoute], [context] depends on which
/// route that is alone: [ModalRoute.of] also rebuilds it whenever the route is
/// covered or uncovered.
ModalRoute<Object?>? routeOf(BuildContext context) {
  final scoped = context
      .dependOnInheritedWidgetOfExactType<_PageRouteScope>()
      ?.route;
  if (scoped != null &&
      identical(scoped.navigator, Navigator.maybeOf(context))) {
    return scoped;
  }
  return ModalRoute.of(context);
}

class _PageRouteScope extends InheritedWidget {
  const _PageRouteScope({required this.route, required super.child});

  final ModalRoute<Object?> route;

  @override
  bool updateShouldNotify(_PageRouteScope oldWidget) =>
      !identical(route, oldWidget.route);
}
