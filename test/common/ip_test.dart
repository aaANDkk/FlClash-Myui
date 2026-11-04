import 'package:fl_clash/common/ip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps endpoint ports separate for masking public and private addresses',
    () {
      expect(ipEndpointOf('198.18.0.1:38120')?.port, '38120');
      expect(ipEndpointOf('[2606:4700:4700::1111]:443')?.port, '443');
      expect(ipEndpointOf('2606:4700:4700::1111')?.port, isNull);
      expect(ipEndpointOf('example.com:443'), isNull);
      expect(ipEndpointOf('1.1.1.1:65536'), isNull);
    },
  );
  test('extracts public addresses while preserving IPv6 identity', () {
    expect(publicIpOf('74.125.204.188:5228'), '74.125.204.188');
    expect(publicIpOf('108.177.97.188'), '108.177.97.188');
    expect(publicIpOf('[2606:4700:4700::1111]:443'), '2606:4700:4700::1111');
    expect(publicIpOf('2606:4700:4700::1111'), '2606:4700:4700::1111');
    expect(publicIpOf('::ffff:8.8.8.8'), '8.8.8.8');
  });

  test(
    'does not offer country lookup for private, synthetic or invalid addresses',
    () {
      for (final endpoint in [
        '',
        'example.com:443',
        '8.8.8.8:65536',
        '[8.8.8.8]:invalid',
        '0.0.0.0',
        '10.1.2.3',
        '100.64.0.1',
        '127.0.0.1',
        '169.254.1.1',
        '172.16.0.1',
        '192.168.1.1',
        '198.18.0.1:38120',
        '198.19.255.255',
        '192.0.2.1',
        '198.51.100.1',
        '203.0.113.1',
        '224.0.0.1',
        '255.255.255.255',
        '::',
        '::1',
        'fe80::1',
        'fd00::1',
        'ff02::1',
        '2001:db8::1',
        '3fff::1',
        '::ffff:192.168.1.1',
      ]) {
        expect(publicIpOf(endpoint), isNull, reason: endpoint);
      }
    },
  );
}
