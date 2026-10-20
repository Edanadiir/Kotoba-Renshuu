import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/assignment.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import 'app_storage.dart';

List<Subject> _decodeSubjects(List<String> raw) => [
  for (final value in raw)
    Subject.fromJson(jsonDecode(value) as Map<String, dynamic>),
];

List<Assignment> _decodeAssignments(List<String> raw) => [
  for (final value in raw)
    Assignment.fromJson(jsonDecode(value) as Map<String, dynamic>),
];

class LocalCache {
  static const _subjectsBox = 'subjects';
  static const _assignmentsBox = 'assignments';
  static const _metaBox = 'sync_meta';
  static const _sessionKey = 'saved_quiz_session';
  static const _userKey = 'user_profile';
  static const _voiceKey = 'preferred_voice';

  Future<void> initialize() async {
    await initAppStorage();
    await Hive.openBox<String>(_subjectsBox);
    await Hive.openBox<String>(_assignmentsBox);
    await Hive.openBox<String>(_metaBox);
  }

  Future<void> saveSubjects(Iterable<Subject> subjects) async {
    final box = Hive.box<String>(_subjectsBox);
    await box.clear();
    for (final subject in subjects) {
      await box.put(subject.id.toString(), jsonEncode(subject.toJson()));
    }
  }

  Future<void> saveUser(WaniKaniUser user) =>
      Hive.box<String>(_metaBox).put(_userKey, jsonEncode(user.toJson()));

  WaniKaniUser? readUser() {
    final value = Hive.box<String>(_metaBox).get(_userKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic>
        ? WaniKaniUser.fromJson(decoded)
        : null;
  }

  Future<void> saveAssignments(Iterable<Assignment> assignments) async {
    final box = Hive.box<String>(_assignmentsBox);
    await box.clear();
    for (final assignment in assignments) {
      await box.put(
        assignment.subjectId.toString(),
        jsonEncode(assignment.toJson()),
      );
    }
  }

  List<Subject> readSubjects() {
    return Hive.box<String>(_subjectsBox).values
        .map(
          (value) =>
              Subject.fromJson(jsonDecode(value) as Map<String, dynamic>),
        )
        .toList();
  }

  List<Assignment> readAssignments() {
    return Hive.box<String>(_assignmentsBox).values
        .map(
          (value) =>
              Assignment.fromJson(jsonDecode(value) as Map<String, dynamic>),
        )
        .toList();
  }

  /// Decodes in a background isolate so large caches do not block the UI.
  Future<List<Subject>> readSubjectsAsync() {
    final raw = Hive.box<String>(_subjectsBox).values.toList();
    return compute(_decodeSubjects, raw);
  }

  Future<List<Assignment>> readAssignmentsAsync() {
    final raw = Hive.box<String>(_assignmentsBox).values.toList();
    return compute(_decodeAssignments, raw);
  }

  Future<void> setLastSync(DateTime date) =>
      Hive.box<String>(_metaBox).put('last_sync', date.toIso8601String());

  DateTime? get lastSync {
    final value = Hive.box<String>(_metaBox).get('last_sync');
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> saveQuizSession(Map<String, dynamic> session) =>
      Hive.box<String>(_metaBox).put(_sessionKey, jsonEncode(session));

  Map<String, dynamic>? readQuizSession() {
    final value = Hive.box<String>(_metaBox).get(_sessionKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> clearQuizSession() =>
      Hive.box<String>(_metaBox).delete(_sessionKey);

  String readPreferredVoice() =>
      Hive.box<String>(_metaBox).get(_voiceKey) ?? 'female';

  Future<void> savePreferredVoice(String voice) =>
      Hive.box<String>(_metaBox).put(_voiceKey, voice);

  Future<void> clearLocalData() async {
    final preferredVoice = readPreferredVoice();
    await Hive.box<String>(_subjectsBox).clear();
    await Hive.box<String>(_assignmentsBox).clear();
    await Hive.box<String>(_metaBox).clear();
    for (final name in [_subjectsBox, _assignmentsBox, _metaBox]) {
      await Hive.box<String>(name).compact();
    }
    (preferredVoice);
    await savePreferredVoice(preferredVoice);
    (preferredVoice);
  }
}
