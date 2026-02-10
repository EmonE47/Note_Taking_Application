import 'dart:ui';

import 'package:intl/intl.dart';

class Note {
  int? id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String color;
  bool isPinned;
  String? category;

  Note({
    this.id,
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
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      color: map['color'],
      isPinned: map['is_pinned'] == 1,
      category: map['category'],
    );
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

  String get fileContent => content;

  String get safeFileName {
    final safeTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return '${safeTitle.isNotEmpty ? safeTitle : 'untitled'}.md';
  }
}
