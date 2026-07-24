import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:transcribe_summarize_clearhear/model/conversation_segment.dart';
import 'package:transcribe_summarize_clearhear/service/audio_recorder_service.dart';
import 'package:transcribe_summarize_clearhear/service/live_transcript_service.dart';
import 'package:transcribe_summarize_clearhear/service/sherpa_onnx_service.dart';
import 'package:transcribe_summarize_clearhear/service/speaker_diarization_service.dart';
import 'package:transcribe_summarize_clearhear/util/asr_text_util.dart';

class _FakeOnlineStream extends OnlineStream {
  _FakeOnlineStream() : super(ptr: nullptr);

  @override
  void free() {}

  @override
  void inputFinished() {}

  @override
  void acceptWaveform({
    required Float32List samples,
    required int sampleRate,
  }) {}
}

class _FakeSherpaService extends SherpaOnnxService {
  String partialText = '';
  String finalizeText = '';
  bool endpoint = false;
  int createStreamCalls = 0;

  @override
  Future<void> ensureModelReady() async {}

  @override
  OnlineStream createStream() {
    createStreamCalls += 1;
    return _FakeOnlineStream();
  }

  @override
  void acceptWaveform(OnlineStream stream, Float32List samples) {}

  @override
  String decodeAndGetText(OnlineStream stream) => formatAsrText(partialText);

  @override
  bool isEndpoint(OnlineStream stream) => endpoint;

  @override
  String finalizeStream(OnlineStream stream) {
    endpoint = false;
    return formatAsrText(finalizeText);
  }

  @override
  AsrUtteranceResult finalizeStreamResult(OnlineStream stream) {
    return AsrUtteranceResult(text: finalizeStream(stream));
  }

  @override
  Future<void> dispose() async {}
}

class _FakeAudioRecorder extends AudioRecorderService {
  PcmChunkCallback? onChunk;
  bool streaming = false;
  int startCalls = 0;
  int stopCalls = 0;
  Object? startError;

  @override
  bool get isStreaming => streaming;

  @override
  Future<void> startStreaming({required PcmChunkCallback onChunk}) async {
    if (startError != null) {
      throw startError!;
    }
    startCalls += 1;
    this.onChunk = onChunk;
    streaming = true;
  }

  @override
  Future<void> stopStreaming() async {
    stopCalls += 1;
    streaming = false;
    onChunk = null;
  }

  @override
  Future<void> dispose() async {
    await stopStreaming();
  }

  void emitPcm16Samples(int sampleCount, {int amplitude = 10000}) {
    final bytes = Uint8List(sampleCount * 2);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < sampleCount; i++) {
      view.setInt16(i * 2, amplitude, Endian.little);
    }
    onChunk?.call(bytes);
  }
}

class _FakeSpeakerDiarization extends SpeakerDiarizationService {
  String? labelToReturn = 'Speaker 1';
  int labelCalls = 0;
  int relabelCalls = 0;
  Completer<String?>? delayedLabel;

  @override
  Future<void> ensureModelReady() async {}

  @override
  void resetSession() {}

  @override
  Future<String?> labelSegment(Float32List samples) async {
    labelCalls += 1;
    final delayed = delayedLabel;
    if (delayed != null) {
      return delayed.future;
    }
    return labelToReturn;
  }

