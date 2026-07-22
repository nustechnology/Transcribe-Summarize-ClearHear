import 'package:flutter/foundation.dart';

import '../model/conversation_segment.dart';

/// Tracks conversation segments produced during a captioning session.
class ConversationSegmentCapture {
  final List<ConversationSegment> _segments = [];
  int _nextId = 1;

  List<ConversationSegment> get segments => List.unmodifiable(_segments);

  void start() {
    _segments.clear();
    _nextId = 1;
  }

  ConversationSegment commitSegment({
    String text = '',
    String wavPath = '',
    int startMs = 0,
    int endMs = 0,
  }) {
    final segment = ConversationSegment(
      id: _nextId,
      wavPath: wavPath,
      asrText: text,
      recordedAt: DateTime.now(),
      startMs: startMs,
      endMs: endMs,
    );
    _nextId++;
    _segments.add(segment);
    debugPrint(
      '[SegmentCapture] finalized segment ${segment.id} '
      '(${segment.displayText.length} characters)',
    );
    return segment;
  }

  void dispose() {
    _segments.clear();
    _nextId = 1;
  }
}
