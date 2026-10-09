enum ApiVersion {
  /// `/api/v1`: Echo, frozen since 2.4.0 but still served.
  v1('v1'),

  /// `/api/v2`: Huma/OpenAPI, available since 2.4.0.
  v2('v2');

  new(this.pathSegment);

  final String pathSegment;
}
