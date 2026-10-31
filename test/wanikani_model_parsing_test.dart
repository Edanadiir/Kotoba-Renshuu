import 'package:flutter_test/flutter_test.dart';

import 'package:kotoba_renshuu/core/models/assignment.dart';
import 'package:kotoba_renshuu/core/models/subject.dart';
import 'package:kotoba_renshuu/core/models/user.dart';

void main() {
  test('parses WaniKani numeric subject fields', () {
    final subject = Subject.fromJson({
      'id': 123,
      'object': 'kanji',
      'data': {
        'level': 12,
        'characters': '学',
        'meanings': [
          {'meaning': 'Study'},
        ],
        'readings': [
          {
            'reading': 'がく',
            'type': 'onyomi',
            'accepted_answer': true,
            'primary': true,
          },
          {
            'reading': 'まなぶ',
            'type': 'kunyomi',
            'accepted_answer': true,
            'primary': false,
          },
        ],
        'visually_similar_subject_ids': [124, 125],
        'pronunciation_audios': [
          {
            'url': 'https://files.wanikani.com/eeu2zfeuqf3uiij9k5xf9nmxs4r2',
            'content_type': 'audio/mpeg',
            'metadata': {
              'gender': 'female',
              'voice_actor_id': 1,
              'voice_actor_name': 'Kyoko',
            },
          },
          {
            'url': 'https://files.wanikani.com/another-extensionless-audio',
            'content_type': 'audio/mpeg',
            'metadata': {
              'gender': 'male',
              'voice_actor_id': 2,
              'voice_actor_name': 'Kenichi',
            },
          },
        ],
      },
    });

    expect(subject.id, 123);
    expect(subject.level, 12);
    expect(subject.visuallySimilarSubjectIds, [124, 125]);
    expect(subject.readingsFor('onyomi'), ['がく']);
    expect(subject.readingsFor('kunyomi'), ['まなぶ']);
    final restoredSubject = Subject.fromJson(subject.toJson());
    expect(restoredSubject.readingDetails.first.type, 'onyomi');
    expect(restoredSubject.readingsFor('kunyomi'), ['まなぶ']);
    expect(subject.pronunciationAudios, hasLength(2));
    expect(
      subject.pronunciationAudioForVoice('female')?.url,
      'https://files.wanikani.com/eeu2zfeuqf3uiij9k5xf9nmxs4r2',
    );
    expect(
      subject.pronunciationAudioForVoice('male')?.voiceActorName,
      'Kenichi',
    );
    expect(subject.pronunciationAudios.first.gender, 'female');
    expect(subject.pronunciationAudios.first.contentType, 'audio/mpeg');
    expect(subject.pronunciationAudios.first.voiceActorName, 'Kyoko');
    expect(
      Subject.fromJson(subject.toJson()).pronunciationAudios.first.voiceActorId,
      1,
    );
  });

  test('maps numeric assignment SRS stages', () {
    final assignment = Assignment.fromJson({
      'id': 456,
      'subject_id': 123,
      'data': {'srs_stage': 9, 'unlocked_at': '2026-09-25T00:00:00.000Z'},
    });

    expect(assignment.id, 456);
    expect(assignment.subjectId, 123);
    expect(assignment.srsStage, SrsStage.burned);
  });

  test('parses numeric user level and id', () {
    final user = WaniKaniUser.fromJson({
      'id': 789,
      'data': {'username': 'learner', 'level': 34},
    });

    expect(user.id, 789);
    expect(user.level, 34);
    expect(user.username, 'learner');
  });
}
