import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

import 'rich_text_json.dart';

// The oracle ran the web editor (TipTap 3.31.3) on window origin, base and
// frontend_url https://vikunja.example.com/ and API root
// https://vikunja.example.com.
final Uri _apiRoot = Uri.parse('https://vikunja.example.com');
final List<Uri> _bases = [
  Uri.parse('https://vikunja.example.com/'),
  Uri.parse('https://vikunja.example.com/'),
];

final Map<String, Object?> _oracle = jsonDecode(
  File('test/fixtures/sanitizer_oracle.json').readAsStringSync(),
) as Map<String, Object?>;

typedef _Difference = ({
  String reason,
  Map<String, Object?> json,
  bool isEmpty,
});

Map<String, Object?> _doc(List<Map<String, Object?>> content) => {
  'type': 'doc',
  'content': content,
};

Map<String, Object?> _paragraph([String? text]) => {
  'type': 'paragraph',
  if (text != null)
    'content': [
      {'type': 'text', 'text': text},
    ],
};

// Vectors whose tree deliberately differs from the web's. Further
// differences are part of the comparison itself (see _normalize): images
// that are neither an attachment nor an absolute http(s) URL are dropped,
// a relative attachment URL counts as this server's, a table cell colour
// is kept only when it parses as a colour, and the attributes the app does
// not use (link target/rel/class/title, ordered list type, cell colwidth,
// task item ids) are not modelled.
final Map<String, _Difference> _differences = {
  'br-only-paragraph': (
    reason: 'a paragraph with only a hard break shows nothing, so it is empty',
    json: _doc([
      {
        'type': 'paragraph',
        'content': [
          {'type': 'hardBreak'},
        ],
      },
    ]),
    isEmpty: true,
  ),
  'link-autolink-on-load-first-block': (
    reason:
        'no autolink on load: TipTap links the last URL of the first '
        'block only by accident and does not store it',
    json: _doc([
      _paragraph('see https://example.com'),
      _paragraph('and https://example.org here'),
    ]),
    isEmpty: false,
  ),
  'math': (
    reason: 'MathML is dropped with its content',
    json: _doc([_paragraph()]),
    isEmpty: true,
  ),
  'form-input-button': (
    reason: 'form controls are dropped with their text',
    json: _doc([_paragraph()]),
    isEmpty: true,
  ),
  'mutation-xss-noscript': (
    reason:
        'package:html parses noscript as raw text (scripting on), so '
        'the img and `">` after the first `</noscript>` are real; the img '
        'is relative and dropped, the text stays as inert text',
    json: _doc([_paragraph('">')]),
    isEmpty: false,
  ),
};

// The vectors that lose an image by the image rule of _normalize.
const _droppedImageVectors = {
  'img-onerror',
  'image-javascript-src',
  'nested-anchor-img-onerror',
};

