enum SrsStage { apprentice, guru, master, enlightened, burned }

extension SrsStageJson on SrsStage {
  int get value => switch (this) {
    SrsStage.apprentice => 1,
    SrsStage.guru => 5,
    SrsStage.master => 7,
    SrsStage.enlightened => 8,
    SrsStage.burned => 9,
  };

  static SrsStage fromValue(dynamic value) {
    final stage = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    if (stage >= 9) return SrsStage.burned;
    if (stage >= 8) return SrsStage.enlightened;
    if (stage >= 7) return SrsStage.master;
    if (stage >= 5) return SrsStage.guru;
    return SrsStage.apprentice;
  }
}

class Assignment {
  const Assignment({
    required this.id,
    required this.subjectId,
    required this.srsStage,
    required this.unlockedAt,
    this.startedAt,
    this.passedAt,
    this.burnedAt,
  });

  final int id;
  final int subjectId;
  final SrsStage srsStage;
  final DateTime? unlockedAt;
  final DateTime? startedAt;
  final DateTime? passedAt;
  final DateTime? burnedAt;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? json;
    return Assignment(
      id: _intValue(json['id'] ?? data['id']),
      subjectId: _intValue(json['subject_id'] ?? data['subject_id']),
      srsStage: SrsStageJson.fromValue(data['srs_stage']),
      unlockedAt: _date(data['unlocked_at']),
      startedAt: _date(data['started_at']),
      passedAt: _date(data['passed_at']),
      burnedAt: _date(data['burned_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject_id': subjectId,
    'data': {
      'srs_stage': srsStage.value,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'passed_at': passedAt?.toIso8601String(),
      'burned_at': burnedAt?.toIso8601String(),
    },
  };

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  static int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}
