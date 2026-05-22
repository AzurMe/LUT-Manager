import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sample_luts.dart';
import '../models/look_adjustment.dart';
import '../models/lut_record.dart';
import '../models/lut_tag.dart';
import '../services/cube_lut.dart';
import '../theme/codex_theme.dart';

enum WorkspacePanel { preview, metadata, maker }

class LutManagerHome extends StatefulWidget {
  const LutManagerHome({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<LutManagerHome> createState() => _LutManagerHomeState();
}

class _LutManagerHomeState extends State<LutManagerHome> {
  late final TextEditingController _searchController;
  late List<LutRecord> _records;
  late String _selectedId;
  final Set<String> _selectedTagKeys = <String>{};
  WorkspacePanel _panel = WorkspacePanel.preview;
  double _split = 0.5;
  LookAdjustment _makerLook = const LookAdjustment(
    contrast: 0.08,
    saturation: 0.1,
    highlightRollOff: 0.12,
  );
  String _makerName = 'My HSL Look';
  String _makerCamera = 'Sony FX3 / S-Log3';
  String _syncFolderLabel = '尚未选择同步文件夹';
  Uint8List? _referenceImageBytes;

  @override
  void initState() {
    super.initState();
    _records = List<LutRecord>.from(sampleLuts);
    _selectedId = _records.first.id;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LutRecord get _selectedRecord {
    return _records.firstWhere(
      (record) => record.id == _selectedId,
      orElse: () => _records.first,
    );
  }

  List<LutRecord> get _filteredRecords {
    return _records
        .where((record) => record.containsQuery(_searchController.text))
        .where((record) => record.matchesTags(_selectedTagKeys))
        .toList();
  }

  Map<LutTagType, List<LutTag>> get _tagGroups {
    final grouped = LinkedHashMap<LutTagType, LinkedHashMap<String, LutTag>>();
    for (final type in LutTagType.values) {
      grouped[type] = LinkedHashMap<String, LutTag>();
    }
    for (final record in _records) {
      for (final tag in record.tags) {
        grouped[tag.type]?[tag.key] = tag;
      }
    }
    return grouped.map(
      (type, tags) => MapEntry(type, tags.values.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1180) {
            return Row(
              children: [
                SizedBox(
                  width: 332,
                  child: _LibraryPane(
                    records: _filteredRecords,
                    selectedId: _selectedId,
                    searchController: _searchController,
                    tagGroups: _tagGroups,
                    selectedTagKeys: _selectedTagKeys,
                    themeMode: widget.themeMode,
                    syncFolderLabel: _syncFolderLabel,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    onSearchChanged: () => setState(() {}),
                    onToggleTag: _toggleTag,
                    onClearTags: _clearTags,
                    onSelectRecord: _selectRecord,
                    onChooseSyncFolder: _chooseSyncFolder,
                    onImportMetadata: _importMetadataBundle,
                    onExportMetadata: _exportMetadataBundle,
                  ),
                ),
                Expanded(
                  child: _WorkspacePane(
                    record: _selectedRecord,
                    panel: _panel,
                    split: _split,
                    makerLook: _makerLook,
                    referenceImageBytes: _referenceImageBytes,
                    onPickReferenceImage: _pickReferenceImage,
                    onImportCube: _importCubeFile,
                    onPanelChanged: (panel) => setState(() => _panel = panel),
                    onSplitChanged: (value) => setState(() => _split = value),
                  ),
                ),
                SizedBox(
                  width: 382,
                  child: _InspectorPane(
                    record: _selectedRecord,
                    panel: _panel,
                    makerLook: _makerLook,
                    makerName: _makerName,
                    makerCamera: _makerCamera,
                    onMakerLookChanged: (look) => setState(() => _makerLook = look),
                    onMakerNameChanged: (value) => _makerName = value,
                    onMakerCameraChanged: (value) => _makerCamera = value,
                    onAddGenerated: _addGeneratedLut,
                    onCopyCube: _copyGeneratedCube,
                    onSaveCube: _saveGeneratedCube,
                    onCopyMetadata: _copyMetadata,
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _LibraryPane(
                    records: _filteredRecords,
                    selectedId: _selectedId,
                    searchController: _searchController,
                    tagGroups: _tagGroups,
                    selectedTagKeys: _selectedTagKeys,
                    themeMode: widget.themeMode,
                    syncFolderLabel: _syncFolderLabel,
                    onThemeModeChanged: widget.onThemeModeChanged,
                    onSearchChanged: () => setState(() {}),
                    onToggleTag: _toggleTag,
                    onClearTags: _clearTags,
                    onSelectRecord: _selectRecord,
                    onChooseSyncFolder: _chooseSyncFolder,
                    onImportMetadata: _importMetadataBundle,
                    onExportMetadata: _exportMetadataBundle,
                    compact: true,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 680,
                    child: _WorkspacePane(
                      record: _selectedRecord,
                      panel: _panel,
                      split: _split,
                      makerLook: _makerLook,
                      referenceImageBytes: _referenceImageBytes,
                      onPickReferenceImage: _pickReferenceImage,
                      onImportCube: _importCubeFile,
                      onPanelChanged: (panel) => setState(() => _panel = panel),
                      onSplitChanged: (value) => setState(() => _split = value),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _InspectorPane(
                    record: _selectedRecord,
                    panel: _panel,
                    makerLook: _makerLook,
                    makerName: _makerName,
                    makerCamera: _makerCamera,
                    onMakerLookChanged: (look) => setState(() => _makerLook = look),
                    onMakerNameChanged: (value) => _makerName = value,
                    onMakerCameraChanged: (value) => _makerCamera = value,
                    onAddGenerated: _addGeneratedLut,
                    onCopyCube: _copyGeneratedCube,
                    onSaveCube: _saveGeneratedCube,
                    onCopyMetadata: _copyMetadata,
                    compact: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleTag(LutTag tag) {
    setState(() {
      if (_selectedTagKeys.contains(tag.key)) {
        _selectedTagKeys.remove(tag.key);
      } else {
        _selectedTagKeys.add(tag.key);
      }
    });
  }

  void _clearTags() {
    setState(_selectedTagKeys.clear);
  }

  void _selectRecord(LutRecord record) {
    setState(() {
      _selectedId = record.id;
      if (_panel == WorkspacePanel.maker) _panel = WorkspacePanel.preview;
    });
  }

  void _addGeneratedLut() {
    final now = DateTime.now();
    final camera = _parseCamera(_makerCamera);
    final record = LutRecord(
      id: 'lut_custom_${now.microsecondsSinceEpoch}',
      name: _makerName.trim().isEmpty ? 'My HSL Look' : _makerName.trim(),
      fileName: '${_slugify(_makerName)}.cube',
      cameraCompatibility: [camera],
      author: '用户自定义',
      colorStyle: _summarizeLook(_makerLook),
      tags: [
        LutTag(type: LutTagType.cameraBrand, value: camera.brand),
        LutTag(type: LutTagType.captureProfile, value: camera.profile),
        const LutTag(type: LutTagType.function, value: '创意风格'),
        const LutTag(type: LutTagType.style, value: '自定义'),
        const LutTag(type: LutTagType.workflow, value: 'Generated in LUT Manager'),
      ],
      notes: '由 Flutter 版 HSL 控制生成。下一步接入文件系统后可直接保存 .cube 到同步目录。',
      look: _makerLook,
      cloudProvider: 'Local Folder',
      relativePath: '${_slugify(_makerName)}.cube',
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _records = [record, ..._records];
      _selectedId = record.id;
      _panel = WorkspacePanel.preview;
    });
    _showMessage('已把自定义 LUT 加入库');
  }

  Future<void> _copyGeneratedCube() async {
    await Clipboard.setData(
      ClipboardData(text: _generateCubeText(_makerName, _makerLook)),
    );
    _showMessage('.cube 文本已复制');
  }

  Future<void> _saveGeneratedCube() async {
    final fileName = '${_slugify(_makerName)}.cube';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;

    final textFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(_generateCubeText(_makerName, _makerLook))),
      mimeType: 'text/plain',
      name: fileName,
    );
    await textFile.saveTo(location.path);
    _showMessage('已保存 $fileName');
  }

  Future<void> _pickReferenceImage() async {
    const imageTypeGroup = XTypeGroup(
      label: 'Reference images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      uniformTypeIdentifiers: ['public.jpeg', 'public.png', 'org.webmproject.webp'],
    );
    final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _referenceImageBytes = bytes);
    _showMessage('已载入参考照片：${file.name}');
  }

  Future<void> _importCubeFile() async {
    const cubeTypeGroup = XTypeGroup(
      label: '3D LUT',
      extensions: ['cube'],
      mimeTypes: ['text/plain'],
      uniformTypeIdentifiers: ['public.plain-text'],
    );
    final file = await openFile(acceptedTypeGroups: [cubeTypeGroup]);
    if (file == null) return;

    final text = await file.readAsString();
    final CubeLut cube;
    try {
      cube = CubeLut.parse(text);
    } on FormatException catch (error) {
      _showMessage('无法导入 ${file.name}: ${error.message}');
      return;
    }

    final now = DateTime.now();
    final name = cube.title.isEmpty
        ? file.name.replaceAll(RegExp(r'\.cube$', caseSensitive: false), '')
        : cube.title;
    final record = LutRecord(
      id: 'lut_imported_${now.microsecondsSinceEpoch}',
      name: name,
      fileName: file.name,
      cameraCompatibility: const [
        CameraCompatibility(
          brand: '通用',
          models: ['未指定'],
          profile: '未指定',
          category: 'Imported',
        ),
      ],
      author: '导入',
      colorStyle: '导入的 ${cube.size}³ 3D LUT。可继续编辑 Tag 和元数据。',
      tags: const [
        LutTag(type: LutTagType.function, value: '导入 LUT'),
        LutTag(type: LutTagType.style, value: '未标记'),
        LutTag(type: LutTagType.workflow, value: 'Imported'),
      ],
      notes: '从 .cube 文件导入。当前版本先记录元数据并校验 LUT 数据，后续会把 3D LUT 实时应用到参考照片。',
      look: LookAdjustment.neutral,
      cloudProvider: 'Local Folder',
      relativePath: file.path,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _records = [record, ..._records];
      _selectedId = record.id;
      _panel = WorkspacePanel.metadata;
    });
    _showMessage('已导入 ${file.name}');
  }

  Future<void> _copyMetadata() async {
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(_selectedRecord.toJson())),
    );
    _showMessage('当前 LUT 元数据已复制');
  }

  Future<void> _chooseSyncFolder() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() => _syncFolderLabel = path);
    _showMessage('同步文件夹已选择');
  }

  Future<void> _exportMetadataBundle() async {
    const encoder = JsonEncoder.withIndent('  ');
    const fileName = 'lut-manager-metadata.json';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;

    final payload = {
      'app': 'LUT Manager',
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'syncFolder': _syncFolderLabel,
      'luts': _records.map((record) => record.toJson()).toList(),
    };
    final metadataFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(encoder.convert(payload))),
      mimeType: 'application/json',
      name: fileName,
    );
    await metadataFile.saveTo(location.path);
    _showMessage('元数据已导出');
  }

  Future<void> _importMetadataBundle() async {
    const jsonTypeGroup = XTypeGroup(
      label: 'LUT Manager metadata',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );
    final file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
    if (file == null) return;

    try {
      final decoded = jsonDecode(await file.readAsString());
      final rawRecords = decoded is List<Object?>
          ? decoded
          : (decoded as Map<String, Object?>)['luts'] as List<Object?>;
      final importedRecords = rawRecords
          .whereType<Map<Object?, Object?>>()
          .map(
            (map) => LutRecord.fromJson(
              map.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((record) => record.id.isNotEmpty)
          .toList();
      if (importedRecords.isEmpty) {
        _showMessage('没有找到可导入的 LUT 记录');
        return;
      }

      final byId = {for (final record in _records) record.id: record};
      for (final record in importedRecords) {
        byId[record.id] = record;
      }
      setState(() {
        _records = byId.values.toList();
        _selectedId = importedRecords.first.id;
      });
      _showMessage('已导入 ${importedRecords.length} 条元数据');
    } catch (_) {
      _showMessage('元数据导入失败，请检查 JSON 格式');
    }
  }

  CameraCompatibility _parseCamera(String input) {
    final parts = input.split('/').map((part) => part.trim()).toList();
    final brandAndModel = parts.isEmpty ? '通用 未指定' : parts.first;
    final profile = parts.length > 1 ? parts[1] : '未指定';
    final words = brandAndModel.split(RegExp(r'\s+'));
    return CameraCompatibility(
      brand: words.isEmpty ? '通用' : words.first,
      models: [words.length <= 1 ? '未指定' : words.skip(1).join(' ')],
      profile: profile,
      category: 'Custom',
    );
  }

  String _slugify(String input) {
    final fallback = input.trim().isEmpty ? 'my_hsl_look' : input.trim();
    return fallback
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _summarizeLook(LookAdjustment look) {
    final parts = <String>[];
    if (look.contrast.abs() > 0.01) parts.add('对比 ${(look.contrast * 100).round()}');
    if (look.saturation.abs() > 0.01) parts.add('饱和 ${(look.saturation * 100).round()}');
    if (look.temperature.abs() > 0.01) parts.add('色温 ${(look.temperature * 100).round()}');
    if (look.highlightRollOff.abs() > 0.01) {
      parts.add('高光保护 ${(look.highlightRollOff * 100).round()}');
    }
    return parts.isEmpty ? '自然 HSL 调整' : parts.join('、');
  }

  String _generateCubeText(String title, LookAdjustment look) {
    const size = 17;
    final lines = <String>[
      'TITLE "${title.replaceAll('"', "'")}"',
      '# Generated by LUT Manager Flutter prototype',
      'LUT_3D_SIZE $size',
      'DOMAIN_MIN 0.0 0.0 0.0',
      'DOMAIN_MAX 1.0 1.0 1.0',
    ];

    for (var b = 0; b < size; b += 1) {
      for (var g = 0; g < size; g += 1) {
        for (var r = 0; r < size; r += 1) {
          final color = Color.fromARGB(
            255,
            (255 * r / (size - 1)).round(),
            (255 * g / (size - 1)).round(),
            (255 * b / (size - 1)).round(),
          );
          final graded = gradeColor(color, look);
          lines.add(
            '${graded.r.toStringAsFixed(6)} '
            '${graded.g.toStringAsFixed(6)} '
            '${graded.b.toStringAsFixed(6)}',
          );
        }
      }
    }
    return '${lines.join('\n')}\n';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LibraryPane extends StatelessWidget {
  const _LibraryPane({
    required this.records,
    required this.selectedId,
    required this.searchController,
    required this.tagGroups,
    required this.selectedTagKeys,
    required this.themeMode,
    required this.syncFolderLabel,
    required this.onThemeModeChanged,
    required this.onSearchChanged,
    required this.onToggleTag,
    required this.onClearTags,
    required this.onSelectRecord,
    required this.onChooseSyncFolder,
    required this.onImportMetadata,
    required this.onExportMetadata,
    this.compact = false,
  });

  final List<LutRecord> records;
  final String selectedId;
  final TextEditingController searchController;
  final Map<LutTagType, List<LutTag>> tagGroups;
  final Set<String> selectedTagKeys;
  final ThemeMode themeMode;
  final String syncFolderLabel;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<LutTag> onToggleTag;
  final VoidCallback onClearTags;
  final ValueChanged<LutRecord> onSelectRecord;
  final VoidCallback onChooseSyncFolder;
  final VoidCallback onImportMetadata;
  final VoidCallback onExportMetadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<CodexPalette>()!;
    final content = ListView(
      padding: EdgeInsets.all(compact ? 16 : 20),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
                color: theme.colorScheme.surfaceContainerHigh,
              ),
              child: Text(
                'LM',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LUT Manager',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Camera LUT Studio',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: themeMode == ThemeMode.dark ? '切换浅色' : '切换深色',
              onPressed: () => onThemeModeChanged(
                themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              ),
              icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: searchController,
          onChanged: (_) => onSearchChanged(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜索 LUT、相机、作者、Tag',
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Tag 筛选',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (selectedTagKeys.isNotEmpty)
              TextButton.icon(
                onPressed: onClearTags,
                icon: const Icon(Icons.close, size: 16),
                label: Text('${selectedTagKeys.length}'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ...tagGroups.entries
            .where((entry) => entry.value.isNotEmpty)
            .map(
              (entry) => _TagGroup(
                type: entry.key,
                tags: entry.value,
                selectedTagKeys: selectedTagKeys,
                onToggleTag: onToggleTag,
              ),
            ),
        const SizedBox(height: 20),
        Text(
          '匹配结果 ${records.length}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '没有找到匹配的 LUT。可以减少 Tag 条件，或清空搜索词。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LutCard(
                record: record,
                selected: record.id == selectedId,
                onTap: () => onSelectRecord(record),
              ),
            ),
          ),
        const SizedBox(height: 10),
        _SyncCard(
          syncFolderLabel: syncFolderLabel,
          onChooseSyncFolder: onChooseSyncFolder,
          onImportMetadata: onImportMetadata,
          onExportMetadata: onExportMetadata,
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.sidebar,
        border: Border(
          right: compact ? BorderSide.none : BorderSide(color: palette.sidebarBorder),
          bottom: compact ? BorderSide(color: palette.sidebarBorder) : BorderSide.none,
        ),
      ),
      child: compact ? SizedBox(height: 760, child: content) : content,
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.syncFolderLabel,
    required this.onChooseSyncFolder,
    required this.onImportMetadata,
    required this.onExportMetadata,
  });

  final String syncFolderLabel;
  final VoidCallback onChooseSyncFolder;
  final VoidCallback onImportMetadata;
  final VoidCallback onExportMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '同步与元数据',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              syncFolderLabel,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onChooseSyncFolder,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('同步文件夹'),
                ),
                OutlinedButton.icon(
                  onPressed: onImportMetadata,
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('导入 JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: onExportMetadata,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('导出 JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.type,
    required this.tags,
    required this.selectedTagKeys,
    required this.onToggleTag,
  });

  final LutTagType type;
  final List<LutTag> tags;
  final Set<String> selectedTagKeys;
  final ValueChanged<LutTag> onToggleTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.value),
                  selected: selectedTagKeys.contains(tag.key),
                  avatar: Icon(_tagIcon(type), size: 16),
                  onSelected: (_) => onToggleTag(tag),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LutCard extends StatelessWidget {
  const _LutCard({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final LutRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
          : theme.cardTheme.color,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${record.functionLabel} · ${record.author}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                record.primaryCamera,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspacePane extends StatelessWidget {
  const _WorkspacePane({
    required this.record,
    required this.panel,
    required this.split,
    required this.makerLook,
    required this.referenceImageBytes,
    required this.onPickReferenceImage,
    required this.onImportCube,
    required this.onPanelChanged,
    required this.onSplitChanged,
  });

  final LutRecord record;
  final WorkspacePanel panel;
  final double split;
  final LookAdjustment makerLook;
  final Uint8List? referenceImageBytes;
  final VoidCallback onPickReferenceImage;
  final VoidCallback onImportCube;
  final ValueChanged<WorkspacePanel> onPanelChanged;
  final ValueChanged<double> onSplitChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLook = panel == WorkspacePanel.maker ? makerLook : record.look;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview Lab',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          record.name,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
    final headerActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: onPickReferenceImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('参考照片'),
        ),
        OutlinedButton.icon(
          onPressed: onImportCube,
          icon: const Icon(Icons.upload_file),
          label: const Text('导入 .cube'),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                headerActions,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                headerActions,
              ],
            ),
          const SizedBox(height: 18),
          Expanded(
            child: Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<WorkspacePanel>(
                          segments: const [
                            ButtonSegment(
                              value: WorkspacePanel.preview,
                              icon: Icon(Icons.compare),
                              label: Text('预览'),
                            ),
                            ButtonSegment(
                              value: WorkspacePanel.metadata,
                              icon: Icon(Icons.data_object),
                              label: Text('元数据'),
                            ),
                            ButtonSegment(
                              value: WorkspacePanel.maker,
                              icon: Icon(Icons.tune),
                              label: Text('生成 LUT'),
                            ),
                          ],
                          selected: {panel},
                          onSelectionChanged: (selection) => onPanelChanged(selection.first),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(
                            '${record.primaryCamera}  ·  ${record.colorStyle}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _PreviewCanvas(
                                referenceImageBytes: referenceImageBytes,
                                painter: _ReferencePreviewPainter(
                                  look: activeLook,
                                  split: split,
                                  isDark: theme.brightness == Brightness.dark,
                                ),
                                look: activeLook,
                                split: split,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(
                                'Before',
                                style: theme.textTheme.labelMedium,
                              ),
                              Expanded(
                                child: Slider(
                                  value: split,
                                  onChanged: onSplitChanged,
                                  min: 0.05,
                                  max: 0.95,
                                ),
                              ),
                              Text(
                                'After',
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorPane extends StatelessWidget {
  const _InspectorPane({
    required this.record,
    required this.panel,
    required this.makerLook,
    required this.makerName,
    required this.makerCamera,
    required this.onMakerLookChanged,
    required this.onMakerNameChanged,
    required this.onMakerCameraChanged,
    required this.onAddGenerated,
    required this.onCopyCube,
    required this.onSaveCube,
    required this.onCopyMetadata,
    this.compact = false,
  });

  final LutRecord record;
  final WorkspacePanel panel;
  final LookAdjustment makerLook;
  final String makerName;
  final String makerCamera;
  final ValueChanged<LookAdjustment> onMakerLookChanged;
  final ValueChanged<String> onMakerNameChanged;
  final ValueChanged<String> onMakerCameraChanged;
  final VoidCallback onAddGenerated;
  final VoidCallback onCopyCube;
  final VoidCallback onSaveCube;
  final VoidCallback onCopyMetadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<CodexPalette>()!;
    final children = [
      if (panel == WorkspacePanel.preview) _RecordDetails(record: record),
      if (panel == WorkspacePanel.metadata)
        _MetadataPanel(record: record, onCopyMetadata: onCopyMetadata),
      if (panel == WorkspacePanel.maker)
        _MakerPanel(
          look: makerLook,
          makerName: makerName,
          makerCamera: makerCamera,
          onLookChanged: onMakerLookChanged,
          onNameChanged: onMakerNameChanged,
          onCameraChanged: onMakerCameraChanged,
          onAddGenerated: onAddGenerated,
          onCopyCube: onCopyCube,
          onSaveCube: onSaveCube,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact ? theme.colorScheme.surface : palette.sidebar,
        border: Border(
          left: compact ? BorderSide.none : BorderSide(color: palette.sidebarBorder),
          top: compact ? BorderSide(color: palette.sidebarBorder) : BorderSide.none,
        ),
      ),
      child: compact
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: children),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: children,
            ),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.record});

  final LutRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: '功能', value: record.functionLabel)),
            const SizedBox(width: 10),
            Expanded(child: _Metric(label: '作者', value: record.author)),
          ],
        ),
        const SizedBox(height: 10),
        _InfoBlock(label: '适配相机', value: record.cameraCompatibility.map((item) => item.label).join('\n')),
        const SizedBox(height: 10),
        _InfoBlock(label: '颜色风格', value: record.colorStyle),
        const SizedBox(height: 14),
        Text(
          'Tags',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in record.tags)
              Chip(
                avatar: Icon(_tagIcon(tag.type), size: 16),
                label: Text('${tag.type.label}: ${tag.value}'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoBlock(label: '备注', value: record.notes),
        const SizedBox(height: 10),
        _InfoBlock(
          label: '同步位置',
          value: '${record.cloudProvider}\n${record.relativePath}',
        ),
      ],
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({
    required this.record,
    required this.onCopyMetadata,
  });

  final LutRecord record;
  final VoidCallback onCopyMetadata;

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(record.toJson());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sidecar JSON',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onCopyMetadata,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              json,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MakerPanel extends StatelessWidget {
  const _MakerPanel({
    required this.look,
    required this.makerName,
    required this.makerCamera,
    required this.onLookChanged,
    required this.onNameChanged,
    required this.onCameraChanged,
    required this.onAddGenerated,
    required this.onCopyCube,
    required this.onSaveCube,
  });

  final LookAdjustment look;
  final String makerName;
  final String makerCamera;
  final ValueChanged<LookAdjustment> onLookChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCameraChanged;
  final VoidCallback onAddGenerated;
  final VoidCallback onCopyCube;
  final VoidCallback onSaveCube;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自定义 LUT',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: makerName,
          onChanged: onNameChanged,
          decoration: const InputDecoration(
            labelText: 'LUT 名称',
            prefixIcon: Icon(Icons.drive_file_rename_outline),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: makerCamera,
          onChanged: onCameraChanged,
          decoration: const InputDecoration(
            labelText: '相机 / Profile',
            prefixIcon: Icon(Icons.photo_camera_outlined),
          ),
        ),
        const SizedBox(height: 16),
        _AdjustmentSlider(
          label: '曝光',
          value: look.exposure,
          onChanged: (value) => onLookChanged(look.copyWith(exposure: value)),
        ),
        _AdjustmentSlider(
          label: '对比',
          value: look.contrast,
          onChanged: (value) => onLookChanged(look.copyWith(contrast: value)),
        ),
        _AdjustmentSlider(
          label: '饱和',
          value: look.saturation,
          onChanged: (value) => onLookChanged(look.copyWith(saturation: value)),
        ),
        _AdjustmentSlider(
          label: '明度',
          value: look.luminance,
          onChanged: (value) => onLookChanged(look.copyWith(luminance: value)),
        ),
        _AdjustmentSlider(
          label: '色温',
          value: look.temperature,
          onChanged: (value) => onLookChanged(look.copyWith(temperature: value)),
        ),
        _AdjustmentSlider(
          label: '色调',
          value: look.tint,
          onChanged: (value) => onLookChanged(look.copyWith(tint: value)),
        ),
        _AdjustmentSlider(
          label: '色相',
          value: look.hueShift,
          onChanged: (value) => onLookChanged(look.copyWith(hueShift: value)),
        ),
        _AdjustmentSlider(
          label: '阴影抬升',
          value: look.shadowLift,
          onChanged: (value) => onLookChanged(look.copyWith(shadowLift: value)),
        ),
        _AdjustmentSlider(
          label: '高光保护',
          value: look.highlightRollOff,
          onChanged: (value) => onLookChanged(look.copyWith(highlightRollOff: value)),
        ),
        _AdjustmentSlider(
          label: '红饱和',
          value: look.redSaturation,
          onChanged: (value) => onLookChanged(look.copyWith(redSaturation: value)),
        ),
        _AdjustmentSlider(
          label: '绿饱和',
          value: look.greenSaturation,
          onChanged: (value) => onLookChanged(look.copyWith(greenSaturation: value)),
        ),
        _AdjustmentSlider(
          label: '蓝饱和',
          value: look.blueSaturation,
          onChanged: (value) => onLookChanged(look.copyWith(blueSaturation: value)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddGenerated,
                icon: const Icon(Icons.library_add),
                label: const Text('加入库'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSaveCube,
                icon: const Icon(Icons.save_alt),
                label: const Text('保存 .cube'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCopyCube,
            icon: const Icon(Icons.copy),
            label: const Text('复制 .cube 文本'),
          ),
        ),
      ],
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.referenceImageBytes,
    required this.painter,
    required this.look,
    required this.split,
  });

  final Uint8List? referenceImageBytes;
  final CustomPainter painter;
  final LookAdjustment look;
  final double split;

  @override
  Widget build(BuildContext context) {
    final bytes = referenceImageBytes;
    if (bytes == null) {
      return CustomPaint(
        painter: painter,
        child: const SizedBox.expand(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final splitX = width * split;
        Widget image({required bool graded}) {
          final child = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
          if (!graded) return child;
          return ColorFiltered(
            colorFilter: ColorFilter.matrix(_lookFilterMatrix(look)),
            child: child,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            image(graded: true),
            ClipRect(
              clipper: _SplitClipper(split),
              child: image(graded: false),
            ),
            Positioned(
              left: splitX - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.white.withValues(alpha: 0.86)),
            ),
            Positioned(
              left: splitX - 7,
              bottom: 24,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFAEBBFF),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 14, height: 14),
              ),
            ),
            const Positioned(
              left: 14,
              top: 14,
              child: _PreviewLabel('Before'),
            ),
            const Positioned(
              right: 14,
              top: 14,
              child: _PreviewLabel('After'),
            ),
          ],
        );
      },
    );
  }
}

class _SplitClipper extends CustomClipper<Rect> {
  const _SplitClipper(this.split);

  final double split;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * split, size.height);

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) => oldClipper.split != split;
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

List<double> _lookFilterMatrix(LookAdjustment look) {
  final saturation = (1 + look.saturation).clamp(0.0, 2.4).toDouble();
  final contrast = (1 + look.contrast).clamp(0.1, 2.4).toDouble();
  final brightness = (look.exposure + look.luminance) * 45;
  final temperature = look.temperature * 34;
  final tint = look.tint * 26;
  final offset = 128 * (1 - contrast) + brightness;

  final invSat = 1 - saturation;
  final rLum = 0.213 * invSat;
  final gLum = 0.715 * invSat;
  final bLum = 0.072 * invSat;

  return [
    (rLum + saturation) * contrast,
    gLum * contrast,
    bLum * contrast,
    0,
    offset + temperature + tint * 0.35,
    rLum * contrast,
    (gLum + saturation) * contrast,
    bLum * contrast,
    0,
    offset - tint,
    rLum * contrast,
    gLum * contrast,
    (bLum + saturation) * contrast,
    0,
    offset - temperature + tint * 0.35,
    0,
    0,
    0,
    1,
    0,
  ];
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Expanded(
                child: Slider(
                  min: -1,
                  max: 1,
                  value: value,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(value * 100).round()}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ReferencePreviewPainter extends CustomPainter {
  const _ReferencePreviewPainter({
    required this.look,
    required this.split,
    required this.isDark,
  });

  final LookAdjustment look;
  final double split;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = isDark ? const Color(0xFF07080A) : const Color(0xFFD9D9D5);
    canvas.drawRect(Offset.zero & size, bg);

    final frame = _largestRect(size, const Size(16, 10)).deflate(12);
    final radius = BorderRadius.circular(8).toRRect(frame);
    canvas.drawRRect(radius, Paint()..color = isDark ? const Color(0xFF111315) : Colors.white);

    canvas.save();
    canvas.clipRRect(radius);
    _drawReferenceScene(canvas, frame, look);
    final splitX = frame.left + frame.width * split;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(frame.left, frame.top, splitX, frame.bottom));
    _drawReferenceScene(canvas, frame, LookAdjustment.neutral);
    canvas.restore();

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(splitX, frame.top), Offset(splitX, frame.bottom), linePaint);
    canvas.drawCircle(
      Offset(splitX, frame.bottom - 30),
      7,
      Paint()..color = const Color(0xFFAEBBFF),
    );
    _drawLabel(canvas, frame.topLeft + const Offset(14, 14), 'Before');
    _drawLabel(canvas, Offset(frame.right - 76, frame.top + 14), 'After');
    canvas.restore();

    canvas.drawRRect(
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: isDark ? 0.11 : 0.38),
    );
  }

