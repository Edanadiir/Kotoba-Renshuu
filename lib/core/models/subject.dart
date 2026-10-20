import 'context_sentence.dart';

enum SubjectType { radical, kanji, vocabulary }

extension SubjectTypeJson on SubjectType {
  String get value => switch (this) {
    SubjectType.radical => 'radical',
    SubjectType.kanji => 'kanji',
    SubjectType.vocabulary => 'vocabulary',
  };

  static SubjectType fromValue(String? value) => switch (value) {
    'radical' => SubjectType.radical,
    'kanji' => SubjectType.kanji,
    _ => SubjectType.vocabulary,
  };
}

class Subject {
  const Subject({
    required this.id,
    required this.type,
    required this.level,
    required this.characters,
    required this.meanings,
    required this.readings,
    this.meaningMnemonic,
    this.readingMnemonic,
    this.readingDetails = const [],
    this.contextSentences = const [],
    this.visuallySimilarSubjectIds = const [],
    this.pronunciationAudios = const [],
  });

  final int id;
  final SubjectType type;
  final int level;
  final String characters;
  final List<String> meanings;
  final List<String> readings;
  final List<SubjectReading> readingDetails;
  final String? meaningMnemonic;
  final String? readingMnemonic;
  final List<ContextSentence> contextSentences;
  final List<int> visuallySimilarSubjectIds;
  final List<PronunciationAudio> pronunciationAudios;

  factory Subject.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    final meanings = _stringList(data['meanings']);
    final readings = _stringList(data['readings']);
    final readingDetails = (data['readings'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SubjectReading.fromJson)
        .toList();
    return Subject(
      id: _intValue(json['id'] ?? data['id']),
      type: SubjectTypeJson.fromValue(
        json['object'] as String? ?? data['object'] as String?,
      ),
      level: (data['level'] as num?)?.toInt() ?? 0,
      characters: data['characters']?.toString() ?? '',
      meanings: meanings,
      readings: readings,
      readingDetails: readingDetails,
      meaningMnemonic: data['meaning_mnemonic']?.toString(),
      readingMnemonic: data['reading_mnemonic']?.toString(),
      contextSentences: (data['context_sentences'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ContextSentence.fromJson)
          .toList(),
      visuallySimilarSubjectIds:
          (data['visually_similar_subject_ids'] as List<dynamic>? ?? [])
              .map(
                (value) => value is num
                    ? value.toInt()
                    : int.tryParse(value.toString()),
              )
              .whereType<int>()
              .toList(),
      pronunciationAudios:
          (data['pronunciation_audios'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(PronunciationAudio.fromJson)
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'object': type.value,
    'data': {
      'level': level,
      'characters': characters,
      'meanings': meanings.map((meaning) => {'meaning': meaning}).toList(),
      'readings': readingDetails.isEmpty
          ? readings.map((reading) => {'reading': reading}).toList()
          : readingDetails.map((reading) => reading.toJson()).toList(),
      'meaning_mnemonic': meaningMnemonic,
      'reading_mnemonic': readingMnemonic,
      'context_sentences': contextSentences
          .map((item) => item.toJson())
          .toList(),
      'visually_similar_subject_ids': visuallySimilarSubjectIds,
      'pronunciation_audios': pronunciationAudios
          .map((audio) => audio.toJson())
          .toList(),
    },
  };

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is String) return item;
          if (item is Map<String, dynamic>) {
            return item['meaning']?.toString() ??
                item['reading']?.toString() ??
                '';
          }
          return '';
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  List<String> readingsFor(String type) {
    if (!hasTypedReadings) return readings;
    final matching = readingDetails.where((item) => item.type == type).toList();
    return matching
        .where((item) => item.acceptedAnswer)
        .map((item) => item.reading)
        .toList();
  }

  bool get hasTypedReadings => readingDetails.any(
    (item) => item.type == 'onyomi' || item.type == 'kunyomi',
  );

  bool get hasPronunciationAudioUrls =>
      pronunciationAudios.any((audio) => _isValidPronunciationUrl(audio.url));

  PronunciationAudio? pronunciationAudioForVoice(String preferredVoice) {
    final available = pronunciationAudios
        .where((audio) => _isValidPronunciationUrl(audio.url))
        .toList();
    if (available.isEmpty) return null;

    final preferredActor = preferredVoice == 'female' ? 'kyoko' : 'kenichi';
    for (final audio in available) {
      if (audio.voiceActorName?.toLowerCase() == preferredActor) return audio;
    }
    for (final audio in available) {
      if (audio.gender == preferredVoice) return audio;
    }
    return available.first;
  }

  static bool _isValidPronunciationUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

class SubjectReading {
  const SubjectReading({
    required this.reading,
    this.type,
    this.acceptedAnswer = false,
    this.primary = false,
  });

  final String reading;
  final String? type;
  final bool acceptedAnswer;
  final bool primary;

  factory SubjectReading.fromJson(Map<String, dynamic> json) => SubjectReading(
    reading: json['reading']?.toString() ?? '',
    type: json['type']?.toString(),
    acceptedAnswer: json['accepted_answer'] == true,
    primary: json['primary'] == true,
  );

  Map<String, dynamic> toJson() => {
    'reading': reading,
    if (type != null) 'type': type,
    'accepted_answer': acceptedAnswer,
    'primary': primary,
  };
}

class PronunciationAudio {
  const PronunciationAudio({
    required this.url,
    this.contentType,
    this.gender,
    this.voiceActorId,
    this.voiceActorName,
  });

  final String url;
  final String? contentType;
  final String? gender;
  final int? voiceActorId;
  final String? voiceActorName;

  factory PronunciationAudio.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? const {};
    final voiceActorId = metadata['voice_actor_id'];
    return PronunciationAudio(
      url: json['url']?.toString() ?? '',
      contentType: json['content_type']?.toString(),
      gender: metadata['gender']?.toString(),
      voiceActorId: voiceActorId is num
          ? voiceActorId.toInt()
          : int.tryParse(voiceActorId?.toString() ?? ''),
      voiceActorName: metadata['voice_actor_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (contentType != null) 'content_type': contentType,
    'metadata': {
      'gender': gender,
      'voice_actor_id': voiceActorId,
      'voice_actor_name': voiceActorName,
    },
  };
}
