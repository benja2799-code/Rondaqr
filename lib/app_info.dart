import 'package:package_info_plus/package_info_plus.dart';

class RondaQrAppInfo {
  RondaQrAppInfo._();

  static const String appName = 'RondaQR';
  static const String company = 'LG Seguridad SPA';

  static final Future<String> version = _loadVersion();

  static Future<String> _loadVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String value = packageInfo.version.trim();
      return value.isEmpty ? 'No disponible' : value;
    } catch (_) {
      return 'No disponible';
    }
  }
}