  Rect _largestRect(Size available, Size ratio) {
    final targetRatio = ratio.width / ratio.height;
    final currentRatio = available.width / available.height;
    double width = available.width;
    double height = available.height;
    if (currentRatio > targetRatio) {
      width = height * targetRatio;
    } else {
      height = width / targetRatio;
    }
    return Rect.fromLTWH(
      (available.width - width) / 2,
      (available.height - height) / 2,
      width,
      height,
    );
  }

  void _drawReferenceScene(Canvas canvas, Rect rect, LookAdjustment activeLook) {
    Color c(Color color) => gradeColor(color, activeLook);
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          c(const Color(0xFFCFD8D9)),
          c(const Color(0xFFD8B487)),
          c(const Color(0xFF587786)),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    final far = Path()
      ..moveTo(rect.left, rect.top + rect.height * 0.5)
      ..cubicTo(
        rect.left + rect.width * 0.22,
        rect.top + rect.height * 0.32,
        rect.left + rect.width * 0.36,
        rect.top + rect.height * 0.48,
        rect.left + rect.width * 0.55,
        rect.top + rect.height * 0.37,
      )
      ..cubicTo(
        rect.left + rect.width * 0.7,
        rect.top + rect.height * 0.28,
        rect.left + rect.width * 0.83,
        rect.top + rect.height * 0.45,
        rect.right,
        rect.top + rect.height * 0.34,
      )
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    canvas.drawPath(far, Paint()..color = c(const Color(0xFF8EAAA4)));

    final near = Path()
      ..moveTo(rect.left, rect.top + rect.height * 0.67)
      ..cubicTo(
        rect.left + rect.width * 0.2,
        rect.top + rect.height * 0.58,
        rect.left + rect.width * 0.38,
        rect.top + rect.height * 0.7,
        rect.left + rect.width * 0.62,
        rect.top + rect.height * 0.58,
      )
      ..cubicTo(
        rect.left + rect.width * 0.8,
        rect.top + rect.height * 0.48,
        rect.left + rect.width * 0.9,
        rect.top + rect.height * 0.68,
        rect.right,
        rect.top + rect.height * 0.6,
      )
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    canvas.drawPath(near, Paint()..color = c(const Color(0xFF294A43)));

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.08,
        rect.top + rect.height * 0.21,
        rect.width * 0.32,
        rect.height * 0.26,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(card, Paint()..color = c(const Color(0xFFF0EEE5)));
    final swatchTop = card.outerRect.top + card.outerRect.height * 0.58;
    final swatchHeight = card.outerRect.height * 0.42;
    final swatchWidth = card.outerRect.width / 3;
    final swatches = [
      const Color(0xFFD85E48),
      const Color(0xFFE9B15F),
      const Color(0xFF5D9B72),
    ];
    for (var i = 0; i < swatches.length; i += 1) {
      canvas.drawRect(
        Rect.fromLTWH(card.outerRect.left + swatchWidth * i, swatchTop, swatchWidth, swatchHeight),
        Paint()..color = c(swatches[i]),
      );
    }

    final bodyRect = Rect.fromLTWH(
      rect.left + rect.width * 0.64,
      rect.top + rect.height * 0.23,
      rect.width * 0.18,
      rect.height * 0.36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(24)),
      Paint()..color = c(const Color(0xFFD39B73)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyRect.center.dx - 4, bodyRect.top + bodyRect.height * 0.42),
        width: bodyRect.width * 0.55,
        height: bodyRect.height * 0.48,
      ),
      Paint()..color = c(const Color(0xFFF0C79D)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyRect.center.dx, bodyRect.top + bodyRect.height * 0.18),
        width: bodyRect.width * 0.82,
        height: bodyRect.height * 0.38,
      ),
      Paint()..color = c(const Color(0xFF50382E)),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Reference Frame',
        style: TextStyle(
          color: c(Colors.white).withValues(alpha: 0.88),
          fontWeight: FontWeight.w800,
          fontSize: rect.width * 0.028,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: card.outerRect.width - 20);
    textPainter.paint(canvas, card.outerRect.topLeft + const Offset(12, 16));
  }

  void _drawLabel(Canvas canvas, Offset offset, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx - 8, offset.dy - 5, painter.width + 16, painter.height + 10),
      const Radius.circular(4),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.42));
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ReferencePreviewPainter oldDelegate) {
    return oldDelegate.look != look ||
        oldDelegate.split != split ||
        oldDelegate.isDark != isDark;
  }
}

