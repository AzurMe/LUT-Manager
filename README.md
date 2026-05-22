# LUT Manager

LUT Manager is a cross-platform camera LUT library, preview, metadata, and LUT creation app.

The production direction is now Flutter. The earlier zero-dependency Web/PWA prototype is still kept in the repository as a reference implementation for `.cube` parsing and browser-based interaction experiments.

## Current Flutter Prototype

Implemented in `lib/`:

- Material 3 desktop/mobile layout with a Codex-like neutral UI direction.
- Light and dark theme switching.
- LUT library with search.
- Typed Tag filtering instead of a flat category list.
- LUT details, sidecar JSON preview, cloud path fields, and camera compatibility.
- Before/After preview canvas using a generated reference frame.
- Native file dialogs via Flutter's `file_selector` package.
- Reference image loading for preview comparison.
- `.cube` file import with 3D LUT validation.
- `.cube` export through native save dialogs.
- Metadata JSON import/export for sync-folder workflows.
- HSL-style custom LUT controls.
- Generated `.cube` text copy and custom LUT creation inside the in-memory library.

## Tag System

Typed tags make filtering predictable. Current tag types include:

- Camera: `cameraCategory`, `cameraBrand`, `cameraModel`, `captureProfile`
- Purpose: `function`, `workflow`, `intensity`
- Look: `style`, `shadowTone`, `highlightTone`, `colorBias`, `skinTone`
- Usage: `lightingScene`, `author`

See `docs/tag-taxonomy.md` for the full taxonomy.

## Running Flutter

Flutter SDK is expected at `/Users/kmy/flutter/bin/flutter` on this machine unless PATH is updated.

```bash
/Users/kmy/flutter/bin/flutter pub get
/Users/kmy/flutter/bin/flutter run -d macos
```

For Windows or iOS:

```bash
/Users/kmy/flutter/bin/flutter run -d windows
/Users/kmy/flutter/bin/flutter run -d ios
```

Generated platform folders are included for iOS, macOS, and Windows. macOS entitlements include user-selected file read/write access for importing LUTs, choosing sync folders, and saving generated `.cube` files.

## Web Prototype

The old browser prototype can still be run with:

```bash
npm run dev
```

Then open:

```text
http://127.0.0.1:4173
```

## Metadata

LUT Manager stores metadata as JSON sidecar records so original LUT files remain untouched.

- `docs/metadata-schema.json` - sidecar schema draft
- `docs/lut-record-example.json` - example record
- `docs/tag-taxonomy.md` - typed tag taxonomy

## Planned Native Modules

- Apply imported 3D LUT data directly to reference photos.
- Persist metadata automatically between launches.
- Persistent local database for metadata and recent reference images.
- Hash-based duplicate detection.
- Native export panel for `.cube`, `.3dl`, and app metadata bundles.
