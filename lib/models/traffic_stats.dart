import 'package:flutter/foundation.dart';

const trafficStatsRetentionOptions = [3, 6, 12];
const _defaultRetentionMonths = 3;

Map<String, Object?> trafficStatsMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

int _intValue(Object? value, [int fallback = 0]) =>
    value is num && value.isFinite ? value.toInt() : fallback;

@immutable
class TrafficStatsSettings {
  final bool enable;
  final bool detail;
  final bool siteIcon;
  final int retentionMonths;

  const TrafficStatsSettings({
    this.enable = false,
    this.detail = true,
    this.siteIcon = true,
    this.retentionMonths = _defaultRetentionMonths,
  });

  factory TrafficStatsSettings.fromJson(Map<String, Object?> json) {
    final months = _intValue(json['retentionMonths']);
    return TrafficStatsSettings(
      enable: json['enable'] == true,
      detail: json['detail'] != false,
      siteIcon: json['siteIcon'] != false,
      retentionMonths: trafficStatsRetentionOptions.contains(months)
          ? months
          : _defaultRetentionMonths,
    );
  }

  Map<String, Object?> toJson() => {
    'enable': enable,
    'detail': detail,
    'siteIcon': siteIcon,
    'retentionMonths': retentionMonths,
  };

  TrafficStatsSettings copyWith({
    bool? enable,
    bool? detail,
    bool? siteIcon,
    int? retentionMonths,
  }) => TrafficStatsSettings(
    enable: enable ?? this.enable,
    detail: detail ?? this.detail,
    siteIcon: siteIcon ?? this.siteIcon,
    retentionMonths: retentionMonths ?? this.retentionMonths,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrafficStatsSettings &&
          enable == other.enable &&
          detail == other.detail &&
          siteIcon == other.siteIcon &&
          retentionMonths == other.retentionMonths;

  @override
  int get hashCode => Object.hash(enable, detail, siteIcon, retentionMonths);
}

@immutable
class TrafficStatsItem {
  final String name;
  final int up;
  final int down;
  final int hits;
  final String path;
  final List<TrafficStatsItem> subs;

  const TrafficStatsItem({
    this.name = '',
    this.up = 0,
    this.down = 0,
    this.hits = 0,
    this.path = '',
    this.subs = const [],
  });

  int get total => up + down;

  factory TrafficStatsItem.fromJson(Map<String, Object?> json) =>
      TrafficStatsItem(
        name: json['name'] as String? ?? '',
        up: _intValue(json['up']),
        down: _intValue(json['down']),
        hits: _intValue(json['hits']),
        path: json['path'] as String? ?? '',
        subs: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['subs'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'up': up,
    'down': down,
    'hits': hits,
    'path': path,
    'subs': [for (final item in subs) item.toJson()],
  };
}

@immutable
class TrafficStatsPoint {
  final String label;
  final int up;
  final int down;

  const TrafficStatsPoint({this.label = '', this.up = 0, this.down = 0});

  int get total => up + down;

  factory TrafficStatsPoint.fromJson(Map<String, Object?> json) =>
      TrafficStatsPoint(
        label: json['label'] as String? ?? '',
        up: _intValue(json['up']),
        down: _intValue(json['down']),
      );

  Map<String, Object?> toJson() => {'label': label, 'up': up, 'down': down};
}

@immutable
class TrafficStatsResult {
  final int runningSeconds;
  final int up;
  final int down;
  final int proxyUp;
  final int proxyDown;
  final List<TrafficStatsPoint> series;
  final List<TrafficStatsItem> hosts;
  final List<TrafficStatsItem> processes;
  final List<TrafficStatsItem> nodes;
  final List<TrafficStatsItem> profiles;
  final List<TrafficStatsItem> rules;
  final int ruleHits;
  final String since;

  const TrafficStatsResult({
    this.runningSeconds = 0,
    this.up = 0,
    this.down = 0,
    this.proxyUp = 0,
    this.proxyDown = 0,
    this.series = const [],
    this.hosts = const [],
    this.processes = const [],
    this.nodes = const [],
    this.profiles = const [],
    this.rules = const [],
    this.ruleHits = 0,
    this.since = '',
  });

  int get total => up + down;
  int get proxyTotal => proxyUp + proxyDown;

  factory TrafficStatsResult.fromJson(Map<String, Object?> json) =>
      TrafficStatsResult(
        runningSeconds: _intValue(json['running-seconds']).clamp(0, 1 << 53),
        up: _intValue(json['up']),
        down: _intValue(json['down']),
        proxyUp: _intValue(json['proxy-up']),
        proxyDown: _intValue(json['proxy-down']),
        series: List<TrafficStatsPoint>.unmodifiable([
          for (final item in (json['series'] as List?) ?? const [])
            TrafficStatsPoint.fromJson(trafficStatsMap(item)),
        ]),
        hosts: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['hosts'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
        processes: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['processes'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
        nodes: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['nodes'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
        profiles: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['profiles'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
        rules: List<TrafficStatsItem>.unmodifiable([
          for (final item in (json['rules'] as List?) ?? const [])
            TrafficStatsItem.fromJson(trafficStatsMap(item)),
        ]),
        ruleHits: _intValue(json['rule-hits']),
        since: json['since'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
    'up': up,
    'down': down,
    'proxy-up': proxyUp,
    'proxy-down': proxyDown,
    'running-seconds': runningSeconds,
    'series': [for (final item in series) item.toJson()],
    'hosts': [for (final item in hosts) item.toJson()],
    'processes': [for (final item in processes) item.toJson()],
    'nodes': [for (final item in nodes) item.toJson()],
    'profiles': [for (final item in profiles) item.toJson()],
    'rules': [for (final item in rules) item.toJson()],
    'rule-hits': ruleHits,
    'since': since,
  };
}
