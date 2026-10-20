class TransitivityPair {
  const TransitivityPair({
    required this.id,
    required this.transitiveKanji,
    required this.transitiveKana,
    required this.transitiveMeaning,
    required this.intransitiveKanji,
    required this.intransitiveKana,
    required this.intransitiveMeaning,
    this.wkLevel,
    this.rulePattern,
    this.transitiveExample,
    this.intransitiveExample,
    this.transitiveExampleMeaning,
    this.intransitiveExampleMeaning,
  });

  final String id;
  final String transitiveKanji;
  final String transitiveKana;
  final String transitiveMeaning;
  final String intransitiveKanji;
  final String intransitiveKana;
  final String intransitiveMeaning;
  final int? wkLevel;
  final String? rulePattern;

  /// Short natural phrase using the transitive verb, e.g. "仕事を終える".
  final String? transitiveExample;

  /// Short natural phrase using the intransitive verb, e.g. "授業が終わる".
  final String? intransitiveExample;

  /// English translation of [transitiveExample], e.g. "to finish work".
  final String? transitiveExampleMeaning;

  /// English translation of [intransitiveExample], e.g. "the class ends".
  final String? intransitiveExampleMeaning;

  String get transitiveDisplay => transitiveKanji == transitiveKana
      ? transitiveKana
      : '$transitiveKanji ($transitiveKana)';
  String get intransitiveDisplay => intransitiveKanji == intransitiveKana
      ? intransitiveKana
      : '$intransitiveKanji ($intransitiveKana)';
}
