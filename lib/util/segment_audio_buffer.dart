import 'dart:typed_data';

import '../config/ml_model_config.dart';

/// Concatenates [chunks] into a single contiguous [Float32List].
Float32List concatFloat32Chunks(List<Float32List> chunks) {
  var total = 0;
  for (final chunk in chunks) {
    total += chunk.length;
  }
  final result = Float32List(total);
  var offset = 0;
  for (final chunk in chunks) {
    result.setAll(offset, chunk);
    offset += chunk.length;
  }
  return result;
}

/// Returns the last [sampleCount] samples from [chunks], or all samples if
/// the buffer is shorter than [sampleCount].
Float32List takeLastSamples(List<Float32List> chunks, int sampleCount) {
  if (sampleCount <= 0) return Float32List(0);

  var total = 0;
  for (final chunk in chunks) {
    total += chunk.length;
  }
  if (total == 0) return Float32List(0);
  if (sampleCount >= total) return concatFloat32Chunks(chunks);

  final result = Float32List(sampleCount);
  var remaining = sampleCount;
  var writeAt = sampleCount;

  for (var i = chunks.length - 1; i >= 0 && remaining > 0; i--) {
    final chunk = chunks[i];
    final take = remaining < chunk.length ? remaining : chunk.length;
    writeAt -= take;
    result.setRange(writeAt, writeAt + take, chunk, chunk.length - take);
    remaining -= take;
  }
  return result;
}

/// Splits buffered audio into [prefix] (everything before the trailing
/// window) and [tail] (the last [windowSamples] samples).
///
/// If the buffer is shorter than [windowSamples], [prefix] is empty and
/// [tail] is the entire buffer.
({Float32List prefix, Float32List tail}) splitTrailingWindow(
  List<Float32List> chunks,
  int windowSamples,
) {
  final all = concatFloat32Chunks(chunks);
  if (windowSamples <= 0 || all.length <= windowSamples) {
    return (prefix: Float32List(0), tail: all);
  }
  final splitAt = all.length - windowSamples;
  return (
    prefix: Float32List.fromList(all.sublist(0, splitAt)),
    tail: Float32List.fromList(all.sublist(splitAt)),
  );
}

/// Whether a speaker-change probe result should force-cut the current
/// utterance given the [pendingLabel] already assigned to it.
///
/// [probeMatchedLabel] is the known-speaker label when the probe matched at
/// or above threshold; [probeIsUnknownNewVoice] is true when the probe did
/// not match anyone but known speakers exist (likely a new voice).
///
/// [pendingSpeakerScore] is cosine similarity of the probe window to the
/// pending speaker specifically. Unknown-new-voice cuts only fire when that
/// score is clearly impostor-level; different-speaker cuts also require a
/// margin over the pending score when both are available.
bool shouldForceCutOnSpeakerChange({
  required String pendingLabel,
  String? probeMatchedLabel,
  bool probeIsUnknownNewVoice = false,
  double? pendingSpeakerScore,
  double? bestScore,
  double rejectThreshold =
      MlModelConfig.diarizationSpeakerChangeRejectThreshold,
  double changeMargin = MlModelConfig.diarizationSpeakerChangeMargin,
}) {
  if (probeMatchedLabel != null) {
    if (probeMatchedLabel == pendingLabel) return false;
    if (pendingSpeakerScore != null && bestScore != null) {
      return bestScore - pendingSpeakerScore >= changeMargin;
    }
    return true;
  }

  if (!probeIsUnknownNewVoice) return false;
  if (pendingSpeakerScore == null) return false;
  return pendingSpeakerScore < rejectThreshold;
}

/// How many consecutive change probes are required before actually cutting.
///
/// Strong different-speaker evidence (typical male↔female gap) cuts on the
/// first hit; weaker/unknown evidence needs
/// [MlModelConfig.diarizationSpeakerChangeConfirmCount] hits.
int requiredSpeakerChangeConfirmations({
  String? probeMatchedLabel,
  double? pendingSpeakerScore,
  double? bestScore,
  double strongMargin = MlModelConfig.diarizationSpeakerChangeStrongMargin,
  int defaultCount = MlModelConfig.diarizationSpeakerChangeConfirmCount,
}) {
  if (probeMatchedLabel != null &&
      pendingSpeakerScore != null &&
      bestScore != null &&
      bestScore - pendingSpeakerScore >= strongMargin) {
    return 1;
  }
  return defaultCount;
}
