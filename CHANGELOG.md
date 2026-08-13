# Changelog

All notable changes to ClearHear are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) for tagged releases
(`pubspec.yaml` `version: x.y.z+build`).

## [Unreleased]

### Changed

- Relicensed application source from MIT to [PolyForm Noncommercial
  License 1.0.0](LICENSE) (download/run allowed; commercial use not permitted).

### Added

- Project documentation: `LICENSE`, `NOTICE.md`, `SECURITY.md`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and this changelog.

## [1.0.0] - 2026-07-27

### Added

- On-device live captioning (sherpa-onnx streaming Zipformer2).
- Live speaker labels (Cam++ embeddings + cosine matching).
- On-device session summaries (Qwen2.5-0.5B GGUF via flutter_llama).
- Local session history, FTS search, export/share, and privacy-oriented
  settings (save toggle / clear data).
- Android foreground service for background capture.
