import 'subject.dart';

enum QuestionKind { meaning, reading, onyomi, kunyomi }

extension QuestionKindJson on QuestionKind {
  String get value => name;

  static QuestionKind fromValue(String? value) =>
      QuestionKind.values.where((kind) => kind.name == value).firstOrNull ??
      QuestionKind.meaning;
}

class QuizItem {
  const QuizItem({required this.id, required this.subject, required this.kind});

  final String id;
  final Subject subject;
  final QuestionKind kind;

  String get prompt => subject.characters;

  List<String> get acceptedAnswers => switch (kind) {
    QuestionKind.meaning => subject.meanings,
    QuestionKind.reading =>
      subject.type == SubjectType.radical ? const [] : subject.readings,
    QuestionKind.onyomi => subject.readingsFor('onyomi'),
    QuestionKind.kunyomi => subject.readingsFor('kunyomi'),
  };

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      id: json['id']?.toString() ?? '',
      subject: Subject.fromJson(json['subject'] as Map<String, dynamic>),
      kind: QuestionKindJson.fromValue(json['kind']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.value,
    'subject': subject.toJson(),
  };
}
