enum OnomatopoeiaCategory {
  giseigoGiongo('Giseigo / Giongo', 'Actual sounds'),
  gitaigo('Gitaigo', 'Manners & conditions'),
  gijogo('Gijōgo', 'Feelings & states');

  const OnomatopoeiaCategory(this.label, this.description);

  final String label;
  final String description;
}

class OnomatopoeiaItem {
  const OnomatopoeiaItem({
    required this.id,
    required this.word,
    required this.category,
    required this.sentenceKanji,
    required this.sentenceKana,
    required this.correctOption,
    required this.options,
    required this.englishSentence,
    required this.wordMeaning,
    required this.explanation,
  });

  static const blank = '___';

  final String id;
  final String word;
  final OnomatopoeiaCategory category;

  /// Sentence with exactly one [blank] marker.
  final String sentenceKanji;

  /// Full kana reading of the sentence, with the same [blank].
  final String sentenceKana;
  final String correctOption;

  /// Four choices from the same category, including [correctOption].
  final List<String> options;
  final String englishSentence;
  final String wordMeaning;
  final String explanation;

  String get filledSentence => sentenceKanji.replaceFirst(blank, correctOption);

  String get filledKana => sentenceKana.replaceFirst(blank, correctOption);

  /// Text before and after the blank in the kanji sentence.
  (String, String) get sentenceParts => _split(sentenceKanji);

  /// Text before and after the blank in the kana sentence.
  (String, String) get kanaParts => _split(sentenceKana);

  static (String, String) _split(String text) {
    final index = text.indexOf(blank);
    return (text.substring(0, index), text.substring(index + blank.length));
  }
}
