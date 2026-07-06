import 'package:transcribe_summarize_clearhear/shared/models/segment_model.dart';

/// Abstract contract for all segment persistence operations.
///
/// Partials are NEVER passed to this repository — only finalized chunks.
abstract class SegmentRepository {
  /// Inserts a single finalized [segment] and returns its auto id.
  ///
  /// The FTS5 trigger fires automatically after insert.
  Future<int> insertSegment(SegmentModel segment);

  /// Batch-inserts multiple [segments] in one sqflite batch.
  ///
  /// Preferred for end-of-session bulk persistence (≈ 900 rows for 60 min).
  /// All FTS5 triggers still fire per row.
  Future<void> insertSegments(List<SegmentModel> segments);

  /// Returns all finalized segments for [sessionId] ordered by [start_ms].
  Future<List<SegmentModel>> getSegments(int sessionId);

  /// Paginated segment loading for very long sessions.
  Future<List<SegmentModel>> getSegmentsPaged({
    required int sessionId,
    required int offset,
    required int limit,
  });

  /// Explicitly deletes all segments for [sessionId].
  ///
  /// Normally handled by CASCADE, but exposed for targeted cleanup.
  Future<void> deleteSegments(int sessionId);
}
