import 'package:get/get.dart';
import 'package:transcribe_summarize_clearhear/service/database_service.dart';
import 'package:transcribe_summarize_clearhear/service/llama_service.dart';
import 'package:transcribe_summarize_clearhear/service/session_summary_service.dart';

void ensureAiSummaryDependencies() {
  if (!Get.isRegistered<LlamaService>()) {
    Get.put<LlamaService>(LlamaService(), permanent: true);
  }
  if (!Get.isRegistered<SessionSummaryService>()) {
    Get.put<SessionSummaryService>(
      SessionSummaryService(
        databaseService: Get.find<DatabaseService>(),
        llamaService: Get.find<LlamaService>(),
      ),
      permanent: true,
    );
  }
}
