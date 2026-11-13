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
