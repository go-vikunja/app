class Client {
  final String _token;

  Client(this._token);

  bool operator ==(dynamic otherClient) {
    return otherClient._token == _token;
  }

  @override
  int get hashCode => _token.hashCode;
}
