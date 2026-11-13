enum SpeedTestPhase { connecting, latency, download, upload, done }

Map<String, Object?> speedTestMap(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

double _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : 0;

class SpeedTestNode {
  final String host;
  final String name;
  final String cc;
  final String sponsor;
  final double latency;
  const SpeedTestNode({
    this.host = '',
    this.name = '',
    this.cc = '',
    this.sponsor = '',
    this.latency = 0,
  });
  factory SpeedTestNode.fromJson(Map<String, Object?> json) => SpeedTestNode(
    host: json['host'] as String? ?? '',
    name: json['name'] as String? ?? '',
    cc: json['cc'] as String? ?? '',
    sponsor: json['sponsor'] as String? ?? '',
    latency: _number(json['latency']),
  );
  Map<String, Object?> toJson() => {
    'host': host,
    'name': name,
    'cc': cc,
    'sponsor': sponsor,
    'latency': latency,
  };
  String get title => [name, sponsor].where((s) => s.isNotEmpty).join(' · ');
}

class SpeedTestServer {
  final String ip;
  final String country;
  final String city;
  final String colo;
  final String host;
  final String sponsor;
  const SpeedTestServer({
    this.ip = '',
    this.country = '',
    this.city = '',
    this.colo = '',
    this.host = '',
    this.sponsor = '',
  });
  factory SpeedTestServer.fromJson(Map<String, Object?> json) =>
      SpeedTestServer(
        ip: json['ip'] as String? ?? '',
        country: json['country'] as String? ?? '',
        city: json['city'] as String? ?? '',
        colo: json['colo'] as String? ?? '',
        host: json['host'] as String? ?? '',
        sponsor: json['sponsor'] as String? ?? '',
      );
  Map<String, Object?> toJson() => {
    'ip': ip,
    'country': country,
    'city': city,
    'colo': colo,
    'host': host,
    'sponsor': sponsor,
  };
}

class SpeedTestOutbound {
  final List<String> chains;
  final String rule;
  final String rulePayload;
  const SpeedTestOutbound({
    this.chains = const [],
    this.rule = '',
    this.rulePayload = '',
  });
  factory SpeedTestOutbound.fromJson(Map<String, Object?> json) =>
      SpeedTestOutbound(
        chains: List<String>.unmodifiable(
          (json['chains'] as List?)?.whereType<String>() ?? const [],
        ),
        rule: json['rule'] as String? ?? '',
        rulePayload: json['rule-payload'] as String? ?? '',
      );
  Map<String, Object?> toJson() => {
    'chains': chains,
    'rule': rule,
    'rule-payload': rulePayload,
  };
}

class SpeedTestState {
  final String id;
  final String provider;
  final String protocol;
  final bool fallback;
  final int streams;
  final int duration;
  final SpeedTestPhase phase;
  final double progress;
  final double speed;
  final bool direct;
  final SpeedTestOutbound? outbound;
  final SpeedTestServer? server;
  final double latency;
  final double jitter;
  final double download;
  final double upload;
  final double downloadLatency;
  final double uploadLatency;
  final int rpm;
  final int bytes;
  final String error;
  const SpeedTestState({
    this.id = '',
    this.provider = 'speedtest',
    this.protocol = 'h1',
    this.fallback = false,
    this.streams = 8,
    this.duration = 10,
    this.phase = SpeedTestPhase.connecting,
    this.progress = 0,
    this.speed = 0,
    this.direct = false,
    this.outbound,
    this.server,
    this.latency = 0,
    this.jitter = 0,
    this.download = 0,
    this.upload = 0,
    this.downloadLatency = 0,
    this.uploadLatency = 0,
    this.rpm = 0,
    this.bytes = 0,
    this.error = '',
  });
  factory SpeedTestState.fromJson(Map<String, Object?> json) => SpeedTestState(
    id: json['id'] as String? ?? '',
    provider: json['provider'] as String? ?? 'speedtest',
    protocol: json['protocol'] as String? ?? 'h1',
    fallback: json['fallback'] as bool? ?? false,
    streams: (json['streams'] as num?)?.toInt() ?? 8,
    duration: (json['duration'] as num?)?.toInt() ?? 10,
    phase: SpeedTestPhase.values.firstWhere(
      (p) => p.name == json['phase'],
      orElse: () => SpeedTestPhase.connecting,
    ),
    progress: _number(json['progress']),
    speed: _number(json['speed']),
    direct: json['direct'] as bool? ?? false,
    outbound: json['outbound'] is Map
        ? SpeedTestOutbound.fromJson(speedTestMap(json['outbound']))
        : null,
    server: json['server'] is Map
        ? SpeedTestServer.fromJson(speedTestMap(json['server']))
        : null,
    latency: _number(json['latency']),
    jitter: _number(json['jitter']),
    download: _number(json['download']),
    upload: _number(json['upload']),
    downloadLatency: _number(json['download-latency']),
    uploadLatency: _number(json['upload-latency']),
    rpm: (json['rpm'] as num?)?.toInt() ?? 0,
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    error: json['error'] as String? ?? '',
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider,
    'protocol': protocol,
    'fallback': fallback,
    'streams': streams,
    'duration': duration,
    'phase': phase.name,
    'progress': progress,
    'speed': speed,
    'direct': direct,
    'outbound': outbound?.toJson(),
    'server': server?.toJson(),
    'latency': latency,
    'jitter': jitter,
    'download': download,
    'upload': upload,
    'download-latency': downloadLatency,
    'upload-latency': uploadLatency,
    'rpm': rpm,
    'bytes': bytes,
    'error': error,
  };
  bool get isFinished => phase == SpeedTestPhase.done || error.isNotEmpty;
  bool get completed => phase == SpeedTestPhase.done && error.isEmpty;
}

class SpeedTestSettings {
  const SpeedTestSettings({
    this.protocol = 'h2',
    this.duration = 10,
    this.multiThread = true,
    this.server,
  });
  final String protocol;
  final int duration;
  final bool multiThread;
  final SpeedTestNode? server;
  factory SpeedTestSettings.fromJson(Map<String, Object?> json) =>
      SpeedTestSettings(
        protocol: json['protocol'] == 'h3' ? 'h3' : 'h2',
        duration: const [5, 10, 15, 20].contains(json['duration'])
            ? json['duration'] as int
            : 10,
        multiThread: json['multiThread'] as bool? ?? true,
        server: json['server'] is Map
            ? SpeedTestNode.fromJson(speedTestMap(json['server']))
            : null,
      );
  SpeedTestSettings copyWith({
    String? protocol,
    int? duration,
    bool? multiThread,
    SpeedTestNode? server,
    bool automatic = false,
  }) => SpeedTestSettings(
    protocol: protocol ?? this.protocol,
    duration: duration ?? this.duration,
    multiThread: multiThread ?? this.multiThread,
    server: automatic ? null : server ?? this.server,
  );
  Map<String, Object?> toJson() => {
    'protocol': protocol,
    'duration': duration,
    'multiThread': multiThread,
    'server': server?.toJson(),
  };
  Map<String, Object?> toParams(String proxy, String id) => {
    ...toJson(),
    'id': id,
    'provider': 'speedtest',
    'proxy': proxy,
    'streams': multiThread ? 8 : 1,
  };
}

class SpeedTestRecord {
  const SpeedTestRecord({
    required this.time,
    required this.proxy,
    required this.result,
  });
  final int time;
  final String proxy;
  final SpeedTestState result;
  factory SpeedTestRecord.fromJson(Map<String, Object?> json) =>
      SpeedTestRecord(
        time: (json['time'] as num).toInt(),
        proxy: json['proxy'] as String? ?? '',
        result: SpeedTestState.fromJson(speedTestMap(json['result'])),
      );
  Map<String, Object?> toJson() => {
    'time': time,
    'proxy': proxy,
    'result': result.toJson(),
  };
}

class SpeedTestData {
  const SpeedTestData({
    this.settings = const SpeedTestSettings(),
    this.records = const [],
  });
  final SpeedTestSettings settings;
  final List<SpeedTestRecord> records;
  factory SpeedTestData.fromJson(Map<String, Object?> json) => SpeedTestData(
    settings: SpeedTestSettings.fromJson(speedTestMap(json['settings'])),
    records: [
      for (final item
          in (json['records'] as List? ?? const []).whereType<Map>())
        SpeedTestRecord.fromJson(speedTestMap(item)),
    ],
  );
  Map<String, Object?> toJson() => {
    'settings': settings.toJson(),
    'records': [for (final record in records) record.toJson()],
  };
}
