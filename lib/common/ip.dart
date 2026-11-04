import 'dart:io';

final _ipEndpointPattern = RegExp(r'^\[([^\]]+)\](?::(\d+))?$|^([^:]+):(\d+)$');

({InternetAddress address, String? port})? ipEndpointOf(String endpoint) {
  var host = endpoint.trim();
  String? port;
  if (InternetAddress.tryParse(host) == null) {
    final match = _ipEndpointPattern.firstMatch(host);
    if (match == null) return null;
    port = match.group(2) ?? match.group(4);
    if (port != null && (int.tryParse(port) ?? 65536) > 65535) return null;
    host = match.group(1) ?? match.group(3)!;
  }
  final address = InternetAddress.tryParse(host);
  return address == null ? null : (address: address, port: port);
}

String? publicIpOf(String endpoint) {
  final address = ipEndpointOf(endpoint)?.address;
  if (address == null) return null;
  var bytes = address.rawAddress;
  if (bytes.length == 16 &&
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 255 &&
      bytes[11] == 255) {
    bytes = bytes.sublist(12);
  }
  if (bytes.length == 4) {
    final a = bytes[0], b = bytes[1], c = bytes[2];
    if (a == 0 ||
        a == 10 ||
        a == 127 ||
        a >= 224 ||
        a == 100 && b >= 64 && b <= 127 ||
        a == 169 && b == 254 ||
        a == 172 && b >= 16 && b <= 31 ||
        a == 192 &&
            (b == 168 || b == 0 && (c == 0 || c == 2) || b == 88 && c == 99) ||
        a == 198 && (b == 18 || b == 19 || b == 51 && c == 100) ||
        a == 203 && b == 0 && c == 113) {
      return null;
    }
    return bytes.join('.');
  }
  if ((bytes[0] & 0xe0) != 0x20 ||
      bytes[0] == 0x20 &&
          bytes[1] == 1 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8 ||
      bytes[0] == 0x3f && bytes[1] == 0xff && (bytes[2] & 0xf0) == 0) {
    return null;
  }
  return address.address;
}
