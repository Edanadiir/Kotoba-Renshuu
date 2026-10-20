class WaniKaniUser {
  const WaniKaniUser({
    required this.id,
    required this.username,
    required this.level,
  });

  final int id;
  final String username;
  final int level;

  factory WaniKaniUser.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return WaniKaniUser(
      id: _intValue(json['id'] ?? data['id']),
      username: data['username']?.toString() ?? '',
      level: _intValue(data['level']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': {'username': username, 'level': level},
  };

  static int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}
