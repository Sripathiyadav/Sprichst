/// A deliberately small Markdown reader for the documents in `legal/`.
///
/// It understands what those documents use and nothing more: headings, paragraphs,
/// bullet and numbered lists, tables, horizontal rules, and the inline forms
/// `**bold**`, `` `code` `` and `[[PLACEHOLDER]]`. Keeping it here, in plain
/// Dart, means no Markdown package (and nothing that could fetch a remote
/// image or follow a link) ships in the app.
library;

/// A run of text inside a block.
class MdSpan {
  const MdSpan(this.text,
      {this.bold = false, this.code = false, this.placeholder = false});

  final String text;
  final bool bold;
  final bool code;

  /// An unfilled `[[FIELD]]`; the viewer highlights these so none ships unnoticed.
  final bool placeholder;

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.code == code &&
      other.placeholder == placeholder;

  @override
  int get hashCode => Object.hash(text, bold, code, placeholder);

  @override
  String toString() =>
      'MdSpan($text${bold ? ', bold' : ''}${code ? ', code' : ''}'
      '${placeholder ? ', placeholder' : ''})';
}

sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.spans);
  final int level;
  final List<MdSpan> spans;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);
  final List<MdSpan> spans;
}

class MdListItem extends MdBlock {
  const MdListItem(this.marker, this.spans);

  /// `•` for bullets, `1.` for numbered items.
  final String marker;
  final List<MdSpan> spans;
}

class MdTable extends MdBlock {
  const MdTable(this.headers, this.rows);
  final List<List<MdSpan>> headers;
  final List<List<List<MdSpan>>> rows;
}

class MdRule extends MdBlock {
  const MdRule();
}

final _heading = RegExp(r'^(#{1,4})\s+(.*)$');
final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
final _numbered = RegExp(r'^\s*(\d+)\.\s+(.*)$');
final _tableSeparator =
    RegExp(r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$');

List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(MdParagraph(parseInline(paragraph.join('\n'))));
    paragraph.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flush();
      i++;
      continue;
    }

    final heading = _heading.firstMatch(trimmed);
    if (heading != null) {
      flush();
      blocks.add(MdHeading(
          heading.group(1)!.length, parseInline(heading.group(2)!.trim())));
      i++;
      continue;
    }

    if (RegExp(r'^(-{3,}|\*{3,})$').hasMatch(trimmed)) {
      flush();
      blocks.add(const MdRule());
      i++;
      continue;
    }

    if (trimmed.startsWith('|') &&
        i + 1 < lines.length &&
        _tableSeparator.hasMatch(lines[i + 1])) {
      flush();
      final headers = _cells(trimmed);
      i += 2;
      final rows = <List<List<MdSpan>>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(_cells(lines[i].trim()));
        i++;
      }
      blocks.add(MdTable(headers, rows));
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      flush();
      blocks.add(MdListItem('•', parseInline(bullet.group(1)!.trim())));
      i++;
      continue;
    }

    final numbered = _numbered.firstMatch(line);
    if (numbered != null) {
      flush();
      blocks.add(MdListItem(
          '${numbered.group(1)}.', parseInline(numbered.group(2)!.trim())));
      i++;
      continue;
    }

    paragraph.add(trimmed);
    i++;
  }
  flush();
  return blocks;
}

List<List<MdSpan>> _cells(String row) {
  var body = row.trim();
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return [for (final cell in body.split('|')) parseInline(cell.trim())];
}

final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[\[([^\]]+)\]\]');

List<MdSpan> parseInline(String text) {
  final spans = <MdSpan>[];
  var cursor = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(MdSpan(text.substring(cursor, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(MdSpan(match.group(1)!, bold: true));
    } else if (match.group(2) != null) {
      spans.add(MdSpan(match.group(2)!, code: true));
    } else {
      spans.add(MdSpan('[[${match.group(3)!}]]', placeholder: true));
    }
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(MdSpan(text.substring(cursor)));
  return spans;
}

/// The plain text of [spans], for tests and accessibility labels.
String plainText(List<MdSpan> spans) => spans.map((s) => s.text).join();
