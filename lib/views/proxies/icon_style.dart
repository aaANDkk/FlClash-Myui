import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/profiles/custom/icon.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesIconStyleView extends ConsumerStatefulWidget {
  const ProxiesIconStyleView({super.key});

  @override
  ConsumerState<ProxiesIconStyleView> createState() =>
      _ProxiesIconStyleViewState();
}

class _ProxiesIconStyleViewState extends ConsumerState<ProxiesIconStyleView> {
  var _selected = <int>{};
  var _sorting = false;
  var _refreshing = false;

  Future<void> _handleRefreshIcons() async {
    if (_refreshing) {
      return;
    }
    final l10n = context.appLocalizations;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _refreshing = true);
    try {
      final confirmed = await dialogs.showMessage(
        context: context,
        title: l10n.refreshGroupIcons,
        message: TextSpan(text: l10n.refreshGroupIconsTip),
        confirmText: l10n.confirm,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await refreshTargetIcons(
        const [],
        reloadSources: () async {
          final sets = await container.read(iconSetsProvider.future);
          final actions = container.read(iconSetsActionProvider.notifier);
          final updatedSets = await Future.wait([
            for (final set in sets)
              if (set.isRemote)
                actions.sync(set, fresh: true).catchError((e) {
                  commonPrint.log('Failed to sync icon set ${set.name}: $e');
                  return set;
                })
              else
                Future.value(set),
          ]);
          final List<IconSet> allSets =
              container.read(iconSetsProvider).value ?? updatedSets;
          return [
            for (final group in container.read(groupsProvider))
              container.read(proxyGroupIconProvider(group.name)),
            for (final rule in container.read(iconRulesProvider)) rule.icon,
            for (final IconSet set in allSets)
              if (set.cover.isNotEmpty) set.cover,
          ];
        },
      );
      if (mounted) {
        dialogs.showBanner(
          l10n.groupIconsRefreshed,
          level: BannerLevel.success,
        );
      }
    } catch (error) {
      commonPrint.log('Failed to refresh group icons: $error');
      if (mounted) {
        dialogs.showBanner(l10n.updateFailed, level: BannerLevel.error);
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _handleStyle(ProxiesIconStyle iconStyle) {
    ref
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(iconStyle: iconStyle));
  }

  void _putRules(List<IconRule> rules) {
    ref.read(iconRulesProvider.notifier).update(rules);
  }

  void _toggleSorting() {
    setState(() {
      _sorting = !_sorting;
    });
  }

  void _handleToggleSelected(int id) {
    setState(() {
      _selected = {..._selected}..addOrRemove(id);
    });
  }

  void _handleSelectAll(Set<int> ids) {
    setState(() {
      _selected = _selected.containsAll(ids) ? {} : ids;
    });
  }

  Future<void> _handleDeleteSelected(Set<int> ids) async {
    final appLocalizations = context.appLocalizations;
    if (ids.isEmpty) {
      return;
    }
    final res = await dialogs.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteMultipTip(appLocalizations.iconRules),
      ),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !mounted) {
      return;
    }
    ref.read(iconRulesProvider.notifier).delAll(ids);
    setState(() {
      _selected = {};
    });
  }

  Future<void> _handleAdd() async {
    final rule = await showFormSheet<IconRule>(
      context: context,
      props: nestedPagedSheetProps,
      builder: (_) => NestedPagedSheet(builder: (_) => const _IconRuleForm()),
    );
    if (rule == null || !mounted) {
      return;
    }
    _putRules([...ref.read(iconRulesProvider), rule]);
  }

  Future<void> _handleEdit(int index) async {
    final rules = ref.read(iconRulesProvider);
    if (index >= rules.length) {
      return;
    }
    final currentRule = rules[index];
    final updatedRule = await showFormSheet<IconRule>(
      context: context,
      props: nestedPagedSheetProps,
      builder: (_) => NestedPagedSheet(
        builder: (_) => _IconRuleForm(
          rule: currentRule,
          onDelete: () => _handleDelete(currentRule),
        ),
      ),
    );
    if (updatedRule == null || !mounted) {
      return;
    }
    final currentRules = ref.read(iconRulesProvider);
    final idx = currentRules.indexWhere((r) => r.id == currentRule.id);
    if (idx != -1) {
      final next = [...currentRules];
      next[idx] = updatedRule;
      _putRules(next);
    }
  }

