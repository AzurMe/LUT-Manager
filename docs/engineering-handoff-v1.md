# LUT Manager V1 Engineering Handoff

本文档用于把第一阶段 Flutter 版 LUT Manager 的研发成果同步给下一位研发。当前日期：2026-05-23。

## 项目状态

LUT Manager 已从早期 Web/PWA 原型转向 Flutter 主线。当前版本已经具备第一版核心闭环：

- 管理 LUT 记录和元数据
- 导入 `.cube` 并校验 3D LUT 数据
- 对参考照片真实应用 `.cube` 生成 Before/After 预览
- 导出套用当前 LUT 后的参考照片，支持 PNG/JPEG
- 用 3D RGB 立方体投影查看 LUT 对 RGB 的偏移方向
- 自动保存本地 LUT 库状态
- 选择同步文件夹后生成/读取 `.lutmanager.json` sidecar
- 记录重复检测指纹，包括文件 hash 和归一化 LUT 内容 hash
- 折叠式 Tag 筛选
- 主流相机品牌/型号/Profile 预置 Tag
- 元数据和 Tag 表单编辑
- sidecar JSON 直接编辑
- HSL 风格 LUT 生成、复制 `.cube`、保存 `.cube`
- 选中已有 LUT 时，生成器会切换为“在 LUT 基础上修改”，输出基础 LUT 叠加 HSL 调整后的新 `.cube`
- 生成 LUT 滑杆双击复位
- 浅色/深色 Codex-like 视觉风格

## 运行与验证

macOS 一键调试：

```bash
./run_macos.command
```

脚本会执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

手动验证：

```bash
flutter analyze
flutter test
flutter build macos --debug
```

当前验证结果：

```text
flutter analyze -> No issues found
flutter test -> 3 tests passed
```

## macOS 构建目录

项目位于 `~/Documents` 下时，macOS/iCloud File Provider 可能给 `.app` 添加 `com.apple.provenance` 等扩展属性，引发 codesign 失败：

```text
resource fork, Finder information, or similar detritus not allowed
```

当前 workaround 在 [run_macos.command](../run_macos.command) 中：

```text
.lut_manager_build -> /private/tmp/lut_manager_flutter_build
```

实际 macOS debug app 输出：

```text
/private/tmp/lut_manager_flutter_build/macos/Build/Products/Debug/lut_manager.app
```

脚本退出时会把 Flutter 全局 `build-dir` 恢复为默认 `build`。`.lut_manager_build` 已加入 `.gitignore`。

macOS Runner 里也加了 `Clear Extended Attributes` build phase，作为辅助防护；核心绕过仍是临时构建目录。

## 关键目录

| 路径 | 说明 |
| --- | --- |
| `lib/main.dart` | Flutter app 入口，初始化主题状态和首页。 |
| `lib/ui/lut_manager_home.dart` | 主界面与主要交互逻辑，包含库列表、预览、元数据、LUT 生成器。 |
| `lib/models/` | `LutRecord`、`LutTag`、`LookAdjustment` 等核心数据模型。 |
| `lib/services/cube_lut.dart` | `.cube` 解析、归一化、三线性采样。 |
| `lib/services/lut_image_processor.dart` | 对参考照片应用 3D LUT，输出 PNG 预览 bytes。 |
| `lib/services/lut_library_repository.dart` | 本地库保存/读取和 `.lutmanager.json` sidecar 保存/读取。 |
| `lib/data/camera_tag_catalog.dart` | 主流相机品牌、型号、类别、Profile 预置 Tag。 |
| `lib/data/sample_luts.dart` | Demo LUT 记录。无本地库时作为初始数据。 |
| `lib/theme/codex_theme.dart` | 浅色/深色 Codex-like Material 3 主题。 |
| `test/` | Widget test 和 LUT 采样单元测试。 |
| `docs/` | 需求、schema、Tag catalog、项目结构与本交接文档。 |
| `macos/` | macOS Runner 工程、entitlements、签名与构建配置。 |
| `ios/` / `windows/` | iOS 和 Windows 平台工程目录。 |

