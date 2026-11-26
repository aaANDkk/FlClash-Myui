import 'package:flutter/widgets.dart';
import 'package:prism_ui/typography.dart';

enum ListTextScale {
  regular(
    title: AppTextStyle.body,
    subtitle: AppTextStyle.subheadline,
    header: AppTextStyle.headline,
  ),
  compact(
    title: AppTextStyle.subheadline,
    subtitle: AppTextStyle.footnote,
    header: AppTextStyle.subheadline,
  );

  const ListTextScale({
    required this.title,
    required this.subtitle,
    required this.header,
  });

  final AppTextStyle title;
  final AppTextStyle subtitle;
  final AppTextStyle header;
}

class ListTextScope extends InheritedWidget {
  const ListTextScope({super.key, required this.scale, required super.child});

  final ListTextScale scale;

  static ListTextScale of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListTextScope>()?.scale ??
      ListTextScale.regular;

  @override
  bool updateShouldNotify(ListTextScope oldWidget) => scale != oldWidget.scale;
}
