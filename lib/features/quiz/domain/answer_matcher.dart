class AnswerMatcher {
  const AnswerMatcher._();

  static bool matches(
    String expected,
    String actual, {
    bool allowTypo = false,
  }) {
    final normalizedExpected = normalize(expected);
    final normalizedActual = normalize(actual);
    if (normalizedExpected == normalizedActual) return true;
    if (!allowTypo || normalizedExpected.length < 3) return false;
    final tolerance = normalizedExpected.length >= 6 ? 2 : 1;
    return _distance(normalizedExpected, normalizedActual) <= tolerance;
  }

  static String normalize(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll("'", '')
        .replaceAll('’', '')
        .replaceAll(RegExp(r'[.,!?;:()\[\]{}"-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return cleaned;

    final words = cleaned.split(' ');
    final normalizedWords = <String>[];
    for (var index = 0; index < words.length;) {
      final parsed = _parseNumberWords(words, index);
      if (parsed == null) {
        normalizedWords.add(words[index]);
        index++;
      } else {
        normalizedWords.add(parsed.value.toString());
        index = parsed.nextIndex;
      }
    }
    return normalizedWords.join(' ');
  }

  static _ParsedNumber? _parseNumberWords(List<String> words, int start) {
    var total = 0;
    var current = 0;
    var index = start;
    var foundNumber = false;
    var canAppendUnit = false;

    while (index < words.length) {
      final word = words[index];
      final small = _smallNumbers[word];
      if (small != null) {
        if (foundNumber && current % 100 != 0 && !canAppendUnit) break;
        current += small;
        foundNumber = true;
        canAppendUnit = false;
        index++;
        continue;
      }

      final tens = _tensNumbers[word];
      if (tens != null) {
        if (canAppendUnit || (foundNumber && current % 100 != 0)) break;
        current += tens;
        foundNumber = true;
        canAppendUnit = true;
        index++;
        continue;
      }

      if (word == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        foundNumber = true;
        canAppendUnit = false;
        index++;
        continue;
      }

      if (word == 'thousand') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        foundNumber = true;
        canAppendUnit = false;
        index++;
        continue;
      }

      if (word == 'and' &&
          foundNumber &&
          index + 1 < words.length &&
          _isNumberWord(words[index + 1])) {
        index++;
        continue;
      }
      break;
    }

    return foundNumber ? _ParsedNumber(total + current, index) : null;
  }

  static bool _isNumberWord(String word) =>
      _smallNumbers.containsKey(word) ||
      _tensNumbers.containsKey(word) ||
      word == 'hundred' ||
      word == 'thousand';

  static const _smallNumbers = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  };

  static const _tensNumbers = <String, int>{
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  static int _distance(String left, String right) {
    final row = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      var previous = row[0];
      row[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final current = row[j + 1];
        row[j + 1] = left[i] == right[j]
            ? previous
            : 1 +
                  [
                    previous,
                    row[j],
                    row[j + 1],
                  ].reduce((a, b) => a < b ? a : b);
        previous = current;
      }
    }
    return row.last;
  }
}

class _ParsedNumber {
  const _ParsedNumber(this.value, this.nextIndex);

  final int value;
  final int nextIndex;
}
