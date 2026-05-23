# FCPX LUT Syncer Requirements

## Background

LUT Manager needs a first practical integration with Final Cut Pro, commonly called FCPX. Final Cut Pro already supports importing 3D LUT files such as `.cube` and `.mga`, so the first integration should focus on reliable LUT installation and folder synchronization instead of a custom Final Cut plugin.

The current Flutter app already supports `.cube` import, validation, metadata, filtering, and export. The FCPX LUT Syncer should reuse that foundation and add a macOS-specific export/sync workflow.

## Goals

- Let users install selected LUTs from LUT Manager into a Final Cut Pro friendly folder structure.
- Support two user-facing targets: Camera LUTs and Custom LUT Effect packs.
- Preserve original LUT files and metadata; never mutate source LUT files.
- Track every LUT installed by LUT Manager so uninstall and resync operations are safe.
- Keep the first version implementable inside the existing Flutter macOS app.

## Non-Goals

- Do not build an FxPlug effect in the first version.
- Do not build a Final Cut Pro Workflow Extension in the first version.
- Do not automatically apply LUTs to clips on the Final Cut timeline.
- Do not parse or modify FCPXML in the first version.
- Do not depend on undocumented Final Cut internal databases or recent-LUT caches.

## Terminology

- Camera LUT: A technical LUT used by Final Cut Pro at the media/camera conversion level, usually for Log to Rec.709 or other camera color space transforms.
- Custom LUT Effect: A creative or technical LUT selected through the Final Cut Pro Custom LUT video effect.
- Managed LUT: A LUT copied or exported by LUT Manager and recorded in the sync manifest.
- Manifest: A JSON file owned by LUT Manager that records installed files, source IDs, hashes, target folders, and install timestamps.

## Target Users

- Video editors who organize LUTs in LUT Manager and want them available in Final Cut Pro.
- Creators with mixed camera systems who need camera/profile-based LUT folders.
- LUT pack authors who want to export clean FCP-ready LUT packs.

## MVP Scope

### Supported Platform

- macOS only.
- Runs from the existing Flutter macOS app.
- The UI should hide or disable FCPX sync controls on Windows, iOS, and web builds.

### Supported File Types

- Required: `.cube`
- Optional future support: `.mga`

The MVP should only install LUTs that pass current `.cube` validation.

### Sync Targets

#### Camera LUTs

Default target:

```text
~/Library/Application Support/ProApps/Camera LUTs/LUT Manager/
```

Use this target for LUTs tagged as:

- `function = Log Correction`
- `function = Display Transform`
- `workflow = Final Cut Pro`
- or user-selected target type: Camera LUT

Folder structure:

```text
LUT Manager/
  {cameraBrand}/
    {captureProfile}/
      {safeLutName}.cube
```

Examples:

```text
LUT Manager/Sony/S-Log3/Sony_FX3_SLog3_to_Rec709.cube
LUT Manager/Canon/C-Log3/Canon_CLog3_Natural_Rec709.cube
```

#### Custom LUT Pack

Default recommended target:

```text
~/Movies/LUT Manager/FCPX Custom LUTs/
```

The user must be allowed to choose a different folder.

Use this target for LUTs tagged as:

- `function = Creative Look`
- `function = Print Film Emulation`
- `style` is present
- or user-selected target type: Custom LUT Effect

Folder structure:

```text
FCPX Custom LUTs/
  {style}/
    {safeLutName}.cube
```

Examples:

```text
FCPX Custom LUTs/Filmic/Kodak_2383_Soft.cube
FCPX Custom LUTs/Clean Commercial/Skin_Safe_Warm.cube
```

Final Cut Pro users can then choose this folder when using the Custom LUT effect.

## Functional Requirements

### FR-1: FCPX Integration Panel

Add an FCPX integration entry point in the app. It may live in the LUT detail actions area first, then later move into a dedicated integrations screen.

Required controls:

- Install selected LUT
- Install all filtered LUTs
- Target selector:
  - Camera LUTs
  - Custom LUT Pack
- Folder structure selector:
  - By camera/profile
  - By style
  - Flat
- Choose custom export folder
- Open target folder
- Remove LUT Manager installed LUTs

### FR-2: LUT Eligibility

Before install, each selected LUT must be checked for:

- File extension is `.cube`.
- File can be read.
- `CubeLut.parse` succeeds.
- LUT has valid `LUT_3D_SIZE`.
- LUT row count matches declared size.

Invalid LUTs should be skipped and shown in a post-sync result summary.

### FR-3: Filename Sanitization

Installed file names must be stable and filesystem safe.

Rules:

- Prefer `record.name`.
- Fall back to `record.fileName` without extension.
- Replace path separators and reserved characters with `_`.
- Collapse repeated spaces/underscores.
- Append `.cube`.
- If a destination file already exists and is not the same content hash, append a short hash suffix.

Example:

```text
Sony FX3 / S-Log3 -> Sony_FX3_S-Log3.cube
Sony FX3 / S-Log3 duplicate -> Sony_FX3_S-Log3_a13f9c.cube
```

### FR-4: Manifest

Each managed target root must contain a manifest:

```text
.lut-manager-fcpx-manifest.json
```

Manifest shape:

```json
{
  "schemaVersion": 1,
  "managedBy": "LUT Manager",
  "target": "fcpx-camera-luts",
  "targetRoot": "/Users/name/Library/Application Support/ProApps/Camera LUTs/LUT Manager",
  "installedAt": "2026-05-23T00:00:00.000Z",
  "items": [
    {
      "recordId": "sony-slog3-rec709",
      "recordName": "Sony S-Log3 to Rec.709",
      "sourceFileName": "Sony_SLog3.cube",
      "sourceRelativePath": "Sony/SLog3/Sony_SLog3.cube",
      "contentHash": "sha256...",
      "installedRelativePath": "Sony/S-Log3/Sony_S-Log3_to_Rec709.cube",
      "targetType": "cameraLut",
      "installedAt": "2026-05-23T00:00:00.000Z"
    }
  ]
}
```

