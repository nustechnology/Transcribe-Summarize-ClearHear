# Third-party notices

ClearHear application code is licensed under the [NUS Technology Non-Commercial License 1.0](LICENSE).
This file lists third-party software and ML models that ClearHear uses or
distributes. Model weights are **not** part of the NUS Technology Non-Commercial License 1.0 application
source; they remain under their own upstream licenses. Always verify the
upstream model card before redistributing weights.

## Application dependencies (runtime)

ClearHear is a Flutter app. Major native/ML dependencies include:

| Component | Role | Upstream | Typical license |
|-----------|------|----------|-----------------|
| [sherpa_onnx](https://pub.dev/packages/sherpa_onnx) / [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Streaming ASR + speaker embedding inference | k2-fsa / Next-gen Kaldi | Apache-2.0 |
| [flutter_llama](https://pub.dev/packages/flutter_llama) | On-device LLM inference | pub.dev package | NativeMindNONC |
| [llama.cpp](https://github.com/ggml-org/llama.cpp) | GGUF runtime (via flutter_llama / vendored build) | ggml-org | MIT |
| [GetX](https://pub.dev/packages/get) | State management / routing | pub.dev | MIT |
| [sqflite](https://pub.dev/packages/sqflite) | Local SQLite storage | pub.dev | BSD-2-Clause |

Other Dart/Flutter packages are declared in `pubspec.yaml` / `pubspec.lock`
and carry their own licenses (viewable via `flutter pub deps` or each package’s
pub.dev page).

## ML models

Configured in `lib/config/ml_model_config.dart`. ASR and speaker-embedding
ONNX files are fetched by `tool/download_sherpa_onnx_model.sh` (or by the app
from Hugging Face on first launch if assets are missing). The summary GGUF is
tracked with Git LFS under `assets/models/`.

### Streaming ASR (Zipformer2, English)

| | |
|--|--|
| **Files** | `encoder-…int8.onnx`, `decoder-…int8.onnx`, `joiner-…int8.onnx`, `tokens.txt` |
| **Distribution** | [csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26) |
| **Origin notes** | TorchScript source cited on the model card: [Zengwei/icefall-asr-librispeech-streaming-zipformer-2023-05-17](https://huggingface.co/Zengwei/icefall-asr-librispeech-streaming-zipformer-2023-05-17); training related to [k2-fsa/icefall](https://github.com/k2-fsa/icefall) |
| **License** | No standalone license for these distributed weight files is published in the referenced upstream model repos/model cards. sherpa-onnx *code* is Apache-2.0, but that does **not** automatically license model weights. Treat weight redistribution as restricted until you independently verify and satisfy all applicable upstream terms (model card, training recipe, and dataset/license chain). |

### Speaker embedding (Cam++ / 3D-Speaker)

| | |
|--|--|
| **File** | `3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx` |
| **Distribution** | [csukuangfj/speaker-embedding-models](https://huggingface.co/csukuangfj/speaker-embedding-models) |
| **Origin notes** | 3D-Speaker / Cam++ family (Alibaba / ModelScope ecosystem) |
| **License** | No standalone license for this distributed ONNX weight file is published in the referenced upstream model repos/model cards. The surrounding inference code may be licensed separately, but that does **not** automatically license model weights. Treat redistribution as restricted until you independently verify and satisfy all applicable upstream terms. |

### Summarization LLM (Qwen2.5)

| | |
|--|--|
| **File** | `qwen2.5-0.5b-instruct-q4_k_m.gguf` (~469 MB) |
| **Distribution** | Bundled via Git LFS; based on [Qwen/Qwen2.5-0.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) |
| **License** | [Apache License 2.0](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/blob/main/LICENSE) (Alibaba Cloud / Qwen) |

## Network use related to models

Transcription, diarization, and summarization run **on-device**. The only
intended network access for ML is downloading missing ONNX model files from
Hugging Face when they are not present under `assets/models/`.

## Attribution

If you distribute ClearHear binaries that include or download these models,
retain this NOTICE (or equivalent attribution) and the applicable upstream
licenses with your distribution.
