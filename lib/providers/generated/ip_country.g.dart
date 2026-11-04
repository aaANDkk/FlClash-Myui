// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../ip_country.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ipCountry)
final ipCountryProvider = IpCountryFamily._();

final class IpCountryProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  IpCountryProvider._({
    required IpCountryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ipCountryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ipCountryHash();

  @override
  String toString() {
    return r'ipCountryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return ipCountry(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IpCountryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ipCountryHash() => r'e1461792b951f44cb5d7ac699d06fa9b92b8964d';

final class IpCountryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  IpCountryFamily._()
    : super(
        retry: null,
        name: r'ipCountryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  IpCountryProvider call(String ip) =>
      IpCountryProvider._(argument: ip, from: this);

  @override
  String toString() => r'ipCountryProvider';
}
