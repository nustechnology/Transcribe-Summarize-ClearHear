import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/llama_service.dart';

void main() {
  group('LlamaService.looksLikeResourceLimit', () {
    test('returns true for LlamaServiceException flagged as resource limit', () {
      expect(
        LlamaService.looksLikeResourceLimit(
          LlamaServiceException('oom', isResourceLimit: true),
        ),
        isTrue,
      );
    });

    test('returns false for generic LlamaServiceException', () {
      expect(
        LlamaService.looksLikeResourceLimit(LlamaServiceException('failed')),
        isFalse,
      );
    });

    test('detects out-of-memory phrases in plain errors', () {
      expect(
        LlamaService.looksLikeResourceLimit(Exception('Out of memory')),
        isTrue,
      );
      expect(
        LlamaService.looksLikeResourceLimit(Exception('failed to allocate')),
        isTrue,
      );
    });

    test('detects resource phrases in PlatformException', () {
      expect(
        LlamaService.looksLikeResourceLimit(
          PlatformException(
            code: 'LLAMA',
            message: 'Unable to allocate buffer',
          ),
        ),
        isTrue,
      );
    });

    test('returns false for unrelated errors', () {
      expect(
        LlamaService.looksLikeResourceLimit(Exception('model missing')),
        isFalse,
      );
    });
  });
}
