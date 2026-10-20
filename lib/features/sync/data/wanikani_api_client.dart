import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/assignment.dart';
import '../../../core/models/subject.dart';
import '../../../core/models/user.dart';

class WaniKaniApiClient {
  WaniKaniApiClient({required String token, Dio? dio})
    : _dio = _configureDio(token, dio);

  final Dio _dio;

  Future<WaniKaniUser> validateToken() async {
    final response = await _get('/user');
    return WaniKaniUser.fromJson(response.data ?? const {});
  }

  Future<List<Subject>> fetchSubjects({
    String? updatedAfter,
    void Function(int page)? onPage,
  }) async {
    final response = await _getAll(
      '/subjects',
      updatedAfter: updatedAfter,
      onPage: onPage,
    );
    return response.map(Subject.fromJson).toList();
  }

  Future<List<Assignment>> fetchAssignments({
    String? updatedAfter,
    void Function(int page)? onPage,
  }) async {
    final response = await _getAll(
      '/assignments',
      updatedAfter: updatedAfter,
      onPage: onPage,
    );
    return response.map(Assignment.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _getAll(
    String path, {
    String? updatedAfter,
    void Function(int page)? onPage,
  }) async {
    final items = <Map<String, dynamic>>[];
    String? nextUrl = path;
    var pageNumber = 0;

    while (nextUrl != null) {
      pageNumber++;
      onPage?.call(pageNumber);
      debugPrint(
        'WaniKani request: $nextUrl; '
        'tokenPresent=$_hasBearerToken',
      );
      final response = await _dio.get<Map<String, dynamic>>(
        nextUrl,
        queryParameters: nextUrl == path && updatedAfter != null
            ? {'updated_after': updatedAfter}
            : null,
      );
      final body = response.data ?? const <String, dynamic>{};
      final page = body['data'];
      if (page is List) {
        items.addAll(page.whereType<Map<String, dynamic>>());
      }
      final pages = body['pages'];
      nextUrl = pages is Map<String, dynamic>
          ? pages['next_url'] as String?
          : null;
    }

    return items;
  }

  Future<Response<Map<String, dynamic>>> _get(String path) {
    debugPrint('WaniKani request: $path; tokenPresent=$_hasBearerToken');
    return _dio.get<Map<String, dynamic>>(path);
  }

  bool get _hasBearerToken {
    final authorization = _dio.options.headers['Authorization'];
    return authorization is String &&
        authorization.replaceFirst('Bearer ', '').trim().isNotEmpty;
  }

  static Dio _configureDio(String token, Dio? dio) {
    final client = dio ?? Dio();
    client.options.baseUrl = 'https://api.wanikani.com/v2';
    client.options.headers.addAll({
      'Authorization': 'Bearer ${token.trim()}',
      'Wanikani-Revision': '20170710',
      'Accept': 'application/json',
    });
    return client;
  }
}
