class AuthModel {
  String address;
  String token;
  String? refreshCookie;

  AuthModel(this.address, this.token, {this.refreshCookie});
}
