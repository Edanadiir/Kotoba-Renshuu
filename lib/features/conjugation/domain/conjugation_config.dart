import '../data/conjugation_dictionary.dart';
import 'conjugation_engine.dart';
import 'conjugation_models.dart';

enum ConjugationInputMode { typing, multipleChoice }

class ConjugationQuestion {
  const ConjugationQuestion(this.entry, this.form);
  final VocabEntry entry;
  final ConjugationForm form;

  @override
  bool operator ==(Object other) =>
      other is ConjugationQuestion &&
      other.entry == entry &&
      other.form == form;

  @override
  int get hashCode => Object.hash(entry, form);
}

class ConjugationConfig {
  const ConjugationConfig({
    required this.groups,
    required this.forms,
    required this.inputMode,
    required this.sessionSize,
  });

  final Set<WordGroup> groups;
  final Set<ConjugationForm> forms;
  final ConjugationInputMode inputMode;

  /// Number of cards; 0 means endless.
  final int sessionSize;

  bool get endless => sessionSize == 0;

  /// All distinct (word, form) combinations that match the filters.
  List<ConjugationQuestion> buildPool() => [
    for (final entry in conjugationDictionary)
      if (groups.contains(entry.group))
        for (final form in forms)
          if (ConjugationEngine.isApplicable(entry, form))
            ConjugationQuestion(entry, form),
  ];
}
