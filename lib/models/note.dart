import 'dart:ui';

import 'package:intl/intl.dart';

class Note {
  int? id;
  String? cloudId;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String color;
  bool isPinned;
  String? category;

  Note({
    this.id,
    this.cloudId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.color = '4280391411', // Default blue color
    this.isPinned = false,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cloud_id': cloudId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'color': color,
      'is_pinned': isPinned ? 1 : 0,
      'category': category,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final pinned = map['is_pinned'];

    return Note(
      id: map['id'],
      cloudId: map['cloud_id'],
      title: map['title'],
      content: map['content'],
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      color: map['color'],
      isPinned: pinned == 1 || pinned == true,
      category: map['category'],
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'title': title,
      'content': content,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'color': color,
      'is_pinned': isPinned,
      'category': category,
    };
  }

  factory Note.fromCloudMap(
    Map<String, dynamic> map, {
    required String cloudId,
  }) {
    return Note(
      cloudId: cloudId,
      title: map['title'] ?? 'Untitled',
      content: map['content'] ?? '',
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
      color: map['color'] ?? '4280391411',
      isPinned: map['is_pinned'] == true || map['is_pinned'] == 1,
      category: map['category'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    try {
      final date = (value as dynamic).toDate();
      if (date is DateTime) {
        return date;
      }
    } catch (_) {}

    return DateTime.now();
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);

    if (noteDay == today) {
      return DateFormat('h:mm a').format(updatedAt);
    } else if (noteDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(updatedAt).inDays < 7) {
      return DateFormat('EEEE').format(updatedAt);
    } else {
      return DateFormat('MMM d, yyyy').format(updatedAt);
    }
  }

  Color get noteColor {
    return Color(int.parse(color));
  }

  int get wordCount {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  int get characterCount => content.length;

  String get fileContent => content;

  String get safeFileName {
    final safeTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return '${safeTitle.isNotEmpty ? safeTitle : 'untitled'}.md';
  }
}
