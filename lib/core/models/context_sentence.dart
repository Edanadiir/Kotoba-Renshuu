class ContextSentence {
  const ContextSentence({required this.en, required this.ja});

  final String en;
  final String ja;

  factory ContextSentence.fromJson(Map<String, dynamic> json) {
    return ContextSentence(
      en: json['en']?.toString() ?? '',
      ja: json['ja']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'en': en, 'ja': ja};
}
