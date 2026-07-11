import 'package:http/http.dart' as http;

http.Client createPlatformClient() => http.Client();

void setPlatformIgnoreCerts(bool val) {
  // Certificate pinning is not supported on web
}

http.Client createPlatformIOClient({bool ignoreCertificates = false}) {
  return http.Client();
}
