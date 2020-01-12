class User {
  final int id;
  final String email, username, avatarHash;

  User(this.id, this.email, this.username, this.avatarHash);
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json.containsKey('email') ? json['email'] : '',
        username = json['username'],
        avatarHash = json['avatarUrl'];

  toJSON() => {"id": this.id, "email": this.email, "username": this.username};

  String avatarUrl() {
    return "https://secure.gravatar.com/avatar/" + this.avatarHash;
  }
}

class UserTokenPair {
  final User user;
  final String token;
  UserTokenPair(this.user, this.token);
}
