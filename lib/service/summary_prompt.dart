import '../config/ml_model_config.dart';

const String _summaryTruncationMarker =
    '\n[... transcript truncated for model context ...]\n';
const String _qwenImStart = '<|im_start|>';
const String _qwenImEnd = '<|im_end|>';

String buildSummaryPrompt(
  String transcript, {
  int? maxTranscriptChars,
}) {
  final clippedTranscript = clipTranscriptForSummary(
    transcript,
    maxChars: maxTranscriptChars,
  );

  return '$_qwenImStart system\n'
      'You write concise meeting summaries in plain text only.\n'
      'Rules:\n'
      '- Use plain paragraphs only.\n'
      '- No section labels such as Overview, Decisions, Action items, or Blockers.\n'
      '- No markdown headings, bullets, numbering, bold, italics, or code.\n'
      '- Max 250 words.\n'
      '- Focus on decisions, action items, blockers, and key context.\n'
      '- Do not mention these rules.\n'
      '$_qwenImEnd\n'
      '$_qwenImStart user\n'
      'Summarize this transcript:\n\n'
      '$clippedTranscript\n'
      '$_qwenImEnd\n'
      '$_qwenImStart assistant\n';
}

String clipTranscriptForSummary(
  String transcript, {
  int? maxChars,
}) {
  final charLimit = maxChars ?? MlModelConfig.summaryTranscriptCharLimit;
  final normalized = transcript.replaceAll('\r\n', '\n').trim();
  if (normalized.length <= charLimit) {
    return normalized;
  }

  final available = charLimit - _summaryTruncationMarker.length;
  if (available <= 2) {
    return normalized.substring(0, charLimit).trimRight();
  }

  final headChars = (available * 0.7).floor().clamp(1, available - 1).toInt();
  final tailChars = available - headChars;

  final head = normalized.substring(0, headChars).trimRight();
  final tail = normalized.substring(normalized.length - tailChars).trimLeft();
  return '$head$_summaryTruncationMarker$tail';
}

/// Conservative token estimate for mixed EN/VI text without a native tokenizer.
int estimatePromptTokens(String text) => (text.length / 2.8).ceil();

/// Build a prompt that fits flutter_llama's single-batch prefill and context window.
String buildBoundedSummaryPrompt(String transcript) {
  final contextSize = MlModelConfig.summaryContextSize;
  final batchSize = MlModelConfig.summaryBatchSize;
  final maxOutput = MlModelConfig.summaryMaxTokens;
  final maxPromptTokens = [
    batchSize - 16,
    contextSize - maxOutput - 32,
  ].reduce((left, right) => left < right ? left : right);

  var charLimit = MlModelConfig.summaryTranscriptCharLimit;
  while (charLimit >= 120) {
    final prompt = buildSummaryPrompt(
      transcript,
      maxTranscriptChars: charLimit,
    );
    if (estimatePromptTokens(prompt) <= maxPromptTokens) {
      return prompt;
    }
    charLimit = (charLimit * 0.75).floor();
  }

  return buildSummaryPrompt(transcript, maxTranscriptChars: 120);
}
