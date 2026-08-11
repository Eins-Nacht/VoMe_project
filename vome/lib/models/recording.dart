class Recording {
  final String id;
  final String title;
  final String eventType;
  final String category;
  final String mood;
  final String status;
  final int durationMs;
  final DateTime createdAt;
  final String audioPath;
  final int? fileSize;
  final String? mimeType;
  final String source;

  const Recording({
    required this.id,
    required this.title,
    required this.eventType,
    this.category = '',
    this.mood = 'Neutral',
    this.status = 'Pending',
    required this.durationMs,
    required this.createdAt,
    required this.audioPath,
    this.fileSize,
    this.mimeType,
    required this.source,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'event_type': eventType,
      'category': category,
      'mood': mood,
      'status': status,
      'duration_ms': durationMs,
      'created_at': createdAt.millisecondsSinceEpoch,
      'audio_path': audioPath,
      'file_size': fileSize,
      'mime_type': mimeType,
      'source': source,
    };
  }

  factory Recording.fromMap(Map<String, Object?> map) {
    return Recording(
      id: map['id'] as String,
      title: map['title'] as String,
      eventType: map['event_type'] as String,
      category: map['category'] as String? ?? '',
      mood: map['mood'] as String? ?? 'Neutral',
      status: map['status'] as String? ?? 'Pending',
      durationMs: map['duration_ms'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      audioPath: map['audio_path'] as String,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
      source: map['source'] as String,
    );
  }

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  String get formattedDuration {
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes} min';
  }
}