  @override
  Future<void> relabelSegments(List<ConversationSegment> segments) async {
    relabelCalls += 1;
    for (final segment in segments) {
      segment.speakerLabel = 'Speaker Relabeled';
    }
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late _FakeAudioRecorder audio;
  late _FakeSherpaService sherpa;
  late LiveTranscriptService live;
  late List<String> partials;
  late List<ConversationSegment> finalized;

  setUp(() {
    audio = _FakeAudioRecorder();
    sherpa = _FakeSherpaService();
    partials = [];
    finalized = [];
    live = LiveTranscriptService(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
      onPartialText: partials.add,
      onSegmentFinalized: finalized.add,
    );
  });

  tearDown(() async {
    await live.dispose();
  });

  test('start begins streaming and creates an ASR stream', () async {
    await live.start();

    expect(sherpa.createStreamCalls, 1);
    expect(audio.startCalls, 1);
    expect(audio.streaming, isTrue);
  });

  test('audio chunk emits partial text from sherpa decode', () async {
    await live.start();
    sherpa.partialText = 'hello';

    audio.emitPcm16Samples(160);

    expect(partials, contains('Hello'));
  });

  test('endpoint finalizes a segment', () async {
    await live.start();
    sherpa.partialText = 'hello world';
    sherpa.finalizeText = 'hello world';
    sherpa.endpoint = true;

    audio.emitPcm16Samples(320);
    await Future<void>.delayed(Duration.zero);

    expect(finalized, hasLength(1));
    expect(finalized.single.displayText, 'Hello world');
  });

  test('pause stops streaming and returns current segments', () async {
    await live.start();
    sherpa.partialText = 'paused text';
    sherpa.finalizeText = 'paused text';
    audio.emitPcm16Samples(160);

    final result = await live.pause();

    expect(audio.stopCalls, 1);
    expect(audio.streaming, isFalse);
    expect(live.isPaused, isTrue);
    expect(result.segments, isNotEmpty);
    expect(result.usedAsr, isTrue);
  });

  test('finish stops streaming and clears active state', () async {
    await live.start();
    sherpa.partialText = 'done';
    audio.emitPcm16Samples(80);

    final result = await live.finish();

    expect(audio.streaming, isFalse);
    expect(live.isPaused, isFalse);
    expect(result.text, isNotEmpty);
  });

  test('resume after pause recreates ASR stream and restarts recorder',
      () async {
    await live.start();
    await live.pause();
    expect(live.isPaused, isTrue);

    await live.resume();

    expect(live.isPaused, isFalse);
    expect(sherpa.createStreamCalls, 2);
    expect(audio.startCalls, 2);
    expect(audio.streaming, isTrue);
  });

  test('start rolls back when recorder fails', () async {
    audio.startError = StateError('mic failed');

    await expectLater(live.start(), throwsStateError);
    expect(audio.streaming, isFalse);
  });

  test('early label emits onPartialSpeakerLabel after enough audio', () async {
    final diarization = _FakeSpeakerDiarization();
    final labels = <String?>[];
    live = LiveTranscriptService(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
      speakerDiarizationService: diarization,
      onPartialText: partials.add,
      onPartialSpeakerLabel: labels.add,
      onSegmentFinalized: finalized.add,
    );

    await live.start();
    sherpa.partialText = 'hello there';
    // 1.0s at 16 kHz is the min segment length for early labeling.
    audio.emitPcm16Samples(16000);
    await Future<void>.delayed(Duration.zero);

    expect(diarization.labelCalls, 1);
    expect(labels, contains('Speaker 1'));
  });

  test('endpoint waits for in-flight early label before finalizing', () async {
    final diarization = _FakeSpeakerDiarization()
      ..delayedLabel = Completer<String?>();
    live = LiveTranscriptService(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
      speakerDiarizationService: diarization,
      onPartialText: partials.add,
      onSegmentFinalized: finalized.add,
    );

    await live.start();
    sherpa.partialText = 'slow label';
    audio.emitPcm16Samples(16000);
    await Future<void>.delayed(Duration.zero);
    expect(diarization.labelCalls, 1);
    expect(finalized, isEmpty);

    sherpa.finalizeText = 'slow label';
    sherpa.endpoint = true;
    audio.emitPcm16Samples(160);
    await Future<void>.delayed(Duration.zero);
    expect(finalized, isEmpty);

    diarization.delayedLabel!.complete('Speaker 1');
    await Future<void>.delayed(Duration.zero);

    expect(finalized, hasLength(1));
    expect(finalized.single.speakerLabel, 'Speaker 1');
  });

  test('refineSpeakerLabels relabels segments and can clear audio', () async {
    final diarization = _FakeSpeakerDiarization();
    live = LiveTranscriptService(
      audioRecorderService: audio,
      sherpaOnnxService: sherpa,
      speakerDiarizationService: diarization,
      onPartialText: partials.add,
      onSegmentFinalized: finalized.add,
    );

    await live.start();
    sherpa.partialText = 'hello world';
    sherpa.finalizeText = 'hello world';
    sherpa.endpoint = true;
    audio.emitPcm16Samples(320);
    await Future<void>.delayed(Duration.zero);
    expect(finalized, hasLength(1));
    expect(finalized.single.audioSamples, isNotNull);

    final refined = await live.refineSpeakerLabels(clearAudioAfter: true);

    expect(diarization.relabelCalls, 1);
    expect(refined.segments.single.speakerLabel, 'Speaker Relabeled');
    expect(refined.segments.single.audioSamples, isNull);
  });
}
