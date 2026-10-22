// package:html offers no other way to watch its tokenizer and tree builder.
// ignore_for_file: implementation_imports

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html/src/constants.dart' show specialElements;
import 'package:html/src/token.dart' show ParseErrorToken, StartTagToken;
import 'package:html/src/tokenizer.dart' show HtmlTokenizer;
import 'package:html/src/treebuilder.dart' show TreeBuilder;

/// The entries package:html walks in its stack of open elements and in its
/// list of active formatting elements: most tokens walk the stack, so deep
/// nesting takes quadratic time, and a formatting element walks the list,
/// comparing attributes with those of its entries.
const int maxListWalk = 1 << 24;

/// The most elements open at once, `<html>` and `<body>` included:
/// package:html serialises and reads text recursively.
const int maxOpenElements = 1024;

/// The elements a document creates, including those package:html reopens
/// before each text and clones in the adoption agency.
const int maxElements = 1 << 18;

/// The characters of attribute names and values over all elements created:
/// a reopened or cloned formatting element copies its attributes.
const int maxAttributeText = 1 << 24;

/// The sibling positions package:html searches to move nodes: it puts
/// markup placed straight into a table before that table, and the adoption
/// agency moves a block's children one by one.
const int maxSiblingSearch = 1 << 28;

/// `html_parser.parse` within the limits above. At the first token past one
/// it stops and returns the document built until then as not `complete`.
({dom.Document document, bool complete}) parseBoundedHtml(String source) {
  final tree = _BoundedTreeBuilder();
  try {
    html_parser.HtmlParser(
      _BoundedTokenizer(source, tree),
      tree: tree,
      generateSpans: true,
    ).parse();
    return (document: tree.document, complete: true);
  } on _LimitReached {
    return (document: tree.document, complete: false);
  }
}

final class _LimitReached implements Exception {
  const new();
}

const _formattingElements = {
  'a',
  'b',
  'big',
  'code',
  'em',
  'font',
  'i',
  'nobr',
  's',
  'small',
  'strike',
  'strong',
  'tt',
  'u',
};

final Set<int> _decimalDigits = {
  for (var unit = 0x30; unit <= 0x39; unit++) unit,
};
final Set<int> _hexDigits = {
  ..._decimalDigits,
  for (var unit = 0x41; unit <= 0x46; unit++) ...[unit, unit + 0x20],
};

final class _BoundedTokenizer extends HtmlTokenizer {
  new(String super.doc, this._tree) : super(generateSpans: true);

  final _BoundedTreeBuilder _tree;

  @override
  bool moveNext() {
    final more = super.moveNext();
    if (more && current is! ParseErrorToken) _tree.startToken();
    return more;
  }

  // package:html reads the number with int.parse, which throws past 64 bits.
  @override
  String consumeNumberEntity(bool isHex) {
    final digits = isHex ? _hexDigits : _decimalDigits;
    final number = stream.charsUntil(digits, true);
    if (int.tryParse(number, radix: isHex ? 16 : 10) != null) {
      for (var i = number.length - 1; i >= 0; i--) {
        stream.unget(number[i]);
      }
      return super.consumeNumberEntity(isHex);
    }
    if (stream.peekCodeUnit() == 0x3b) stream.char();
    return '�';
  }
}

final class _BoundedTreeBuilder extends TreeBuilder {
  new() : super(true);

  var _listWalk = 0;
  var _elements = 0;
  var _attributeText = 0;
  var _siblingSearch = 0;
  dom.Element? _adopted;

  void startToken() {
    _adopted = null;
    _listWalk += openElements.length;
    _stopPastLimits();
  }

  @override
  dom.Element insertElement(StartTagToken token) {
    if (openElements.length >= maxOpenElements) throw const _LimitReached();
    _elements++;
    _attributeText += _textOf(token.data);
    if (_formattingElements.contains(token.name)) {
      _listWalk += activeFormattingElements.length * (1 + token.data.length);
    }
    _stopPastLimits();
    return super.insertElement(token);
  }

  // Not stopped here: the adoption agency calls this while a node it moves
  // is out of the tree.
  @override
  List<dom.Node?> getTableMisnestedNodePosition() {
    final position = super.getTableMisnestedNodePosition();
    _siblingSearch += position.first!.nodes.length;
    return position;
  }

  // Called before each round of the adoption agency and for each `a` start
  // tag, which go on to search the whole list. The `a` start tag runs the
  // round it looked up.
  @override
  dom.Element? elementInActiveFormattingElements(String? name) {
    _listWalk += openElements.length + activeFormattingElements.length;
    final element = super.elementInActiveFormattingElements(name);
    if (element != null && !identical(element, _adopted)) {
      _adopted = element;
      _chargeAdoption(element);
    }
    _stopPastLimits();
    return element;
  }

  // A round of the adoption agency that goes ahead takes nodes out of their
  // parents, moves the children of the furthest
  // block (the first special element opened after the formatting element)
  // one by one, and clones the formatting element and those of the three
  // elements under the furthest block that are formatting elements too.
  void _chargeAdoption(dom.Element formatting) {
    final index = openElements.lastIndexOf(formatting);
    if (index >= 0 && elementInScope(formatting.localName)) {
      for (var block = index + 1; block < openElements.length; block++) {
        final furthestBlock = openElements[block];
        if (!specialElements.contains(
          html_parser.getElementNameTuple(furthestBlock),
        )) {
          continue;
        }
        final children = furthestBlock.nodes.length;
        _siblingSearch += children * children ~/ 2;
        final under = block - 3 > index ? block - 3 : index + 1;
        for (final element in [
          formatting,
          ...openElements.sublist(under, block),
        ]) {
          _siblingSearch += element.nodes.length;
          if (element == formatting ||
              activeFormattingElements.contains(element)) {
            _elements++;
            _attributeText += _textOf(element.attributes);
          }
        }
        break;
      }
    }
  }

  void _stopPastLimits() {
    if (_listWalk > maxListWalk ||
        _elements > maxElements ||
        _attributeText > maxAttributeText ||
        _siblingSearch > maxSiblingSearch) {
      throw const _LimitReached();
    }
  }
}

int _textOf(Map<Object, String> attributes) {
  var length = 0;
  for (final MapEntry(:key, :value) in attributes.entries) {
    length += key.toString().length + value.length;
  }
  return length;
}
