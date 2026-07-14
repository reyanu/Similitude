# Similitude

A privacy-first iPhone app for families: compare facial resemblance, create artistic portrait effects, generate an on-device AI cartoon portrait, and build premium family keepsakes.

> **Private. On-device. Your family photos never leave your phone.**

Resemblance results are for entertainment and family keepsake purposes only. They are not proof of biological relationship, identity, or genetics.

## Tech stack

- Swift / SwiftUI, iOS 17+
- Apple Vision (`VNDetectFaceLandmarksRequest`) for face detection and landmarks
- Core Image for artistic filters
- Core ML (Photo2Cartoon) for the AI Cartoon Portrait — downloaded on demand, never bundled
- No backend. No cloud AI. No analytics. All processing is on-device.

## Repository layout

```
project.yml                     XcodeGen project definition (the .xcodeproj is generated, not committed)
Similitude/
  App/                          App entry + root tab bar
  Theme/                        Brand colors, copy, shared badges
  Model/                        ImageSource and shared domain types
  Services/                     FaceNormalizationService, FaceDetectionService
  Filters/                      Pencil Sketch, Poster Art, Soft Cartoon + output safety validation
  Views/                        Home, Compare, Studio, Timeline, Profile
  Resources/Assets.xcassets/    StudioPreviews image slots (real app output goes here)
SimilitudeTests/                Unit tests (normalization, filter safety)
.github/workflows/
  ios-testflight.yml            CI build + test on macOS runners, archive + TestFlight upload
```

## Building

The development workspace is Windows-based; all iOS builds are validated on GitHub Actions macOS runners. On a Mac:

```sh
brew install xcodegen
xcodegen generate
open Similitude.xcodeproj
```

## CI / TestFlight

`ios-testflight.yml` runs two jobs:

1. **Build & Test** — every push/PR: generates the project with XcodeGen, builds unsigned for the simulator, runs unit tests, uploads logs.
2. **Archive & Upload** — pushes to `main` (or manual dispatch with `deploy: true`): signs via App Store Connect API cloud signing and uploads to TestFlight.

Required repository secrets (environment `testflight`):

| Secret | Description |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer ID |
| `ASC_KEY_P8` | Contents of the `.p8` API key |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `DIST_CERT_P12_BASE64` | *(optional)* Base64 distribution certificate, if not using cloud-managed signing |
| `DIST_CERT_PASSWORD` | *(optional)* Password for the p12 |

## Model packaging

The Photo2Cartoon Core ML model is packaged by `package-cartoonization-model.yml` (manual dispatch) into `SimilitudeCartoonizationModel.zip` plus a `model-manifest.json` with SHA256, published as a GitHub Release asset tagged `model-vX.Y.Z`. Model weights are never committed to the repository.

To publish a model:

1. Obtain a **commercially licensed** Photo2Cartoon model (`.mlmodel`, zipped `.mlpackage`/`.mlmodelc`, or `.onnx`). Verify its license permits App Store distribution.
2. Actions → *Package Cartoonization Model* → Run workflow with the model URL, format, and version.
3. The workflow compiles, size-checks, zips, hashes, and creates the release. The run summary prints the manifest URL.
4. The app's default manifest URL is `releases/latest/download/model-manifest.json`, so the newest `model-v*` release is picked up automatically. A different manifest URL can be tested via Profile → Developer → AI Model Diagnostics → override.

In-app pipeline (`Similitude/Services/Avatar/`): manifest fetch → zip download with progress → streaming SHA256 verification → extraction (ZIPFoundation) → expected-file validation → atomic install into Application Support → `MLModel` load with Neural Engine → pixel-buffer inference. Every step is tracked on the diagnostics screen.

## Build phases

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Navigation, Home, Studio tabs, shared camera/library pipeline, Vision detection, artistic filters | ✅ implemented |
| 2 | Resemblance scoring, feature explanations, disclaimers | pending |
| 3 | Photo2Cartoon packaging, download, checksum, diagnostics, inference | pending |
| 4 | Free/Premium gating, watermark, export limits, subscription UI | pending |
| 5 | Birthday / Graduation / Family Poster templates, layered renderer | pending |
| 6 | Timeline, history, polish, TestFlight acceptance | pending |
