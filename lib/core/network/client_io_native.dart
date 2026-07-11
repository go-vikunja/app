import 'dart:io';

import 'package:cronet_http/cronet_http.dart' as cronet_http;
import 'package:cupertino_http/cupertino_http.dart' as cupertino_http;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;

http.Client createPlatformClient() {
  if (Platform.isAndroid) {
    final engine = cronet_http.CronetEngine.build(
      cacheMode: cronet_http.CacheMode.memory,
      cacheMaxSize: 1000000,
    );
    return cronet_http.CronetClient.fromCronetEngine(engine);
  } else if (Platform.isIOS || Platform.isMacOS) {
    final config =
        cupertino_http.URLSessionConfiguration.ephemeralSessionConfiguration()
          ..cache = cupertino_http.URLCache.withCapacity(
            memoryCapacity: 1000000,
          );
    return cupertino_http.CupertinoClient.fromSessionConfiguration(config);
  }
  return io_client.IOClient();
}

class IgnoreCertHttpOverrides extends HttpOverrides {
  bool ignoreCerts = false;

  IgnoreCertHttpOverrides(bool ignore) {
    ignoreCerts = ignore;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, _, _) => ignoreCerts;
  }
}

void setPlatformIgnoreCerts(bool val) {
  HttpOverrides.global = IgnoreCertHttpOverrides(val);
}

http.Client createPlatformIOClient({bool ignoreCertificates = false}) {
  final httpClient = HttpClient();
  if (ignoreCertificates) {
    httpClient.badCertificateCallback = (_, _, _) => true;
  }
  return io_client.IOClient(httpClient);
}
