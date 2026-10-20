class QuizConfig {
  const QuizConfig({
    this.revealOnSecondMiss = true,
    this.showOther = true,
    this.showEnglishByDefault = false,
  });

  final bool revealOnSecondMiss;
  final bool showOther;
  final bool showEnglishByDefault;

  Map<String, bool> toJson() => {
    'reveal_on_second_miss': revealOnSecondMiss,
    'show_other': showOther,
    'show_english_by_default': showEnglishByDefault,
  };

  factory QuizConfig.fromJson(Map<String, dynamic>? json) => QuizConfig(
    revealOnSecondMiss: json?['reveal_on_second_miss'] as bool? ?? true,
    showOther: json?['show_other'] as bool? ?? true,
    showEnglishByDefault: json?['show_english_by_default'] as bool? ?? false,
  );
}
