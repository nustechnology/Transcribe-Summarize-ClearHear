class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.snippet,
    required this.summaryStatus,
    required this.duration,
    required this.speakerCount,
    required this.category,
  });

  final String id;
  final String title;
  final DateTime timestamp;
  final String snippet;
  final String summaryStatus;
  final int duration;
  final int speakerCount;
  final String category;

  HistoryItem copyWith({
    String? id,
    String? title,
    DateTime? timestamp,
    String? snippet,
    String? summaryStatus,
    int? duration,
    int? speakerCount,
    String? category,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      snippet: snippet ?? this.snippet,
      summaryStatus: summaryStatus ?? this.summaryStatus,
      duration: duration ?? this.duration,
      speakerCount: speakerCount ?? this.speakerCount,
      category: category ?? this.category,
    );
  }


  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      snippet: json['snippet'] as String,
      summaryStatus: json['summaryStatus'] as String? ?? 'idle',
      duration: json['duration'] as int,
      speakerCount: json['speakerCount'] as int,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'timestamp': timestamp.toIso8601String(),
      'snippet': snippet,
      'summaryStatus': summaryStatus,
      'duration': duration,
      'speakerCount': speakerCount,
      'category': category,
    };
  }
}
