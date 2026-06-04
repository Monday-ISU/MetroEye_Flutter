import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef ClientVersionLoader = Future<String> Function();

class ClientVersionInterceptor extends Interceptor {
  ClientVersionInterceptor({ClientVersionLoader? loadClientVersion})
    : _loadClientVersion = loadClientVersion ?? _loadPackageVersion;

  static const String headerName = 'Client-Version';

  final ClientVersionLoader _loadClientVersion;
  String? _cachedVersion;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers[headerName] = await _clientVersion();
    handler.next(options);
  }

  Future<String> _clientVersion() async {
    final cachedVersion = _cachedVersion;
    if (cachedVersion != null) {
      return cachedVersion;
    }

    final version = await _loadClientVersion();
    _cachedVersion = version;
    return version;
  }

  static Future<String> _loadPackageVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