  Future<bool> _handleDelete(IconRule rule) async {
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.deleteTip(rule.pattern)),
      destructive: true,
      confirmText: appLocalizations.delete,
    );
    if (res != true || !mounted) {
      return false;
    }
    ref.read(iconRulesProvider.notifier).delAll({rule.id});
    setState(() {
      _selected = {..._selected}..remove(rule.id);
    });
    return true;
  }

  void _handleReorder(int oldIndex, int newIndex) {
    ref.read(iconRulesProvider.notifier).order(oldIndex, newIndex);
  }

  List<IconButtonData> _buildActions(Set<int> ids, Set<int> selected) {
    final appLocalizations = context.appLocalizations;
    if (selected.isNotEmpty) {
      return [
        IconButtonData(
          glyph: AppGlyphs.delete,
          tooltip: appLocalizations.delete,
          onPressed: () => _handleDeleteSelected(selected),
        ),
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: appLocalizations.selectAll,
          onPressed: () => _handleSelectAll(ids),
        ),
      ];
    }
    return [
      if (_sorting || ids.length > 1)
        sortModeAction(context, sorting: _sorting, onPressed: _toggleSorting),
      IconButtonData(
        glyph: AppGlyphs.addCircle,
        tooltip: appLocalizations.addIconRule,
        onPressed: _handleAdd,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.iconStyle),
    );
    final rules = ref.watch(iconRulesProvider);
    final ids = {for (final rule in rules) rule.id};
    final selected = _selected.intersection(ids);

    Widget itemAt(int index) {
      final rule = rules[index];
      final position = ItemPosition.get(index, rules.length);
      final isEditing = selected.isNotEmpty;
      final isSelected = selected.contains(rule.id);
      return SortableItem(
        key: ValueKey(rule.id),
        index: index,
        child: ContextMenuRegion(
          menuItems: isEditing
              ? null
              : [
                  PopupMenuItem(
                    glyph: AppGlyphs.edit,
                    label: appLocalizations.edit,
                    onPressed: () => _handleEdit(index),
                  ),
                  PopupMenuItem(
                    danger: true,
                    glyph: AppGlyphs.delete,
                    label: appLocalizations.delete,
                    onPressed: () => _handleDelete(rule),
                  ),
                ],
          child: ItemPositionProvider(
            position: position,
            child: DecorationListItem(
              invalid: rule.regExp == null,
              isSelected: isSelected,
              contentPadding: const EdgeInsets.only(left: 16),
              onPressed: isEditing
                  ? () => _handleToggleSelected(rule.id)
                  : () => _handleEdit(index),
              leading: SizedBox.square(
                dimension: 32,
                child: IconTheme.merge(
                  data: const IconThemeData(size: 32),
                  child: CommonTargetIcon(src: rule.icon),
                ),
              ),
              title: TooltipText(
                text: Text(
                  rule.pattern,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: rule.regExp == null
                  ? Text(
                      appLocalizations.invalidRegex,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle,
                    )
                  : null,
              trailing: Checkbox(
                value: isSelected,
                isCircle: true,
                onChanged: (_) => _handleToggleSelected(rule.id),
              ),
            ),
          ),
        ),
      );
    }

    return PopGuard(
      onPop: selected.isEmpty && !_sorting
          ? null
          : (_) {
              setState(() {
                _selected = {};
                _sorting = false;
              });
              return false;
            },
      child: Scaffold(
        title: appLocalizations.iconStyle,
        iconActions: [
          IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: appLocalizations.refreshGroupIcons,
            onPressed: _refreshing ? null : _handleRefreshIcons,
          ),
        ],
        body: SortModeScope(
          sorting: _sorting,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(top: context.contentTopPadding),
                sliver: SliverToBoxAdapter(
                  child: SegmentedControl<ProxiesIconStyle>(
                    segments: [
                      (
                        ProxiesIconStyle.filled,
                        appLocalizations.iconStyleFilled,
                      ),
                      (ProxiesIconStyle.plain, appLocalizations.iconStylePlain),
                      (
                        ProxiesIconStyle.hidden,
                        appLocalizations.iconStyleHidden,
                      ),
                    ],
                    value: iconStyle,
                    onChanged: _handleStyle,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: TonalButtonTheme(
                    child: ListHeader(
                      title: appLocalizations.iconRules,
                      actions: _buildActions(ids, selected),
                    ),
                  ),
                ),
              ),
              if (rules.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ).copyWith(top: 12),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 48,
                      ),
                      child: NullStatus(
                        label: appLocalizations.iconRulesEmpty,
                        illustration: NullStatusIllustration.icons,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverPrismReorderableList(
                    itemBuilder: (_, index) => itemAt(index),
                    itemCount: rules.length,
                    proxyDecorator: (child, index, animation) =>
                        commonProxyDecorator(itemAt(index), index, animation),
                    onReorderItem: _handleReorder,
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(bottom: 16 + context.bottomInset),
                sliver: SliverToBoxAdapter(
                  child: ListFooter(text: appLocalizations.iconRulesTip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconRuleForm extends ConsumerStatefulWidget {
  const _IconRuleForm({this.rule, this.onDelete});

  final IconRule? rule;
  final Future<bool> Function()? onDelete;

  @override
  ConsumerState<_IconRuleForm> createState() => _IconRuleFormState();
}

enum _RuleField { pattern, icon }

class _IconRuleFormState extends ConsumerState<_IconRuleForm> {
  late final TextEditingController _controller;
  String _icon = '';
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.rule?.pattern);
    _icon = widget.rule?.icon ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({_RuleField field, String message})? _issue() {
    final appLocalizations = context.appLocalizations;
    final pattern = _controller.text.trim();
    if (pattern.isEmpty) {
      return (
        field: _RuleField.pattern,
        message: appLocalizations.emptyTip(appLocalizations.regex),
      );
    }
    try {
      RegExp(pattern);
    } catch (_) {
      return (
        field: _RuleField.pattern,
        message: appLocalizations.invalidRegex,
      );
    }
    if (_icon.isEmpty) {
      return (
        field: _RuleField.icon,
        message: appLocalizations.emptyTip(appLocalizations.icon),
      );
    }
    return null;
  }

  void _handleChanged(String _) {
    if (_attempted) {
      setState(() {});
    }
  }

  /// The same picker the custom groups use, with its link entry in the bar.
  Future<void> _handlePickIcon() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = await Navigator.of(context).push<String>(
      PagedSheetRoute(
        builder: (_) =>
            IconPickerView(value: _icon, groupName: _controller.text.trim()),
      ),
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      _icon = value;
    });
  }

  Future<void> _handleDelete() async {
    final deleted = await widget.onDelete?.call();
    if (deleted == true && mounted) {
      context.safeNestedPop();
    }
  }

  void _handleSubmit() {
    if (_issue() != null) {
      setState(() {
        _attempted = true;
      });
      return;
    }
    context.safeNestedPop(
      widget.rule != null
          ? widget.rule!.copyWith(pattern: _controller.text.trim(), icon: _icon)
          : IconRule(pattern: _controller.text.trim(), icon: _icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final issue = _attempted ? _issue() : null;
    return Scaffold(
      title: widget.rule == null
          ? appLocalizations.addIconRule
          : appLocalizations.editIconRule,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: appLocalizations.confirm,
        onPressed: _handleSubmit,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          top: context.sectionsTopPadding,
          bottom: 20 + context.bottomInset,
        ),
        children: [
          ErrorBanner(message: issue?.message),
          generateSection(
            title: appLocalizations.general,
            footer: appLocalizations.iconRuleHelp,
            items: [
              FormRow(
                title: appLocalizations.regex,
                invalid: issue?.field == _RuleField.pattern,
                trailing: FormRowTextField(
                  controller: _controller,
                  hintText: appLocalizations.required,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: _handleChanged,
                  onFieldSubmitted: (_) => _handleSubmit(),
                ),
              ),
              FormRow(
                title: appLocalizations.icon,
                invalid: issue?.field == _RuleField.icon,
                onPressed: _handlePickIcon,
                trailing: Row(
                  spacing: 2,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_icon.isNotEmpty)
                      SizedBox.square(
                        dimension: 28,
                        child: IconTheme.merge(
                          data: const IconThemeData(size: 28),
                          child: CommonTargetIcon(src: _icon),
                        ),
                      )
                    else
                      Text(
                        appLocalizations.required,
                        style: context.listTitleStyle.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const GlyphIcon(AppGlyphs.chevronForward),
                  ],
                ),
              ),
            ],
          ),
          if (widget.rule != null)
            generateSection(
              title: appLocalizations.action,
              items: [
                FormRow(
                  title: appLocalizations.delete,
                  titleStyle: TextStyle(color: context.colorScheme.error),
                  onPressed: _handleDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