早期 Web 原型仍保留在根目录：`index.html`、`app.js`、`styles.css`、`server.mjs`、`package.json`。新功能优先落到 Flutter。

## 核心数据流

### 启动

1. `LutManagerHome.initState()` 先载入 `sampleLuts`。
2. `_loadLibraryState()` 从 `LutLibraryRepository` 读取本地 `lut-manager-library.json`。
3. 如果保存过同步文件夹路径，会继续读取该文件夹下的 `.lutmanager.json`。
4. 本地记录和 sidecar 记录按 `id` 合并，`updatedAt` 较新的记录优先。

### 导入 `.cube`

1. `file_selector` 打开原生文件选择器。
2. 读取文件 bytes，计算 `fileHash`。
3. `CubeLut.parse()` 解析 `LUT_3D_SIZE` 和 RGB 数据。
4. 用 `normalizedContent` 计算 `contentHash`，用于忽略标题、注释、空白差异的重复检测。
5. 检测重复后生成 `LutRecord`。
6. 保存到本地库；如果有同步文件夹，同步写入 `.lutmanager.json`。
7. 缓存 `CubeLut` 并刷新参考图预览。

### 参考照片预览

1. 用户选择参考照片后保存 bytes 到 `_referenceImageBytes`。
2. `_refreshCubePreview()` 根据当前选中 LUT 读取或生成 `CubeLut`。
3. `LutImageProcessor.applyCube()` 把图片最长边限制到 1600px，然后逐像素采样 LUT。
4. 预览区显示原图 Before 和 LUT 处理后的 After。

### 图片导出

1. 用户在 Preview Lab 顶部导出菜单选择 PNG 或 JPEG。
2. `_exportGradedReferenceImage()` 读取当前参考图；普通预览导出当前选中 LUT，生成器页导出“基础 LUT + 当前 HSL 调整”的结果。
3. `LutImageProcessor.applyCube()` 使用原始参考图尺寸重新应用 LUT。
4. 用 `XFile.fromData()` 保存为目标格式。

### 基于 LUT 二次生成

1. `_makerBaseRecord` 使用当前库中选中的 LUT 作为可选基础。
2. `_generateMakerCubeText()` 读取基础 `CubeLut`；没有基础 LUT 时退回中性输入。
3. `_generateCubeText()` 对每个 17³ 采样点先采样基础 LUT，再用 `gradeColor()` 叠加 HSL 控件调整。
4. 复制、保存、加入库和生成器页导出都共用这条路径。

### LUT 查看

1. Preview Lab 的 `LUT 查看` 页签读取当前 `CubeLut`。
2. `_LutImpactPainter` 把 RGB 立方体投影到 2D 平面。
3. 每个采样点从原始 RGB 位置画到 LUT 输出 RGB 位置，线和点使用输出色。
4. `_LutImpactStats` 显示平均 `ΔR/ΔG/ΔB` 和最大偏移。

### Sidecar

本地状态文件由平台 application support directory 管理，文件名：

```text
lut-manager-library.json
```

同步文件夹 sidecar 文件名：

```text
.lutmanager.json
```

sidecar 结构：

```json
{
  "app": "LUT Manager",
  "schemaVersion": 3,
  "updatedAt": "2026-05-23T00:00:00.000",
  "syncFolderPath": "/path/to/LUTs",
  "luts": []
}
```

`.cube` 原文件不会被修改。元数据、Tag、hash、路径等都保存在 JSON 中。

## Tag 体系

Tag 类型定义在 `lib/models/lut_tag.dart`，当前包括：

- `cameraCategory`
- `cameraBrand`
- `cameraModel`
- `captureProfile`
- `function`
- `style`
- `shadowTone`
- `highlightTone`
- `colorBias`
- `skinTone`
- `lightingScene`
- `workflow`
- `intensity`
- `author`

折叠式 Tag UI 在 `_TagGroup`。预置相机 Tag 来自 `cameraTagCatalog`，用户自己的库记录也会合并到筛选列表中。

