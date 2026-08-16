import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/core/network/client.dart';

class AuthenticatedAvatar extends StatefulWidget {
  final Client client;
  final String username;

  const AuthenticatedAvatar({
    required this.client,
    required this.username,
    super.key,
  });

  @override
  State<AuthenticatedAvatar> createState() => _AuthenticatedAvatarState();
}

class _AuthenticatedAvatarState extends State<AuthenticatedAvatar> {
  Future<http.Response>? _response;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AuthenticatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        oldWidget.username != widget.username) {
      _load();
    }
  }

  void _load() {
    _response = widget.username.isEmpty
        ? null
        : widget.client.getRaw(url: '/avatar/${widget.username}');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<http.Response>(
      future: _response,
      builder: (context, snapshot) {
        final response = snapshot.data;
        if (response != null &&
            response.statusCode >= 200 &&
            response.statusCode < 400) {
          return CircleAvatar(backgroundImage: MemoryImage(response.bodyBytes));
        }
        return const CircleAvatar();
      },
    );
  }
}