The manifest is the only source of truth for uninstalling managed LUTs.

### FR-5: Safe Install

Install behavior:

- Create missing target directories.
- Copy LUT files rather than moving them.
- Never overwrite an unmanaged file.
- If the file is already installed with the same content hash, treat it as up to date.
- If the same record changed content hash, replace only the previously managed file from the manifest.
- Write the manifest atomically after all file operations complete.

### FR-6: Safe Uninstall

Uninstall behavior:

- Read the manifest first.
- Delete only files listed in the manifest.
- Delete empty directories created under the managed root after file deletion.
- Never delete files that are not listed in the manifest.
- Never delete files outside the managed root.
- If a listed file has changed and no longer matches the manifest hash, skip deletion and report it.

### FR-7: Permissions

The macOS app must request user authorization before writing to the Final Cut Pro Camera LUT folder.

Implementation guidance:

- For a sandboxed build, use a directory picker and store a security-scoped bookmark for the authorized target directory.
- If direct write access fails, show an authorization flow instead of failing silently.
- The user should be able to reset or change the authorized FCPX target folder.

### FR-8: Sync Result Summary

After each install or uninstall, show a summary:

- Installed count
- Updated count
- Skipped count
- Failed count
- Target folder
- Action to open target folder

The summary should list invalid or failed LUTs with short reasons.

### FR-9: FCPX Refresh Guidance

After installing Camera LUTs, show a short instruction:

```text
If the LUTs do not appear in Final Cut Pro, restart Final Cut Pro and check the Camera LUT menu again.
```

After exporting a Custom LUT Pack, show:

```text
In Final Cut Pro, add Effects > Color > Custom LUT, then choose this exported folder from the LUT menu.
```

## Data and Metadata Mapping

Use existing `LutRecord` fields where possible:

- `id` -> manifest `recordId`
- `name` -> display name and base filename
- `fileName` -> source file name
- `relativePath` -> source relative path if available
- `contentHash` or `fileHash` -> manifest hash
- `cameraCompatibility.brand` -> camera folder
- `cameraCompatibility.profile` -> capture profile folder
- `tagValue(LutTagType.function)` -> target suggestion
- `tagValue(LutTagType.style)` -> style folder

If metadata is missing:

- Camera brand folder: `Generic`
- Capture profile folder: `Unspecified Profile`
- Style folder: `Uncategorized`

## Proposed Implementation

### New Service

Create:

```text
lib/services/fcpx_lut_installer.dart
```

Suggested API:

```dart
enum FcpxLutTargetType {
  cameraLut,
  customLutPack,
}

enum FcpxFolderStrategy {
  cameraProfile,
  style,
  flat,
}

class FcpxInstallRequest {
  const FcpxInstallRequest({
    required this.records,
    required this.targetType,
    required this.folderStrategy,
    required this.targetRoot,
  });
}

class FcpxInstallResult {
  const FcpxInstallResult({
    required this.installed,
    required this.updated,
    required this.skipped,
    required this.failed,
  });
}

class FcpxLutInstaller {
  Future<FcpxInstallResult> install(FcpxInstallRequest request);
  Future<FcpxInstallResult> uninstallManagedLuts(Directory targetRoot);
  Future<File> writeManifest(FcpxManifest manifest);
  Future<FcpxManifest?> readManifest(Directory targetRoot);
}
```

### Native Utilities

May require small macOS-specific helpers for:

- Opening target folder in Finder.
- Resolving `~/Library/Application Support/...`.
- Persisting security-scoped bookmarks if the app is sandboxed.

Keep the sync logic in Dart where possible. Only use native Swift for macOS APIs that Dart packages cannot handle cleanly.

## UI Copy

Panel title:

```text
Final Cut Pro Sync
```

Target descriptions:

```text
Camera LUTs: best for Log conversion and technical transforms.
Custom LUT Pack: best for creative looks used with the Custom LUT effect.
```

Permission prompt:

```text
Choose your Final Cut Pro Camera LUT folder so LUT Manager can install and update managed LUTs.
```

Safety note:

```text
LUT Manager only removes files it installed itself.
```

## Acceptance Criteria

- A user can install one valid `.cube` LUT to the Camera LUT target.
- A user can install multiple filtered `.cube` LUTs to a Custom LUT Pack folder.
- Invalid `.cube` files are skipped with visible reasons.
- Re-running sync does not create duplicate files for unchanged LUTs.
- Updating a managed LUT replaces the previous managed copy.
- Uninstall removes only manifest-listed files under the managed root.
- Uninstall skips files whose hashes no longer match the manifest.
- The app can open the target folder after sync.
- The UI provides clear Final Cut Pro next-step instructions.
- Non-macOS platforms do not expose active FCPX install actions.

## Future Enhancements

- Add `.mga` support.
- Add FCPXML metadata export for LUT usage notes.
- Add a native Final Cut Pro Workflow Extension.
- Add FxPlug effect for direct LUT Manager browsing inside Final Cut Pro.
- Add project-specific LUT bundles that can travel with client deliverables.
- Add validation for color space metadata and warnings for mismatched source/output transforms.

## References

- Final Cut Pro Apply LUTs: https://support.apple.com/guide/final-cut-pro/apply-luts-ver24f966423/mac
- Final Cut Pro XML exchange: https://support.apple.com/guide/final-cut-pro/use-xml-to-transfer-projects-verdbd66ae/mac
- Final Cut Pro Workflow Extensions: https://support.apple.com/en-us/101630