筛选逻辑在 `LutRecord.matchesTags()`。它不仅看显式 `tags`，也会把 `cameraCompatibility` 里的品牌、型号、类别、Profile 当作虚拟 Tag 匹配，避免用户选择 `FX3` 这类型号时漏掉记录。

相机 Tag 来源和维护规则见 [camera-tag-catalog.md](camera-tag-catalog.md)。

## 关键实现说明

- `.cube` 只支持当前常见 3D LUT 数据流，未完整支持 1D LUT 或复杂 domain 映射。
- `CubeLut.sample()` 使用三线性插值，假设 `.cube` 数据顺序为 red fastest, green next, blue slowest。
- `LutImageProcessor` 当前在 Dart 层处理预览图片，并把最长边限制到 1600px。未来做高分辨率导出时应迁到 isolate 或原生/GPU 管线。
- 导出图片目前在 Dart 层同步处理，包在 `Future` 中避免直接阻塞调用栈；大图批量导出时仍应迁移到 isolate。
- 自定义 LUT 生成使用 `LookAdjustment` 和 `gradeColor()` 生成 17³ `.cube`。
- 参考照片本身暂不持久化；重启后需要重新选择参考照片。
- 同步目前是“文件夹 + sidecar”策略，不是 iCloud/Dropbox/OneDrive API 集成。实际同步由用户的云盘客户端完成。
- 编辑 JSON 时会解析回 `LutRecord` 并更新 `updatedAt`，然后持久化。
- 记录路径支持绝对路径和相对同步文件夹路径。相对路径由 `_resolveRecordPath()` 解析。

## 测试

当前测试：

- `test/widget_test.dart`
  - 首页能渲染 sample library
  - 主题切换按钮可用
- `test/cube_lut_test.dart`
  - identity 3D LUT 的三线性采样结果正确

建议下一步增加：

- `.cube` parser 对注释、TITLE、非法尺寸、非法行数的单元测试
- duplicate detection 的单元测试
- sidecar merge 的单元测试
- metadata JSON edit 的 widget test
- Tag 折叠/筛选交互测试

## 已知限制

- 没有批量导入文件夹。
- 没有监听同步文件夹变化。
- 没有最近参考照片历史。
- 已支持导出当前参考图的 LUT 处理结果；还没有批量导出或导出队列。
- 没有真正的云服务 OAuth/API，只依赖本地同步文件夹。
- iOS/Windows 平台目录已生成，但主要验证集中在 macOS。
- 相机品牌/型号列表是人工维护的 seed catalog，后续需要定期更新。
- 当前 UI 的大量状态还集中在 `LutManagerHome`，后续功能变大时应拆分状态管理和 service。

## 下一阶段建议

1. 加入批量 `.cube` 导入和重复检测汇总结果。
2. 加入同步文件夹扫描，自动发现 `.cube` 和 sidecar。
3. 增加最近参考照片与项目级参考照片集合。
4. 把图片处理移到 isolate，避免大图预览卡 UI。
5. 引入更完整的 LUT parser，支持 DOMAIN_MIN/MAX、1D LUT、不同 LUT 格式转换。
6. 把元数据编辑 UI 拆分成独立 widget，便于测试。
7. 增加 Riverpod/Bloc 等状态管理，降低 `lut_manager_home.dart` 体积。
8. 做 iOS 和 Windows 真机/实机文件权限验证。
9. 增加 release 打包脚本和签名/公证流程。
10. 设计正式 app icon、空状态、错误状态和 onboarding。

## 相关文档

- [project-root-guide.md](project-root-guide.md)
- [camera-tag-catalog.md](camera-tag-catalog.md)
- [metadata-schema.json](metadata-schema.json)
- [lut-record-example.json](lut-record-example.json)
- [tag-taxonomy.md](tag-taxonomy.md)
- [fcpx-lut-syncer-requirements.md](fcpx-lut-syncer-requirements.md)
