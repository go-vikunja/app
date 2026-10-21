import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_text_controller.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna Lee');
const _ben = User(id: 10, username: 'ben');

void main() {
  group('CommentTextController', () {
    CommentTextController at(String text, [int? cursor]) {
      final controller = CommentTextController()
        ..value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        );
      addTearDown(controller.dispose);
      return controller;
    }

    test('an @ query starts at the start or after a space and has no '
        'space', () {
      expect(at('@').activeMention(), (at: 0, query: ''));
      expect(at('Hi @an').activeMention(), (at: 3, query: 'an'));
      expect(at('Hi\n@an').activeMention(), (at: 3, query: 'an'));
      expect(at('mail a@b').activeMention(), isNull);
      expect(at('@an na').activeMention(), isNull);
      expect(at('Hi @an later', 6).activeMention(), (at: 3, query: 'an'));
      final selected = at('Hi @an')
        ..selection = const TextSelection(baseOffset: 3, extentOffset: 6);
      expect(selected.activeMention(), isNull);
    });

    test('a person picked replaces the query, with a space after', () {
      final controller = at('Hi @an, ok', 6)..insertMention(_anna, at: 3);

      expect(controller.text, 'Hi @Anna Lee , ok');
      expect(controller.selection, const TextSelection.collapsed(offset: 13));
      expect(controller.mentions, [
        const ComposerMention(start: 3, end: 12, user: _anna),
      ]);
      // Inside a mention there is no new query.
      controller.selection = const TextSelection.collapsed(offset: 5);
      expect(controller.activeMention(), isNull);
    });

    test('an existing space after the query is used', () {
      final controller = at('@b x', 2)..insertMention(_ben, at: 0);

      expect(controller.text, '@ben x');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });

    test('typing before a mention moves it, typing in it makes it text', () {
      final controller = at('@an')..insertMention(_anna, at: 0);
      expect(controller.mentions.single.start, 0);

      controller.value = const TextEditingValue(text: 'Hey @Anna Lee ');
      expect(controller.mentions.single.start, 4);
      expect(controller.mentions.single.end, 13);

      controller.value = const TextEditingValue(text: 'Hey @Anna Lee and ');
      expect(controller.mentions, hasLength(1));

      controller.value = const TextEditingValue(text: 'Hey @Ana Lee and ');
      expect(controller.mentions, isEmpty);
    });

    test('clearing drops the mentions; a restore keeps only valid ones', () {
      final controller = at('@an')
        ..insertMention(_anna, at: 0)
        ..clear();
      expect(controller.mentions, isEmpty);

      controller.restore('@Anna Lee hi', const [
        ComposerMention(start: 0, end: 9, user: _anna),
        ComposerMention(start: 8, end: 40, user: _ben),
      ]);
      expect(controller.mentions, [
        const ComposerMention(start: 0, end: 9, user: _anna),
      ]);
      expect(controller.selection.baseOffset, 12);
    });
  });

  group('CommentComposerController', () {
    CommentComposerController create() {
      final controller = CommentComposerController();
      addTearDown(controller.dispose);
      return controller;
    }

    test("the HTML is the web's, with the mentions and the reply", () {
      final composer = create()
        ..text.value = const TextEditingValue(
          text: 'Ask @an',
          selection: TextSelection.collapsed(offset: 7),
        );
      composer.text.insertMention(_anna, at: 4);
      composer.text.value = TextEditingValue(
        text: '${composer.text.text}\nthanks',
        selection: const TextSelection.collapsed(offset: 0),
      );
      composer.replyTo(
        const ComposerReply(
          commentId: 3,
          html: '<p>Earlier</p>',
          authorName: 'Ben',
        ),
      );

      expect(
        composer.html(),
        commentHtmlFromText(
          'Ask @Anna Lee \nthanks',
          mentions: const [
            MentionSpan(start: 4, end: 13, username: 'anna', label: 'Anna Lee'),
          ],
          reply: const QuotedComment(id: 3, html: '<p>Earlier</p>'),
        ),
      );
      expect(composer.html(), contains('data-id="anna"'));
      expect(composer.html(), startsWith('<blockquote data-comment-id="3">'));
    });

    test('blank, empty and the draft round trip', () {
      final composer = create();
      expect(composer.isBlank, isTrue);
      expect(composer.isEmpty, isTrue);

      composer.text.text = ' \n ';
      expect(composer.isBlank, isTrue);
      composer.replyTo(
        const ComposerReply(commentId: 3, html: '<p>x</p>', authorName: 'Ben'),
      );
      expect(composer.isEmpty, isFalse);

      composer.text.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      composer.text.insertMention(_anna, at: 0);
      final draft = composer.toDraft();
      expect(
        draft,
        const CommentComposerDraft(
          text: '@Anna Lee ',
          mentions: [(start: 0, end: 9, username: 'anna', label: 'Anna Lee')],
          reply: (commentId: 3, author: 'Ben', html: '<p>x</p>'),
        ),
      );

      final restored = create()..restore(draft);
      expect(restored.toDraft(), draft);
      expect(restored.html(), composer.html());

      restored.clear();
      expect(restored.isEmpty, isTrue);
    });
  });
}
