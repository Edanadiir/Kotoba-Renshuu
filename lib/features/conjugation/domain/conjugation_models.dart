enum WordGroup {
  godan('Godan verbs (五段)', 'Godan verb', true),
  ichidan('Ichidan verbs (一段)', 'Ichidan verb', true),
  irregular('Irregular verbs (する / くる)', 'Irregular verb', true),
  iAdjective('I-adjectives (い形容詞)', 'I-adjective', false),
  naAdjective('Na-adjectives (な形容詞)', 'Na-adjective', false);

  const WordGroup(this.title, this.shortLabel, this.isVerb);
  final String title;
  final String shortLabel;
  final bool isVerb;
}

enum ConjugationForm {
  plainPresent('Plain Present'),
  plainPast('Plain Past'),
  plainNegative('Plain Negative'),
  politePresent('Polite Present'),
  politePast('Polite Past'),
  politeNegative('Polite Negative'),
  te('Te-form (て形)'),
  potential('Potential (れる)'),
  passive('Passive'),
  causative('Causative'),
  volitional('Volitional (よう)'),
  tai('Tai-form (たい)'),
  conditionalBa('Conditional (ば)'),
  conditionalTara('Conditional (たら)');

  const ConjugationForm(this.label);
  final String label;

  bool get verbOnly => switch (this) {
    potential || passive || causative || volitional || tai => true,
    _ => false,
  };

  bool appliesTo(WordGroup group) => group.isVerb || !verbOnly;
}

/// A selectable chip in the setup screen; may cover several forms.
class FormChoice {
  const FormChoice(this.label, this.forms);
  final String label;
  final List<ConjugationForm> forms;
}

const formChoices = <FormChoice>[
  FormChoice('Plain Present', [ConjugationForm.plainPresent]),
  FormChoice('Plain Past', [ConjugationForm.plainPast]),
  FormChoice('Plain Negative', [ConjugationForm.plainNegative]),
  FormChoice('Polite Present', [ConjugationForm.politePresent]),
  FormChoice('Polite Past', [ConjugationForm.politePast]),
  FormChoice('Polite Negative', [ConjugationForm.politeNegative]),
  FormChoice('Te-form (て形)', [ConjugationForm.te]),
  FormChoice('Potential (ható)', [ConjugationForm.potential]),
  FormChoice('Passive & Causative', [
    ConjugationForm.passive,
    ConjugationForm.causative,
  ]),
  FormChoice('Volitional / Tai-form', [
    ConjugationForm.volitional,
    ConjugationForm.tai,
  ]),
  FormChoice('Conditional (ば / たら)', [
    ConjugationForm.conditionalBa,
    ConjugationForm.conditionalTara,
  ]),
];

class VocabEntry {
  const VocabEntry(this.kanji, this.kana, this.meaning, this.group);

  /// Written form; equals [kana] for words normally written without kanji.
  final String kanji;
  final String kana;
  final String meaning;
  final WordGroup group;

  bool get hasKanji => kanji != kana;
}

class ConjugationResult {
  const ConjugationResult({
    required this.kana,
    required this.kanji,
    required this.explanation,
    this.alternativesKana = const [],
    this.alternativesKanji = const [],
  });

  /// Primary answer in kana.
  final String kana;

  /// Primary answer with kanji (same as [kana] if the word has none).
  final String kanji;
  final String explanation;
  final List<String> alternativesKana;
  final List<String> alternativesKanji;

  Set<String> get acceptedKana => {kana, ...alternativesKana};

  Set<String> get acceptedAnswers => {
    kana,
    kanji,
    ...alternativesKana,
    ...alternativesKanji,
  };

  /// Accepted answers other than the primary kana / kanji ones.
  List<String> get alternatives => {
    ...alternativesKana,
    ...alternativesKanji,
  }.where((value) => value != kana && value != kanji).toList();
}
