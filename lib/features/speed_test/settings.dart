import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client.dart';
import 'widgets.dart';

class SpeedTestSettingsView extends StatefulWidget {
  const SpeedTestSettingsView({
    super.key,
    required this.settings,
    required this.proxy,
    this.onChanged,
  });
  final SpeedTestSettings settings;
  final String proxy;
  final ValueChanged<SpeedTestSettings>? onChanged;
  @override
  State<SpeedTestSettingsView> createState() => _SpeedTestSettingsViewState();
}

class _SpeedTestSettingsViewState extends State<SpeedTestSettingsView> {
  late SpeedTestSettings _settings = widget.settings;
  bool _pickingServer = false;

  void _change(SpeedTestSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged?.call(settings);
  }

  Future<void> _pickServer() async {
    if (_pickingServer) return;
    _pickingServer = true;
    try {
      final node = await Navigator.of(context).push<SpeedTestNode>(
        PagedSheetRoute(
          builder: (_) => SpeedTestServerPicker(
            proxy: widget.proxy,
            selected: _settings.server,
          ),
        ),
      );
      if (!mounted || node == null) return;
      _change(_settings.copyWith(server: node, automatic: node.host.isEmpty));
    } finally {
      _pickingServer = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return SpeedTestScope(
      child: Scaffold(
        title: l.speedTestSettings,
        confirmationAction: IconButtonData(
          glyph: AppGlyphs.check,
          tooltip: l.save,
          onPressed: () => context.safeNestedPop(_settings),
        ),
        body: Builder(
          builder: (context) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
              top: context.sectionsTopPadding,
              bottom: 20 + context.bottomInset,
            ),
            children: [
              generateSection(
                items: [
                  ListItem(
                    title: Text(l.speedTestServer),
                    subtitle: Text(
                      _settings.server?.title ?? l.speedTestServerAutoDesc,
                    ),
                    trailing: const GlyphIcon(AppGlyphs.chevronForward),
                    onTap: _pickServer,
                  ),
                ],
              ),
              generateSection(
                title: l.general,
                footer:
                    '${l.speedTestConnectionsDesc(8)}\n${l.speedTestProtocolDesc}',
                items: [
                  ListItem<int>.options(
                    title: Text(l.speedTestDuration),
                    options: const [5, 10, 15, 20],
                    value: _settings.duration,
                    textBuilder: (value) => '${value}s',
                    onChanged: (value) =>
                        _change(_settings.copyWith(duration: value)),
                  ),
                  ListItem<bool>.options(
                    title: Text(l.speedTestConnections),
                    options: const [false, true],
                    value: _settings.multiThread,
                    textBuilder: (value) =>
                        value ? l.speedTestMultiThread : l.speedTestSingleThread,
                    onChanged: (value) =>
                        _change(_settings.copyWith(multiThread: value)),
                  ),
                  ListItem<String>.options(
                    title: Text(l.speedTestProtocol),
                    options: const ['h2', 'h3'],
                    value: _settings.protocol,
                    textBuilder: (value) =>
                        value == 'h3' ? 'HTTP/3 · QUIC' : 'HTTP/2',
                    onChanged: (value) =>
                        _change(_settings.copyWith(protocol: value)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeedTestServerPicker extends ConsumerStatefulWidget {
  const SpeedTestServerPicker({super.key, required this.proxy, this.selected});
  final String proxy;
  final SpeedTestNode? selected;
  @override
  ConsumerState<SpeedTestServerPicker> createState() =>
      _SpeedTestServerPickerState();
}

class _SpeedTestServerPickerState extends ConsumerState<SpeedTestServerPicker> {
  late final _client = ref.read(speedTestClientProvider);
  final _id = 'servers-${DateTime.now().microsecondsSinceEpoch}';
  Timer? _debounce;
  int _serial = 0;
  String _query = '';
  List<SpeedTestNode>? _nodes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_client.cancel(_id));
    super.dispose();
  }

  void _search(String query) {
    if (query == _query) return;
    _debounce?.cancel();
    setState(() {
      _query = query;
      _serial++;
      _loading = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_load()),
    );
  }

  Future<void> _load() async {
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final nodes = await _client.servers(widget.proxy, _query, _id);
      if (!mounted || serial != _serial) return;
      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _select(SpeedTestNode node) {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    // A focused bar search owns local history. Close that layer before
    // returning the server, so selecting a result completes in one tap.
    navigator.popUntil(
      (page) => page != route || !page.willHandlePopInternally,
    );
    navigator.pop(node);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(speedTestClientProvider);
    final l = context.appLocalizations;
    final nodes = _nodes ?? const <SpeedTestNode>[];
    return SpeedTestScope(
      child: Scaffold(
        title: l.speedTestServer,
        searchState: AppBarSearchState(onSearch: _search),
        body: Builder(
          builder: (context) => NullStatusSwitcher(
            isLoading: _loading,
            loadingStatus: const Center(child: ActivityIndicator.page()),
            child: _loading
                ? const Center(child: ActivityIndicator.page())
                : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.speedTestErrorUnavailable),
                        TextButton(onPressed: _load, child: Text(l.retry)),
                      ],
                    ),
                  )
                : PrismListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
                      top: context.contentTopPadding + 12,
                      bottom: 20 + context.bottomInset,
                    ),
                    itemCount: nodes.length + 1,
                    itemBuilder: (context, index) {
                      final node = index == 0 ? null : nodes[index - 1];
                      final selected = node == null
                          ? widget.selected == null
                          : node.host == widget.selected?.host;
                      return ItemPositionProvider(
                        position: ItemPosition.get(index, nodes.length + 1),
                        child: DecorationListItem(
                          title: node == null
                              ? Text(l.auto)
                              : EmojiText(
                                  [
                                    if (node.cc.length == 2)
                                      node.cc.toUpperCase().countryFlagEmoji,
                                    node.name,
                                  ].join(' '),
                                ),
                          subtitle: Text(
                            node == null
                                ? l.speedTestServerAutoDesc
                                : [
                                    node.sponsor,
                                    node.latency > 0
                                        ? '${node.latency.round()} ms'
                                        : node.host,
                                  ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                          trailing: selected ? const SelectionCheck() : null,
                          onPressed: () =>
                              _select(node ?? const SpeedTestNode()),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
