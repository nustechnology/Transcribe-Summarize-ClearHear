import 'session_model.dart';

/// Paginated result from [SessionRepository.getAllSessions].
class SessionPageResult {
  const SessionPageResult({
    required this.items,
    required this.hasMore,
  });

  final List<SessionModel> items;
  final bool hasMore;
}