void main() {
  final vectors = (_oracle['vectors']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final droppedImages = <String>{};

  test('the oracle has 123 vectors', () {
    expect(vectors, hasLength(123));
  });

  group('every oracle vector', () {
    for (final vector in vectors) {
      final id = vector['id']! as String;
      test(id, () {
        final document = parseRichText(
          vector['input']! as String,
          apiRoot: _apiRoot,
          taskLinkBases: _bases,
        );
        final actual = _stripTrailingParagraph(richDocumentJson(document));
        final difference = _differences[id];
        if (difference != null) {
          expect(actual, difference.json, reason: difference.reason);
          expect(document.isEmpty, difference.isEmpty);
          return;
        }
        var lostImage = false;
        final expected = _stripTrailingParagraph(
          _normalize(
            vector['json']! as Map<String, Object?>,
            onDroppedImage: () => lostImage = true,
          )!,
        );
        if (lostImage) droppedImages.add(id);
        expect(actual, expected);
        // A dropped image was the web's only content in these vectors.
        expect(document.isEmpty, lostImage || vector['isEmpty']! as bool);
      });
    }

    test('only the listed vectors lose an image', () {
      expect(droppedImages, _droppedImageVectors);
    });
  });

  group('the task link vectors of taskLink.test.ts', () {
    final upgrades = (_oracle['taskLinkUpgrade']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final vector in upgrades) {
      test(vector['id']! as String, () {
        final document = parseRichText(
          vector['input']! as String,
          apiRoot: Uri.parse('http://localhost:3000'),
          taskLinkBases: [Uri.parse('http://localhost:3000/')],
        );

        final links = richNodes(document).whereType<RichTaskLink>().toList();
        expect(links, hasLength(vector['taskLinkNodes']));
        for (final link in links) {
          expect(link.taskId, 123);
        }
      });
    }
  });
}

/// The oracle's ProseMirror JSON in the terms of [richDocumentJson]; null
/// for a node the parser drops.
Map<String, Object?>? _normalize(
  Map<String, Object?> node, {
  required void Function() onDroppedImage,
}) {
  final type = node['type']! as String;
  final attrs = (node['attrs'] as Map<String, Object?>?) ?? const {};
  List<Object?> children() {
    final normalized = <Map<String, Object?>>[];
    for (final child in (node['content'] as List<Object?>?) ?? const []) {
      final next = _normalize(
        child! as Map<String, Object?>,
        onDroppedImage: onDroppedImage,
      );
      if (next != null) normalized.add(next);
    }
    return normalized;
  }

  Map<String, Object?> build(
    String type, {
    Map<String, Object?>? attrs,
    List<Object?> content = const [],
  }) => {
    'type': type,
    'attrs': ?attrs,
    if (content.isNotEmpty) 'content': content,
  };

  switch (type) {
    case 'text':
      final marks = (node['marks'] as List<Object?>?) ?? const [];
      String? link;
      final names = <String>[];
      for (final mark in marks.cast<Map<String, Object?>>()) {
        if (mark['type'] == 'link') {
          final href = (mark['attrs']! as Map<String, Object?>)['href']!;
          link = 'link ${_cleanUrl(href as String)}';
        } else {
          names.add(mark['type']! as String);
        }
      }
      names.sort();
      return {
        'type': 'text',
        if (link != null || names.isNotEmpty) 'marks': [?link, ...names],
        'text': node['text'],
      };
    case 'hardBreak':
      return {'type': 'hardBreak'};
    case 'mention':
      return build(
        'mention',
        attrs: {'id': attrs['id'] ?? '', 'label': attrs['label'] ?? ''},
      );
    case 'taskLink':
      return build('taskLink', attrs: {'href': attrs['href']});
    case 'heading':
      return build(type, attrs: {'level': attrs['level']}, content: children());
    case 'blockquote':
      return build(
        type,
        attrs: {'commentId': attrs['commentId']},
        content: children(),
      );
    case 'orderedList':
      return build(type, attrs: {'start': attrs['start']}, content: children());
    case 'taskItem':
      return build(
        type,
        attrs: {'checked': attrs['checked']},
        content: children(),
      );
    case 'codeBlock':
      return build(
        type,
        attrs: {'language': attrs['language']},
        content: children(),
      );
    case 'tableHeader' || 'tableCell':
      return build(
        type,
        attrs: {
          'colspan': attrs['colspan'],
          'rowspan': attrs['rowspan'],
          'align': attrs['align'],
          if (type == 'tableCell')
            'backgroundColor': _colour(attrs['backgroundColor'] as String?),
        },
        content: children(),
      );
    case 'image':
      final src = attrs['src']! as String;
      final attachment = parseAttachmentUrl(
        (attrs['data-src'] as String?) ?? src,
        apiRoot: _apiRoot,
      );
      final external = Uri.tryParse(_cleanUrl(src));
      final Map<String, Object?> source;
      if (attachment != null) {
        source = imageSourceJson(RichAttachmentImage(attachment));
      } else if (external != null &&
          (external.scheme == 'http' || external.scheme == 'https') &&
          external.host.isNotEmpty) {
        source = imageSourceJson(RichExternalImage(external));
      } else {
        onDroppedImage();
        return null;
      }
      return build(
        type,
        attrs: {
          ...source,
          'alt': attrs['alt'] ?? '',
          'title': attrs['title'] ?? '',
        },
      );
    default:
      return build(type, content: children());
  }
}

/// TipTap's TrailingNode appends an empty paragraph after a last block that
/// is not a paragraph; the parser does not.
Map<String, Object?> _stripTrailingParagraph(Map<String, Object?> doc) {
  final content = [...?doc['content'] as List<Object?>?];
  if (content.length >= 2) {
    final last = content.last! as Map<String, Object?>;
    final before = content[content.length - 2]! as Map<String, Object?>;
    if (last['type'] == 'paragraph' &&
        last['content'] == null &&
        before['type'] != 'paragraph') {
      content.removeLast();
    }
  }
  return {...doc, 'content': content};
}

String _cleanUrl(String text) => text
    .replaceAll(RegExp(r'^[\x00-\x20]+|[\x00-\x20]+$'), '')
    .replaceAll(RegExp(r'[\t\n\r]'), '');

int? _colour(String? value) {
  if (value == null) return null;
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
  return hex == null ? null : 0xFF000000 | int.parse(hex[1]!, radix: 16);
}
