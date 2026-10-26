import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

final String _hash = 'a1B2' * 10;
final String _token = 'Zx9' * 21 + 'q';

void main() {
  group('parseLinkShareUrl', () {
    test("the web's link: base, hash and view", () {
      final parsed = parseLinkShareUrl(
        'https://tasks.example.com/share/$_hash/auth?view=42',
      )!;

      expect(parsed.base, Uri.parse('https://tasks.example.com/'));
      expect(parsed.hash, _hash);
      expect(parsed.viewId, 42);
    });

    test('a path prefix before share/ is part of the base, port kept', () {
      final parsed = parseLinkShareUrl(
        'http://192.168.1.5:8080/apps/vikunja/share/$_hash/auth',
      )!;

      expect(parsed.base, Uri.parse('http://192.168.1.5:8080/apps/vikunja/'));
      expect(parsed.viewId, isNull);
    });

    test('without /auth, with trailing slashes, with logoVisible', () {
      for (final link in [
        'https://e.com/share/$_hash',
        'https://e.com/share/$_hash/',
        'https://e.com/share/$_hash/auth/',
        'https://e.com/share/$_hash/auth?logoVisible=false&view=3',
        'https://e.com/share/$_hash/auth?view=3&logoVisible=true#top',
      ]) {
        final parsed = parseLinkShareUrl(link);
        expect(parsed?.hash, _hash, reason: link);
        expect(parsed?.base, Uri.parse('https://e.com/'), reason: link);
      }
      expect(
        parseLinkShareUrl('https://e.com/share/$_hash/auth?view=3')?.viewId,
        3,
      );
    });

    test('a view that is not a positive number is ignored', () {
      for (final view in ['0', '-2', 'abc', '', '1.5', '%E0%A4%A']) {
        expect(
          parseLinkShareUrl('https://e.com/share/$_hash/auth?view=$view')
              ?.viewId,
          isNull,
          reason: view,
        );
      }
    });

    test('the last share/ segment counts', () {
      final parsed = parseLinkShareUrl(
        'https://e.com/share/tools/share/$_hash/auth',
      )!;

      expect(parsed.base, Uri.parse('https://e.com/share/tools/'));
    });

    test('a link among other words, as Android shares it', () {
      final parsed = parseLinkShareUrl(
        'Our shopping list\nhttps://e.com/share/$_hash/auth?view=7 thanks',
      )!;

      expect(parsed.hash, _hash);
      expect(parsed.viewId, 7);
      expect(
        parseLinkShareUrl('  https://e.com/share/$_hash/auth \n')?.hash,
        _hash,
      );
    });

    test('the address the web shows a guest, with the hash in #', () {
      final inView = parseLinkShareUrl(
        'https://e.com/vikunja/projects/12/34#share-auth-token=$_hash',
      )!;
      expect(inView.base, Uri.parse('https://e.com/vikunja/'));
      expect(inView.hash, _hash);
      expect(inView.viewId, 34);

      final project = parseLinkShareUrl(
        'https://e.com/projects/12#share-auth-token=$_hash',
      )!;
      expect(project.base, Uri.parse('https://e.com/'));
      expect(project.viewId, isNull);

      final task = parseLinkShareUrl(
        'https://e.com/v/tasks/99#share-auth-token=$_hash',
      )!;
      expect(task.base, Uri.parse('https://e.com/v/'));
      expect(task.viewId, isNull);

      expect(
        parseLinkShareUrl('https://e.com/#share-auth-token=$_hash')?.base,
        Uri.parse('https://e.com/'),
      );
    });

    test('not a share link', () {
      for (final text in [
        '',
        '   ',
        'tasks.example.com/share/$_hash/auth',
        'ftp://e.com/share/$_hash/auth',
        'vikunja-dev.coderoftime.vikunja://share/$_hash/auth',
        'https://e.com/share/${_hash.substring(1)}/auth',
        'https://e.com/share/${_hash}a/auth',
        'https://e.com/share/${_hash.substring(1)}-/auth',
        'https://e.com/share/$_hash/edit',
        'https://e.com/share/$_hash/auth/more',
        'https://e.com/projects/12',
        'https://e.com/projects/12#share-auth-token=short',
        'https://e.com/register#invite-link=$_token',
        'https://tasks.example.com',
        'not a link at all',
        'https://e.com/%E0%A4%A/share/$_hash/auth',
      ]) {
        expect(parseLinkShareUrl(text), isNull, reason: text);
      }
    });

    test('round trips with linkShareUrl', () {
      for (final (base, viewId) in [
        ('https://tasks.example.com/', null),
        ('https://tasks.example.com/', 42),
        ('http://localhost:34527/', 3),
        ('https://example.com/a/b/', null),
      ]) {
        final link = linkShareUrl(
          base: Uri.parse(base),
          hash: _hash,
          viewId: viewId,
        );
        final parsed = parseLinkShareUrl(link.toString())!;

        expect(parsed.base, Uri.parse(base));
        expect(parsed.hash, _hash);
        expect(parsed.viewId, viewId);
        expect(parsed.url, link);
      }
    });

    test('shortened shows four characters of the hash', () {
      final parsed = parseLinkShareUrl(
        'https://e.com/v/share/$_hash/auth?view=2',
      )!;

      expect(parsed.shortened, 'https://e.com/v/share/a1B2…/auth');
      expect(parsed.shortened, isNot(contains(_hash)));
      expect(
        ParsedLinkShareUrl(
          base: Uri.parse('https://e.com/'),
          hash: 'abc',
        ).shortened,
        'https://e.com/share/…/auth',
      );
    });

    test('equality, and toString without the hash', () {
      final a = parseLinkShareUrl('https://e.com/share/$_hash/auth?view=1');
      final b = parseLinkShareUrl('https://e.com/share/$_hash?view=1');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(parseLinkShareUrl('https://e.com/share/$_hash')));
      expect(a.toString(), isNot(contains(_hash)));
    });
  });

  group('parseInviteLink', () {
    test("the admin's invite: base and token", () {
      final parsed = parseInviteLink(
        'https://tasks.example.com/register#invite-link=$_token',
      )!;

      expect(parsed.base, Uri.parse('https://tasks.example.com/'));
      expect(parsed.token, _token);
    });

    test('a path prefix, a trailing slash, any case, other words', () {
      for (final text in [
        'https://e.com/vikunja/register#invite-link=$_token',
        'https://e.com/vikunja/register/#invite-link=$_token',
        'https://e.com/vikunja/Register#invite-link=$_token',
        'https://e.com/vikunja/register?x=1#invite-link=$_token&y=2',
        'Join us: https://e.com/vikunja/register#invite-link=$_token !',
      ]) {
        final parsed = parseInviteLink(text);
        expect(parsed?.token, _token, reason: text);
        expect(parsed?.base, Uri.parse('https://e.com/vikunja/'), reason: text);
      }
    });

    test('not an invite', () {
      for (final text in [
        '',
        'https://e.com/register',
        'https://e.com/register#invite-link=',
        'https://e.com/register#redirect=/oauth/authorize',
        'https://e.com/login#invite-link=$_token',
        'https://e.com/register?invite-link=$_token',
        'https://e.com/register#invite-link=a%20b',
        'e.com/register#invite-link=$_token',
        'https://e.com/share/${'a' * 40}/auth',
      ]) {
        expect(parseInviteLink(text), isNull, reason: text);
      }
    });

    test('equality, and toString without the token', () {
      final a = parseInviteLink('https://e.com/register#invite-link=$_token');
      final b = parseInviteLink('https://e.com/register/#invite-link=$_token');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), isNot(contains(_token)));
    });
  });
}
