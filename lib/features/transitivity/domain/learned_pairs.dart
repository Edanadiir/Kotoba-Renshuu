import '../../../core/models/assignment.dart';
import '../../../core/models/subject.dart';
import '../../../models/transitivity_pair.dart';

/// Which halves of a pair must already be learned on WaniKani.
enum LearnedRequirement { both, either }

/// Characters of vocabulary the user has actually started (passed the
/// lesson stage). Assignments that are only unlocked, with no `started_at`,
/// do not count.
Set<String> learnedVocabulary(
  Iterable<Subject> subjects,
  Iterable<Assignment> assignments,
) {
  final startedSubjectIds = {
    for (final assignment in assignments)
      if (assignment.startedAt != null ||
          assignment.passedAt != null ||
          assignment.burnedAt != null)
        assignment.subjectId,
  };
  return {
    for (final subject in subjects)
      if (subject.type == SubjectType.vocabulary &&
          startedSubjectIds.contains(subject.id))
        subject.characters,
  };
}

/// Pairs whose verbs are learned according to [requirement]. A verb that
/// has no matching WaniKani vocabulary subject counts as not learned.
List<TransitivityPair> filterLearnedPairs(
  Iterable<TransitivityPair> pairs,
  Set<String> learned,
  LearnedRequirement requirement,
) => [
  for (final pair in pairs)
    if (requirement == LearnedRequirement.both
        ? learned.contains(pair.transitiveKanji) &&
              learned.contains(pair.intransitiveKanji)
        : learned.contains(pair.transitiveKanji) ||
              learned.contains(pair.intransitiveKanji))
      pair,
];