Color gradeColor(Color color, LookAdjustment look) {
  final hsl = HSLColor.fromColor(color);
  final redWeight = _hueWeight(hsl.hue, 0);
  final greenWeight = _hueWeight(hsl.hue, 120);
  final blueWeight = _hueWeight(hsl.hue, 240);
  final channelSaturation = look.redSaturation * redWeight +
      look.greenSaturation * greenWeight +
      look.blueSaturation * blueWeight;
  final temperatureHue = look.temperature * -8;
  final tintHue = look.tint * 5;
  final hue = (hsl.hue + look.hueShift * 180 + temperatureHue + tintHue) % 360;
  var saturation = hsl.saturation * (1 + look.saturation + channelSaturation);
  var lightness = hsl.lightness + look.exposure * 0.16 + look.luminance * 0.14;
  lightness = (lightness - 0.5) * (1 + look.contrast) + 0.5;
  if (lightness < 0.46) {
    lightness += look.shadowLift * (0.46 - lightness) * 0.8;
  }
  if (lightness > 0.58) {
    lightness -= look.highlightRollOff * (lightness - 0.58) * 0.8;
  }
  saturation = saturation.clamp(0.0, 1.0).toDouble();
  lightness = lightness.clamp(0.0, 1.0).toDouble();
  return hsl.withHue(hue).withSaturation(saturation).withLightness(lightness).toColor();
}

double _hueWeight(double hue, double center) {
  final distance = math.min((hue - center).abs(), 360 - (hue - center).abs());
  return (1 - distance / 70).clamp(0.0, 1.0).toDouble();
}

IconData _tagIcon(LutTagType type) {
  switch (type) {
    case LutTagType.cameraCategory:
      return Icons.category;
    case LutTagType.cameraBrand:
      return Icons.business;
    case LutTagType.cameraModel:
      return Icons.photo_camera;
    case LutTagType.captureProfile:
      return Icons.tune;
    case LutTagType.function:
      return Icons.build_circle;
    case LutTagType.style:
      return Icons.palette;
    case LutTagType.shadowTone:
      return Icons.dark_mode;
    case LutTagType.highlightTone:
      return Icons.light_mode;
    case LutTagType.colorBias:
      return Icons.color_lens;
    case LutTagType.skinTone:
      return Icons.face;
    case LutTagType.lightingScene:
      return Icons.wb_sunny;
    case LutTagType.workflow:
      return Icons.account_tree;
    case LutTagType.intensity:
      return Icons.speed;
    case LutTagType.author:
      return Icons.person;
  }
}
