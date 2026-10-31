import 'package:flutter_test/flutter_test.dart';
import 'package:kotoba_renshuu/core/models/assignment.dart';
import 'package:kotoba_renshuu/core/models/subject.dart';
import 'package:kotoba_renshuu/features/transitivity/domain/learned_pairs.dart';
import 'package:kotoba_renshuu/models/transitivity_pairs.dart';

Subject vocab(int id, String characters, {SubjectType? type}) => Subject(
  id: id,
  type: type ?? SubjectType.vocabulary,
  level: 1,
  characters: characters,
  meanings: const [],
  readings: const [],
);

Assignment assignment(int subjectId, {DateTime? startedAt}) => Assignment(
  id: subjectId,
  subjectId: subjectId,
  srsStage: SrsStage.apprentice,
  unlockedAt: DateTime(2024),
  startedAt: startedAt,
);

void main() {
  final subjects = [
    vocab(1, '開ける'),
    vocab(2, '開く'),
    vocab(3, '閉める'),
    vocab(4, '閉まる', type: SubjectType.kanji),
  ];
  final assignments = [
    assignment(1, startedAt: DateTime(2024, 2)),
    assignment(2, startedAt: DateTime(2024, 2)),
    assignment(3), // unlocked but lesson not taken
    assignment(4, startedAt: DateTime(2024, 2)),
  ];

  test('only started vocabulary counts as learned', () {
    expect(learnedVocabulary(subjects, assignments), {'開ける', '開く'});
  });

  test('both vs either requirement', () {
    final learned = learnedVocabulary(subjects, assignments);
    final both = filterLearnedPairs(
      transitivityPairs,
      learned,
      LearnedRequirement.both,
    );
    expect(both.map((p) => p.transitiveKanji), ['開ける']);

    learned.add('閉める');
    final either = filterLearnedPairs(
      transitivityPairs,
      learned,
      LearnedRequirement.either,
    );
    expect(either.map((p) => p.transitiveKanji), contains('閉める'));
    expect(
      filterLearnedPairs(
        transitivityPairs,
        learned,
        LearnedRequirement.both,
      ).map((p) => p.transitiveKanji),
      isNot(contains('閉める')),
    );
  });
}
