enum IpRiskLevel { low, medium, high, veryHigh }

enum IpRiskGroup { datacenter, blacklist, proxy }

enum IpRiskAmount { low, medium, high }

enum IpRiskShare { little, some, almostAll }

enum IpRiskConnection { server, vpn, publicProxy, tor, webProxy }

class IpRiskCheck {
  final IpRiskGroup group;
  final String name;
  final bool? hit;
  const IpRiskCheck({required this.group, required this.name, this.hit});
  IpRiskCheck copyWith({bool? hit}) =>
      IpRiskCheck(group: group, name: name, hit: hit ?? this.hit);
}

class IpRiskNote {
  final bool? direct;
  final String isp;
  final IpRiskAmount? amount;
  final IpRiskShare? share;
  final String operatorName;
  final IpRiskLevel? operatorLevel;
  final String ownerName;
  final IpRiskLevel? ownerLevel;
  final IpRiskConnection? connection;
  final IpRiskLevel? warning;
  const IpRiskNote({
    this.direct,
    this.isp = '',
    this.amount,
    this.share,
    this.operatorName = '',
    this.operatorLevel,
    this.ownerName = '',
    this.ownerLevel,
    this.connection,
    this.warning,
  });
}

class IpRisk {
  final String ip;
  final int score;
  final IpRiskLevel level;
  final String hostname;
  final String asn;
  final String isp;
  final String organization;
  final String country;
  final String countryCode;
  final String region;
  final String city;
  final List<IpRiskCheck> checks;
  final IpRiskNote? note;
  const IpRisk({
    required this.ip,
    required this.score,
    required this.level,
    this.hostname = '',
    this.asn = '',
    this.isp = '',
    this.organization = '',
    this.country = '',
    this.countryCode = '',
    this.region = '',
    this.city = '',
    this.checks = const [],
    this.note,
  });
  factory IpRisk.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported IP risk cache');
    }
    final note = json['note'] as Map<String, dynamic>?;
    T? optionalEnum<T extends Enum>(List<T> values, String? name) =>
        name == null ? null : values.byName(name);
    return IpRisk(
      ip: json['ip'] as String,
      score: json['score'] as int,
      level: IpRiskLevel.values.byName(json['level'] as String),
      hostname: json['hostname'] as String,
      asn: json['asn'] as String,
      isp: json['isp'] as String,
      organization: json['organization'] as String,
      country: json['country'] as String,
      countryCode: json['countryCode'] as String,
      region: json['region'] as String,
      city: json['city'] as String,
      checks: [
        for (final check in json['checks'] as List)
          IpRiskCheck(
            group: IpRiskGroup.values.byName(check['group'] as String),
            name: check['name'] as String,
            hit: check['hit'] as bool?,
          ),
      ],
      note: note == null
          ? null
          : IpRiskNote(
              direct: note['direct'] as bool?,
              isp: note['isp'] as String,
              amount: optionalEnum(
                IpRiskAmount.values,
                note['amount'] as String?,
              ),
              share: optionalEnum(IpRiskShare.values, note['share'] as String?),
              operatorName: note['operatorName'] as String,
              operatorLevel: optionalEnum(
                IpRiskLevel.values,
                note['operatorLevel'] as String?,
              ),
              ownerName: note['ownerName'] as String,
              ownerLevel: optionalEnum(
                IpRiskLevel.values,
                note['ownerLevel'] as String?,
              ),
              connection: optionalEnum(
                IpRiskConnection.values,
                note['connection'] as String?,
              ),
              warning: optionalEnum(
                IpRiskLevel.values,
                note['warning'] as String?,
              ),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'ip': ip,
    'score': score,
    'level': level.name,
    'hostname': hostname,
    'asn': asn,
    'isp': isp,
    'organization': organization,
    'country': country,
    'countryCode': countryCode,
    'region': region,
    'city': city,
    'checks': [
      for (final check in checks)
        {'group': check.group.name, 'name': check.name, 'hit': check.hit},
    ],
    'note': note == null
        ? null
        : {
            'direct': note!.direct,
            'isp': note!.isp,
            'amount': note!.amount?.name,
            'share': note!.share?.name,
            'operatorName': note!.operatorName,
            'operatorLevel': note!.operatorLevel?.name,
            'ownerName': note!.ownerName,
            'ownerLevel': note!.ownerLevel?.name,
            'connection': note!.connection?.name,
            'warning': note!.warning?.name,
          },
  };

  IpRisk copyWith({int? score}) => IpRisk(
    ip: ip,
    score: score ?? this.score,
    level: level,
    hostname: hostname,
    asn: asn,
    isp: isp,
    organization: organization,
    country: country,
    countryCode: countryCode,
    region: region,
    city: city,
    checks: checks,
    note: note,
  );
}

extension IpRiskExt on IpRisk {
  bool get isHomeBroadband =>
      checks.isNotEmpty &&
      checks.any((check) => check.group == IpRiskGroup.datacenter) &&
      checks.every((check) => check.hit != true);

  int get displayScore => !isHomeBroadband && score == 0 ? 1 : score;

  IpRisk get normalized =>
      !isHomeBroadband && score == 0 ? copyWith(score: 1) : this;
}

extension IpRiskClassification on IpRisk {
  bool get isDatacenter => checks.any(
    (c) =>
        c.group == IpRiskGroup.datacenter &&
        c.name == 'Datacenter' &&
        c.hit == true,
  );
  bool get isResidentialProxy => checks.any(
    (c) =>
        c.group == IpRiskGroup.datacenter &&
        c.name == 'Residential Proxy' &&
        c.hit == true,
  );
}
