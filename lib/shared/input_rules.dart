/// Limits for text that leaves a screen: typed into the coach, saved in a
/// profile, or sent to the AI server.
///
/// The same numbers are enforced on the other side of each boundary: the
/// gateway's request models (`ai-server/app/security.py`) and the Firestore
/// rules (`firebase/firestore.rules`). Checking here as well means a learner
/// gets a sensible result instead of a rejected request.
abstract final class InputLimits {
  /// A coach message or a text to be spoken (gateway: `Message`).
  static const message = 1500;

  /// The learner's name (Firestore rules allow 60; the form allows 40).
  static const name = 40;

  /// A skill label or vocabulary word (gateway: `Short`).
  static const short = 60;

  /// A unit or lesson title, a mistake summary (gateway: `Medium`).
  static const medium = 120;

  static const weakSkills = 8;
  static const vocabulary = 30;
  static const mistakes = 10;
}

// Control characters other than tab and newline, and invisible characters that
// can reorder or hide text (zero-width, bidirectional overrides, BOM). Written
// as code-point ranges so no invisible character appears in this source file.
bool _isUnwanted(int c) =>
    (c <= 0x08) ||
    c == 0x0B ||
    c == 0x0C ||
    (c >= 0x0E && c <= 0x1F) ||
    (c >= 0x7F && c <= 0x9F) ||
    (c >= 0x200B && c <= 0x200F) || // zero-width and direction marks
    (c >= 0x202A && c <= 0x202E) || // bidirectional embeddings and overrides
    (c >= 0x2060 && c <= 0x2064) || // word joiner and invisible operators
    c == 0xFEFF; // byte-order mark

String _withoutUnwanted(String text) =>
    String.fromCharCodes(text.runes.where((c) => !_isUnwanted(c)));

final _manyBlankLines = RegExp(r'\n{4,}');

/// Cleans [input] for sending or storing: removes control and invisible
/// characters, trims, and cuts it to [maxLength] characters without splitting
/// an emoji or other character made of two UTF-16 units.
String sanitizeText(String input, {int maxLength = InputLimits.message}) {
  var text =
      _withoutUnwanted(input).replaceAll(_manyBlankLines, '\n\n\n').trim();
  if (text.length > maxLength) {
    var end = maxLength;
    final unit = text.codeUnitAt(end - 1);
    final splitsPair = unit >= 0xD800 && unit <= 0xDBFF; // a lone high half
    if (splitsPair) end--;
    text = text.substring(0, end).trimRight();
  }
  return text;
}

/// A display name: one line, single spaces.
String sanitizeName(String input) => sanitizeText(
      input.replaceAll(RegExp(r'\s+'), ' '),
      maxLength: InputLimits.name,
    );

/// Keeps at most [max] items, each cleaned and cut to [maxLength]; empty items
/// are dropped.
List<String> sanitizeList(
  Iterable<String> items, {
  required int max,
  required int maxLength,
}) =>
    [
      for (final item in items)
        if (sanitizeText(item, maxLength: maxLength) case final clean
            when clean.isNotEmpty)
          clean,
    ].take(max).toList();
