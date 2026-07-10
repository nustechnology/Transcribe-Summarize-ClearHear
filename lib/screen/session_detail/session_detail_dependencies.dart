import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/segment_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/impl/session_repository_impl.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/segment_repository.dart';
import 'package:transcribe_summarize_clearhear/arch/repository/session_repository.dart';
import 'package:transcribe_summarize_clearhear/service/ai_summary_dependencies.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';

void ensureSessionDetailDependencies() {
  ensureAiSummaryDependencies();

  if (!Get.isRegistered<SegmentRepository>()) {
    Get.lazyPut<SegmentRepository>(
      () => SegmentRepositoryImpl(Get.find<DatabaseService>()),
      fenix: true,
    );
  }
  if (!Get.isRegistered<SessionRepository>()) {
    Get.lazyPut<SessionRepository>(
      () => SessionRepositoryImpl(
        Get.find<DatabaseService>(),
      ),
      fenix: true,
    );
  }
}
