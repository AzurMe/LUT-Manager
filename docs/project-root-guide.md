# LUT Manager Project Root Guide

这份文档说明项目根目录下每个文件和文件夹的用途，并记录当前 macOS 调试时使用的 Flutter 构建输出目录。

## Flutter 构建输出目录

由于项目位于 `~/Documents` 下，macOS/iCloud File Provider 可能会给构建产物添加 `com.apple.provenance` 等扩展属性，导致 `codesign` 报错：

```text
resource fork, Finder information, or similar detritus not allowed
```

为避开这个问题，[run_macos.command](../run_macos.command) 会在运行期间临时把 Flutter 构建目录指向项目根目录下的符号链接：

```text
.lut_manager_build -> /private/tmp/lut_manager_flutter_build
```

实际构建产物会写到：

```text
/private/tmp/lut_manager_flutter_build
```

macOS debug app 的实际路径是：

```text
/private/tmp/lut_manager_flutter_build/macos/Build/Products/Debug/lut_manager.app
```

在项目中也可以通过下面这个相对路径访问同一个 app：

```text
.lut_manager_build/macos/Build/Products/Debug/lut_manager.app
```

脚本退出时会把 Flutter 的全局 `build-dir` 配置恢复为默认的 `build`。根目录里的 `build/` 是历史或默认构建目录，可能还保留旧产物；不要手动编辑其中内容。

## 根目录文件和文件夹

| 路径 | 用途 |
| --- | --- |
| `.dart_tool/` | Dart/Flutter 工具生成的本地缓存目录，包含 package config 等运行时辅助文件。自动生成，不需要手动改。 |
| `.flutter-plugins-dependencies` | Flutter 根据插件依赖生成的记录文件，用于平台插件注册和构建。自动生成，依赖变化后可能更新。 |
| `.git/` | Git 仓库数据目录，保存版本历史、分支和远程配置。不要手动编辑。 |
| `.gitignore` | Git 忽略规则，控制哪些生成文件或本地文件不提交。 |
| `.idea/` | JetBrains/Android Studio/IntelliJ 项目配置目录。属于 IDE 配置。 |
| `.lut_manager_build` | 指向 `/private/tmp/lut_manager_flutter_build` 的符号链接，用于把 Flutter 构建产物放到 Documents 之外，避免 macOS codesign 扩展属性问题。 |
| `.metadata` | Flutter 项目元数据，记录项目类型、Flutter 版本迁移信息等。由 Flutter 管理。 |
| `README.md` | 项目主说明文档，介绍当前 Flutter 原型功能、运行方式、Tag 系统和元数据格式。 |
| `analysis_options.yaml` | Dart/Flutter 静态分析规则配置，`flutter analyze` 会读取它。 |
| `app.js` | 早期 Web/PWA 原型的主要 JavaScript 逻辑，保留作参考。当前主线开发在 Flutter 的 `lib/` 中。 |
| `assets/` | 项目资源目录。可用于存放图片、示例 LUT、字体等静态资源；当前 Flutter 是否打包资源需看 `pubspec.yaml` 的 assets 配置。 |
| `build/` | 默认 Flutter 构建输出目录或历史构建缓存。当前 macOS 一键脚本改用 `.lut_manager_build` 指向的临时目录。 |
| `data/` | 早期原型或后续数据文件预留目录，可用于示例 JSON/LUT 数据。 |
| `docs/` | 项目文档目录，包含 metadata schema、Tag taxonomy、需求文档和本说明文档。 |
| `index.html` | 早期 Web/PWA 原型入口页面。 |
| `ios/` | Flutter iOS 平台工程目录，用于 iPhone/iPad 构建。 |
| `lib/` | Flutter/Dart 主应用代码目录，是当前 LUT Manager 的核心实现。 |
| `lut_manager.iml` | JetBrains IDE 模块配置文件。 |
| `macos/` | Flutter macOS 平台工程目录，用于 macOS 桌面应用构建、签名、权限和 Runner 配置。 |
| `manifest.webmanifest` | 早期 Web/PWA 原型的 manifest 文件。 |
| `package.json` | 早期 Web 原型的 npm 脚本和依赖声明。Flutter 主项目不依赖它运行。 |
| `pubspec.lock` | Flutter/Dart 依赖锁定文件，记录当前解析到的具体 package 版本。应用项目通常应提交。 |
| `pubspec.yaml` | Flutter 项目配置文件，声明项目名称、版本、Dart SDK 范围和依赖。 |
| `run_macos.command` | macOS 一键调试脚本：检查 Flutter、设置临时构建目录、执行 `pub get`、`analyze`、`test`，最后运行 `flutter run -d macos`。 |
| `server.mjs` | 早期 Web/PWA 原型的本地开发服务器脚本。 |
| `styles.css` | 早期 Web/PWA 原型样式表。 |
| `test/` | Flutter 测试目录，包含 widget test 和 LUT 采样单元测试。 |
| `windows/` | Flutter Windows 平台工程目录，用于 Windows 桌面应用构建。 |

## 当前开发重点

当前主线是 Flutter 版本：

```text
lib/
macos/
ios/
windows/
test/
pubspec.yaml
pubspec.lock
run_macos.command
```

早期 Web 原型仍保留在根目录：

```text
index.html
app.js
styles.css
manifest.webmanifest
server.mjs
package.json
```

这些 Web 文件可以作为交互和功能参考，但新功能优先落到 Flutter 代码中。
