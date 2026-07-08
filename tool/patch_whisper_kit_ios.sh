#!/usr/bin/env bash
# Patches whisper_kit 0.3.0 iOS sources in pub-cache after `flutter pub get`.
# Idempotent — safe to run multiple times.
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

python3 - "$PUB_CACHE" <<'PY'
import pathlib
import re
import sys

pub_cache = pathlib.Path(sys.argv[1])
files = sorted(pub_cache.glob("hosted/pub.dev/whisper_kit-*/ios/Classes/*"))
files += sorted(pub_cache.glob("hosted/pub.dev/whisper_kit-*/ios/Classes/WhisperKitWrapper.mm"))

if not files:
    print("No whisper_kit iOS sources found in pub-cache. Run 'flutter pub get' first.")
    sys.exit(1)

def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")

def write(path: pathlib.Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"Patched: {path}")

def patch_plugin_header(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_PLUGIN_HEADER" in text:
        return text
    old = """#endif
#endif

@interface WhisperKitPlugin : NSObject<FlutterPlugin>
@end"""
    new = """#endif
#endif

// PATCHED_CLEARHEAR_PLUGIN_HEADER
// WhisperKitPlugin is declared in whisper_kit-Swift.h"""
    if old not in text:
        return text
    return text.replace(old, new, 1)

def patch_wrapper(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_WRAPPER" in text:
        return text
    if "NSMutableDictionary *request =" not in text:
        return text
    text = text.replace(
        "NSMutableDictionary *request = [NSMutableDictionary dictionary];",
        "// PATCHED_CLEARHEAR_WRAPPER\n    NSMutableDictionary *requestPayload = [NSMutableDictionary dictionary];",
        1,
    )
    text = text.replace("request[@", "requestPayload[@")
    text = text.replace(
        "dataWithJSONObject:request options:0",
        "dataWithJSONObject:requestPayload options:0",
        1,
    )
    text = text.replace(
        "char *result = request(jsonMutable);",
        "char *result = ::request(jsonMutable);",
        1,
    )
    return text

def patch_plugin_access(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_PLUGIN_ACCESS" in text:
        return text
    replacements = [
        ("  private let logger = Logger", "  // PATCHED_CLEARHEAR_PLUGIN_ACCESS\n  let logger = Logger"),
        ("  private let audioPreprocessor = AudioPreprocessor()", "  let audioPreprocessor = AudioPreprocessor()"),
        ("  private let formatConverter = AudioFormatConverter()", "  let formatConverter = AudioFormatConverter()"),
        ("  private var enhancedAudioManager", "  var enhancedAudioManager"),
    ]
    for old, new in replacements:
        text = text.replace(old, new, 1)
    text = text.replace(
        "guard let resultC = request(mutableString) else {",
        "guard let resultC = request(mutableString) else {",
    )
    if "guard let resultC = request(mutableString)" not in text:
        text = text.replace(
            "let resultC = request(mutableString)",
            "guard let resultC = request(mutableString) else {\n      logger.error(\"C++ request function returned nil\")\n      return nil\n    }",
            1,
        )
    return text

def patch_enhanced_audio_manager(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_ENHANCED_AUDIO" in text:
        return text
    old = "        let metadata = formatConverter.getAudioMetadata(url: url)"
    new = """        // PATCHED_CLEARHEAR_ENHANCED_AUDIO
        guard let metadata = formatConverter.getAudioMetadata(url: url) else {
            completion(.failure(EnhancedAudioError.invalidAudioData))
            return
        }"""
    if old in text and "guard let metadata" not in text:
        text = text.replace(old, new, 1)
    return text

def patch_enhanced_audio_extension(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_PRESET_NAME" not in text:
        old = """    private func preprocessingPresetName(_ settings: AudioPreprocessingSettings) -> String {
        if settings == AudioPreprocessingSettings.default {
            return "default"
        }
        if settings == AudioPreprocessingSettings.minimal {
            return "minimal"
        }
        return "aggressive"
    }"""
        new = """    private func preprocessingPresetName(_ settings: AudioPreprocessingSettings) -> String {
        // PATCHED_CLEARHEAR_PRESET_NAME
        if !settings.enableNoiseReduction && !settings.enableVoiceEnhancement {
            return "minimal"
        }
        if settings.enableLowPassFilter && settings.noiseReductionStrength >= 0.9 {
            return "aggressive"
        }
        return "default"
    }"""
        if old in text:
            text = text.replace(old, new, 1)
        elif "preprocessingPresetName" in text and "PATCHED_CLEARHEAR_PRESET_NAME" not in text:
            text = text.replace(
                "    private func preprocessingPresetName(_ settings: AudioPreprocessingSettings) -> String {\n        if !settings.enableNoiseReduction",
                "    private func preprocessingPresetName(_ settings: AudioPreprocessingSettings) -> String {\n        // PATCHED_CLEARHEAR_PRESET_NAME\n        if !settings.enableNoiseReduction",
                1,
            )

    text = text.replace(
        '"metadata": convertAudioMetadataToDict(metadata)',
        '"metadata": metadata.map { convertAudioMetadataToDict($0) } ?? [:]',
    )
    text = text.replace(
        '"recommendedSettings": qualityAnalysis.recommendedSettings == .default ? "default" :\n                                     qualityAnalysis.recommendedSettings == .minimal ? "minimal" : "aggressive"',
        '"recommendedSettings": preprocessingPresetName(qualityAnalysis.recommendedSettings)',
    )

    if "PATCHED_CLEARHEAR_ENHANCED_AUDIO_DELEGATE" not in text:
        delegate_block = """

// MARK: - EnhancedAudioManagerDelegate
// PATCHED_CLEARHEAR_ENHANCED_AUDIO_DELEGATE

extension WhisperKitPlugin: EnhancedAudioManagerDelegate {
    func audioManager(_ manager: EnhancedAudioManager, didStartProcessing startTime: TimeInterval) {
        logger.info("Enhanced audio processing started")
    }

    func audioManager(_ manager: EnhancedAudioManager, didProcessChunk chunk: AudioChunk, transcription: TranscriptionResult?) {
        logger.debug("Processed enhanced audio chunk")
    }

    func audioManager(_ manager: EnhancedAudioManager, didDetectVoiceActivity isActive: Bool, timestamp: TimeInterval) {}

    func audioManager(_ manager: EnhancedAudioManager, didUpdateProgress progress: Float) {}

    func audioManager(_ manager: EnhancedAudioManager, didCompleteProcessing finalResult: EnhancedAudioResult) {
        logger.info("Enhanced audio processing completed")
    }

    func audioManager(_ manager: EnhancedAudioManager, didEncounterError error: Error) {
        logger.error("Enhanced audio error: \\(error.localizedDescription)")
    }

    func audioManager(_ manager: EnhancedAudioManager, didChangeQuality quality: AudioQuality) {}
}
"""
        if "extension WhisperKitPlugin: EnhancedAudioManagerDelegate" not in text:
            marker = "\n// MARK: - AudioFormat Extension"
            if marker in text:
                text = text.replace(marker, delegate_block + marker, 1)
    return text

def patch_format_converter(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_FORMAT_CONVERTER" not in text:
        old_blocks = [
            """    func getAudioMetadata(url: URL) -> AudioMetadata? {
        let asset = AVURLAsset(url: url)

        guard let duration = asset.duration.seconds,
              duration > 0 else { return nil }

        var sampleRate: Double = 0
        var channelCount: Int = 0
        var bitRate: Int = 0

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = audioTrack.formatDescriptions
            for formatDescription in formatDescriptions {
                if let streamDescription = formatDescription.streamBasicDescription {
                    sampleRate = streamDescription.pointee.mSampleRate
                    channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
                    break
                }
            }
        }

        bitRate = Int(asset.preferredTrackRate) // Approximation

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0""",
            """    func getAudioMetadata(url: URL) -> AudioMetadata? {
        let asset = AVURLAsset(url: url)

        guard let duration = asset.duration.seconds,
              duration > 0 else { return nil }

        var sampleRate: Double = 0
        var channelCount: Int = 0
        var bitRate: Int = 0

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let formatDescriptions = audioTrack.formatDescriptions
            for formatDescription in formatDescriptions {
                guard let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
                    continue
                }
                sampleRate = streamDescription.pointee.mSampleRate
                channelCount = Int(streamDescription.pointee.mChannelsPerFrame)
                break
            }
        }

        bitRate = Int(asset.preferredTrackRate) // Approximation

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0""",
        ]
        new = """    func getAudioMetadata(url: URL) -> AudioMetadata? {
        let asset = AVURLAsset(url: url)

        // PATCHED_CLEARHEAR_FORMAT_CONVERTER
        let duration = asset.duration.seconds
        guard duration > 0 else { return nil }

        var sampleRate: Double = 0
        var channelCount: Int = 0
        var bitRate: Int = 0

        if let audioFile = try? AVAudioFile(forReading: url) {
            sampleRate = audioFile.fileFormat.sampleRate
            channelCount = Int(audioFile.fileFormat.channelCount)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        if duration > 0 {
            bitRate = Int(Double(fileSize * 8) / duration)
        }"""
        for old in old_blocks:
            if old in text:
                text = text.replace(old, new, 1)
                break

    if "PATCHED_CLEARHEAR_FORMAT_CONVERTER_BITRATE" not in text:
        text = text.replace(
            "            converter.bitRate = settings.bitRate",
            "            // PATCHED_CLEARHEAR_FORMAT_CONVERTER_BITRATE\n            converter.bitRate = settings.bitRate ?? 128000",
            1,
        )

    if "PATCHED_CLEARHEAR_FORMAT_CONVERTER_CHANNELS" not in text:
        text = text.replace(
            "return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: settings.sampleRate, channels: settings.channelCount, interleaved: false)!",
            "// PATCHED_CLEARHEAR_FORMAT_CONVERTER_CHANNELS\n            return AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: settings.sampleRate, channels: AVAudioChannelCount(settings.channelCount), interleaved: false)!",
            1,
        )

    if "PATCHED_CLEARHEAR_FORMAT_CONVERTER_LOSSLESS" not in text:
        text = text.replace(
            "AVEncoderAudioQualityKey: AudioQuality.lossless.rawValue",
            "// PATCHED_CLEARHEAR_FORMAT_CONVERTER_LOSSLESS\n                AVEncoderAudioQualityKey: AudioConversionSettings.AudioQuality.lossless.rawValue",
            1,
        )

    if "PATCHED_CLEARHEAR_FORMAT_CONVERTER_FRAMECOUNT" not in text:
        text = text.replace(
            "let frameCount = AVAudioFrameCount(data.count / (format.streamDescription.pointee.mBytesPerFrame))",
            "// PATCHED_CLEARHEAR_FORMAT_CONVERTER_FRAMECOUNT\n        let frameCount = AVAudioFrameCount(data.count / Int(format.streamDescription.pointee.mBytesPerFrame))",
            1,
        )

    return text

def patch_vad(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_VAD" in text:
        return text
    text = text.replace(
        "import AVFoundation\nimport os.log",
        "import AVFoundation\nimport Accelerate\nimport os.log",
        1,
    )
    text = text.replace(
        'logger.info("VAD initialized with frame size: \\(frameSize), sample rate: \\(sampleRate)")',
        '// PATCHED_CLEARHEAR_VAD\n        logger.info("VAD initialized with frame size: \\(self.frameSize), sample rate: \\(self.sampleRate)")',
        1,
    )
    text = text.replace(
        "let log2n = vDSP_Length(log2(Double(fftSize)))",
        "let log2n = vDSP_Length(floor(log2(Double(fftSize))))",
        1,
    )
    return text

def patch_vdsp_svesq(text: str, marker: str) -> str:
    if marker in text:
        return text
    old = """        var sum: Float = 0.0
        vDSP_vsq(samples, 1, &sum, vDSP_Length(samples.count))"""
    new = f"""        // {marker}
        var sum: Float = 0.0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))"""
    return text.replace(old, new, 1)

def patch_audio_chunker(path: pathlib.Path, text: str) -> str:
    if "import Accelerate" not in text:
        text = text.replace(
            "import AVFoundation\nimport os.log",
            "import AVFoundation\nimport Accelerate\nimport os.log",
            1,
        )
    text = patch_vdsp_svesq(text, "PATCHED_CLEARHEAR_AUDIO_CHUNKER_VDSP")
    if "PATCHED_CLEARHEAR_AUDIO_CHUNKER" in text:
        return text
    text = text.replace(
        "processingProgress: totalDuration > 0 ? processedDuration / totalDuration : 0.0",
        "// PATCHED_CLEARHEAR_AUDIO_CHUNKER\n            processingProgress: totalDuration > 0 ? Float(processedDuration / totalDuration) : 0.0",
        1,
    )
    return text

def patch_streaming(path: pathlib.Path, text: str) -> str:
    if "import Accelerate" not in text:
        text = text.replace(
            "import AVFoundation\nimport os.log",
            "import AVFoundation\nimport Accelerate\nimport os.log",
            1,
        )
    text = patch_vdsp_svesq(text, "PATCHED_CLEARHEAR_STREAMING_VDSP")

    if "PATCHED_CLEARHEAR_STREAMING_CHUNKSIZE" not in text:
        replacements = [
            (
                "        let chunkSize = Int(chunkDuration * sampleRate)\n        if audioBuffer.count >= chunkSize {",
                "        // PATCHED_CLEARHEAR_STREAMING_CHUNKSIZE\n        let chunkSize = Int(chunkDuration * sampleRate * Double(MemoryLayout<Float>.size))\n        if audioBuffer.count >= chunkSize {",
            ),
            (
                "        let chunkSize = Int(chunkDuration * sampleRate * MemoryLayout<Float>.size)\n        if audioBuffer.count >= chunkSize {",
                "        // PATCHED_CLEARHEAR_STREAMING_CHUNKSIZE\n        let chunkSize = Int(chunkDuration * sampleRate * Double(MemoryLayout<Float>.size))\n        if audioBuffer.count >= chunkSize {",
            ),
        ]
        for old, new in replacements:
            if old in text:
                text = text.replace(old, new, 1)
                break
        text = text.replace(
            "audioBuffer.removeFirst(chunkSize - Int(overlapDuration * sampleRate * MemoryLayout<Float>.size))",
            "audioBuffer.removeFirst(chunkSize - Int(overlapDuration * sampleRate * Double(MemoryLayout<Float>.size)))",
            1,
        )

    if "PATCHED_CLEARHEAR_STREAMING_TIMESTAMP" not in text:
        text = text.replace(
            "                timestamp: time.timeIntervalSince1970,",
            "                // PATCHED_CLEARHEAR_STREAMING_TIMESTAMP\n                timestamp: Date().timeIntervalSince1970,",
            1,
        )

    if "PATCHED_CLEARHEAR_STREAMING_PROCESSING_TIME" not in text:
        old = """            if var transcriptionResult = result {
                transcriptionResult.processingTime = processingTime
                self?.processedTranscriptions.append(transcriptionResult)

                DispatchQueue.main.async {
                    self?.delegate?.audioProcessor(self!, didProcessAudioChunk: chunk, transcription: transcriptionResult)
                }"""
        new = """            // PATCHED_CLEARHEAR_STREAMING_PROCESSING_TIME
            if let transcriptionResult = result {
                let updatedResult = TranscriptionResult(
                    text: transcriptionResult.text,
                    segments: transcriptionResult.segments,
                    confidence: transcriptionResult.confidence,
                    language: transcriptionResult.language,
                    timestamp: transcriptionResult.timestamp,
                    processingTime: processingTime
                )
                self?.processedTranscriptions.append(updatedResult)

                DispatchQueue.main.async {
                    self?.delegate?.audioProcessor(self!, didProcessAudioChunk: chunk, transcription: updatedResult)
                }"""
        if old in text:
            text = text.replace(old, new, 1)

    return text

def patch_audio_preprocessor(path: pathlib.Path, text: str) -> str:
    if "PATCHED_CLEARHEAR_AUDIO_PREPROCESSOR" in text:
        return text
    old = """    private var type: FilterType
    private var frequency: Float
    private var sampleRate: Double
    private var q: Float"""
    new = """    private var type: FilterType
    private var frequency: Float
    private var sampleRate: Double
    private var q: Float

    // PATCHED_CLEARHEAR_AUDIO_PREPROCESSOR
    private var b0: Float = 0.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a0: Float = 1.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0"""
    if old in text:
        text = text.replace(old, new, 1)
    text = re.sub(
        r"coefficients\.b0",
        "b0",
        text,
    )
    return text

def patch_podspec(pub_cache: pathlib.Path) -> None:
    for path in sorted(pub_cache.glob("hosted/pub.dev/whisper_kit-*/ios/whisper_kit.podspec")):
        text = read(path)
        if "PATCHED_CLEARHEAR_PODSPEC" in text:
            continue
        old = "s.source_files     = 'Classes/**/*', 'src/**/*.{h,cpp}'"
        new = "s.source_files     = 'Classes/**/*', 'src/**/*.{h,cpp,c}'  # PATCHED_CLEARHEAR_PODSPEC: include ggml.c"
        if old not in text:
            continue
        write(path, text.replace(old, new, 1))

patchers = {
    "WhisperKitPlugin.h": patch_plugin_header,
    "WhisperKitWrapper.mm": patch_wrapper,
    "WhisperKitPlugin.swift": patch_plugin_access,
    "EnhancedAudioManager.swift": patch_enhanced_audio_manager,
    "WhisperKitPlugin+EnhancedAudio.swift": patch_enhanced_audio_extension,
    "AudioFormatConverter.swift": patch_format_converter,
    "VoiceActivityDetector.swift": patch_vad,
    "AudioChunker.swift": patch_audio_chunker,
    "StreamingAudioProcessor.swift": patch_streaming,
    "AudioPreprocessor.swift": patch_audio_preprocessor,
}

for path in files:
    if path.name not in patchers:
        continue
    original = read(path)
    updated = patchers[path.name](path, original)
    if updated != original:
        write(path, updated)

patch_podspec(pub_cache)

print("Done.")
PY
