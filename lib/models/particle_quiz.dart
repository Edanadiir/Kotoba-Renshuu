enum JlptLevel { n5, n4 }

class ParticleQuestion {
  const ParticleQuestion({
    required this.id,
    required this.sentenceWithBlank,
    required this.sentenceKana,
    required this.correctParticle,
    required this.options,
    required this.englishTranslation,
    required this.explanation,
    required this.jlptLevel,
  });

  static const blank = '___';

  final String id;

  /// Sentence containing exactly one [blank] marker.
  final String sentenceWithBlank;

  /// Full hiragana/katakana reading of the sentence, with the same [blank].
  final String sentenceKana;
  final String correctParticle;

  /// Four choices, including [correctParticle].
  final List<String> options;
  final String englishTranslation;
  final String explanation;
  final JlptLevel jlptLevel;

  String get filledSentence =>
      sentenceWithBlank.replaceFirst(blank, correctParticle);

  String get filledKana => sentenceKana.replaceFirst(blank, correctParticle);

  /// Kana text before and after the blank.
  (String, String) get kanaParts {
    final index = sentenceKana.indexOf(blank);
    return (
      sentenceKana.substring(0, index),
      sentenceKana.substring(index + blank.length),
    );
  }

  /// Text before and after the blank.
  (String, String) get sentenceParts {
    final index = sentenceWithBlank.indexOf(blank);
    return (
      sentenceWithBlank.substring(0, index),
      sentenceWithBlank.substring(index + blank.length),
    );
  }
}
