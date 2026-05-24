import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/camera_tag_catalog.dart';
import '../data/sample_luts.dart';
import '../models/look_adjustment.dart';
import '../models/lut_record.dart';
import '../models/lut_tag.dart';
import '../services/cube_lut.dart';
import '../services/lut_image_processor.dart';
import '../services/lut_library_repository.dart';
import '../theme/codex_theme.dart';

enum WorkspacePanel { preview, lutView, metadata, maker }

enum DuplicateKind { file, content }

class _DuplicateMatch {
  const _DuplicateMatch({required this.kind, required this.existingRecord});

  final DuplicateKind kind;
  final LutRecord existingRecord;
}

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
  final LutLibraryRepository _repository = LutLibraryRepository();
  final LutImageProcessor _imageProcessor = const LutImageProcessor();
  final Map<String, CubeLut> _cubeCache = <String, CubeLut>{};
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
  String? _syncFolderPath;
  Uint8List? _referenceImageBytes;
  Uint8List? _gradedReferenceImageBytes;
  String? _gradedRecordId;
  CubeLut? _activeCube;
  String? _activeCubeRecordId;
  bool _isProcessingPreview = false;
  bool _isLoadingCube = false;
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    _records = List<LutRecord>.from(sampleLuts);
    _selectedId = _records.first.id;
    _searchController = TextEditingController();
    _loadLibraryState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryState() async {
    final state = await _repository.loadLibraryState();
    if (!mounted) return;
    setState(() {
      _records = state.records;
      _selectedId = _records.isEmpty ? '' : _records.first.id;
      _syncFolderPath = state.syncFolderPath;
      _syncFolderLabel = state.syncFolderPath == null
          ? '尚未选择同步文件夹'
          : '${state.syncFolderPath}\nsidecar: ${LutLibraryRepository.sidecarFileName}';
    });
    await _readSyncSidecarIfAvailable();
    await _refreshCubePreview();
  }

  Future<void> _persistLibraryState() async {
    await _repository.saveLibraryState(
      LutLibraryState(records: _records, syncFolderPath: _syncFolderPath),
    );
    final folderPath = _syncFolderPath;
    if (folderPath != null && folderPath.isNotEmpty) {
      await _repository.saveSidecar(folderPath, _records);
    }
  }

  Future<void> _readSyncSidecarIfAvailable() async {
    final folderPath = _syncFolderPath;
    if (folderPath == null || folderPath.isEmpty) return;
    try {
      final sidecarRecords = await _repository.loadSidecar(folderPath);
      if (sidecarRecords.isEmpty) {
        await _repository.saveSidecar(folderPath, _records);
        return;
      }
      _mergeRecords(sidecarRecords);
      await _persistLibraryState();
    } catch (_) {
      _showMessage('同步文件夹 sidecar 读取失败，将继续使用本地库');
    }
  }

  void _mergeRecords(List<LutRecord> incomingRecords) {
    final byId = {for (final record in _records) record.id: record};
    for (final incoming in incomingRecords) {
      final current = byId[incoming.id];
      if (current == null || incoming.updatedAt.isAfter(current.updatedAt)) {
        byId[incoming.id] = incoming;
      }
    }
    setState(() {
      _records = byId.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (_records.isNotEmpty &&
          !_records.any((record) => record.id == _selectedId)) {
        _selectedId = _records.first.id;
      }
    });
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

  LutRecord? get _makerBaseRecord {
    for (final record in _records) {
      if (record.id == _selectedId) return record;
    }
    return _records.isEmpty ? null : _records.first;
  }

  Map<LutTagType, List<LutTag>> get _tagGroups {
    final grouped = LinkedHashMap<LutTagType, LinkedHashMap<String, LutTag>>();
    for (final type in LutTagType.values) {
      grouped[type] = LinkedHashMap<String, LutTag>();
    }
    // Seed common camera tags first, then merge tags discovered from the library.
    for (final tag in cameraTagCatalog) {
      grouped[tag.type]?[tag.key] = tag;
    }
    for (final record in _records) {
      for (final tag in record.tags) {
        grouped[tag.type]?[tag.key] = tag;
      }
    }
    return grouped.map((type, tags) => MapEntry(type, tags.values.toList()));
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
                    makerBaseName: _makerBaseRecord?.name,
                    referenceImageBytes: _referenceImageBytes,
                    gradedReferenceImageBytes: _gradedRecordId == _selectedId
                        ? _gradedReferenceImageBytes
                        : null,
                    activeCube: _activeCubeRecordId == _selectedId
                        ? _activeCube
                        : null,
                    isProcessingPreview: _isProcessingPreview,
                    isLoadingCube: _isLoadingCube,
                    onPickReferenceImage: _pickReferenceImage,
                    onImportCube: _importCubeFile,
                    onExportImage: _exportGradedReferenceImage,
                    onPanelChanged: _setPanel,
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
                    makerBaseName: _makerBaseRecord?.name,
                    onMakerLookChanged: _updateMakerLook,
                    onMakerNameChanged: (value) => _makerName = value,
                    onMakerCameraChanged: (value) => _makerCamera = value,
                    onAddGenerated: _addGeneratedLut,
                    onCopyCube: _copyGeneratedCube,
                    onSaveCube: _saveGeneratedCube,
                    onCopyMetadata: _copyMetadata,
                    onSaveMetadataJson: _saveSelectedMetadataJson,
                    onEditMetadata: _editSelectedMetadata,
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
                      makerBaseName: _makerBaseRecord?.name,
                      referenceImageBytes: _referenceImageBytes,
                      gradedReferenceImageBytes: _gradedRecordId == _selectedId
                          ? _gradedReferenceImageBytes
                          : null,
                      activeCube: _activeCubeRecordId == _selectedId
                          ? _activeCube
                          : null,
                      isProcessingPreview: _isProcessingPreview,
                      isLoadingCube: _isLoadingCube,
                      onPickReferenceImage: _pickReferenceImage,
                      onImportCube: _importCubeFile,
                      onExportImage: _exportGradedReferenceImage,
                      onPanelChanged: _setPanel,
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
                    makerBaseName: _makerBaseRecord?.name,
                    onMakerLookChanged: _updateMakerLook,
                    onMakerNameChanged: (value) => _makerName = value,
                    onMakerCameraChanged: (value) => _makerCamera = value,
                    onAddGenerated: _addGeneratedLut,
                    onCopyCube: _copyGeneratedCube,
                    onSaveCube: _saveGeneratedCube,
                    onCopyMetadata: _copyMetadata,
                    onSaveMetadataJson: _saveSelectedMetadataJson,
                    onEditMetadata: _editSelectedMetadata,
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
    _refreshCubePreview();
  }

  void _setPanel(WorkspacePanel panel) {
    setState(() => _panel = panel);
    _refreshCubePreview();
  }

  void _updateMakerLook(LookAdjustment look) {
    setState(() => _makerLook = look);
    if (_panel == WorkspacePanel.maker) {
      _refreshCubePreview();
    }
  }

  Future<void> _addGeneratedLut() async {
    final now = DateTime.now();
    final camera = _parseCamera(_makerCamera);
    final baseRecord = _makerBaseRecord;
    final cubeText = await _generateMakerCubeText();
    final cube = CubeLut.parse(cubeText);
    final fileHash = _hashText(cubeText);
    final contentHash = _hashText(cube.normalizedContent);
    final duplicate = _findDuplicate(
      fileHash: fileHash,
      contentHash: contentHash,
    );
    if (duplicate != null) {
      final shouldImport = await _confirmDuplicateImport(duplicate);
      if (!shouldImport) {
        _showMessage('已跳过重复 LUT：$_makerName');
        return;
      }
    }

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
        LutTag(
          type: LutTagType.workflow,
          value: baseRecord == null
              ? 'Generated in LUT Manager'
              : 'Modified from existing LUT',
        ),
      ],
      notes: baseRecord == null
          ? '由 Flutter 版 HSL 控制生成。'
          : '基于 ${baseRecord.name} 叠加 HSL 控制生成。',
      look: _makerLook,
      cloudProvider: 'Local Folder',
      relativePath: '${_slugify(_makerName)}.cube',
      fileHash: fileHash,
      contentHash: contentHash,
      lutSize: 17,
      sourceFileSize: utf8.encode(cubeText).length,
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _records = [record, ..._records];
      _selectedId = record.id;
      _panel = WorkspacePanel.preview;
    });
    _cubeCache[record.id] = cube;
    await _persistLibraryState();
    await _refreshCubePreview();
    _showMessage('已把自定义 LUT 加入库');
  }

  Future<void> _copyGeneratedCube() async {
    await Clipboard.setData(
      ClipboardData(text: await _generateMakerCubeText()),
    );
    _showMessage('.cube 文本已复制');
  }

  Future<void> _saveGeneratedCube() async {
    final fileName = '${_slugify(_makerName)}.cube';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;

    final cubeText = await _generateMakerCubeText();
    final textFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(cubeText)),
      mimeType: 'text/plain',
      name: fileName,
    );
    await textFile.saveTo(location.path);
    _showMessage('已保存 $fileName');
  }

  Future<void> _exportGradedReferenceImage(LutImageFormat format) async {
    final sourceBytes = _referenceImageBytes;
    if (sourceBytes == null) {
      _showMessage('请先载入参考照片');
      return;
    }

    final record = _selectedRecord;
    final isMakerExport = _panel == WorkspacePanel.maker;
    final cube = isMakerExport
        ? await _loadMakerCube()
        : await _loadCubeForRecord(record);
    if (cube == null) {
      _showMessage('当前 LUT 无法用于导出');
      return;
    }

    final extension = format == LutImageFormat.png ? 'png' : 'jpg';
    final mimeType = format == LutImageFormat.png ? 'image/png' : 'image/jpeg';
    final exportName = isMakerExport ? _makerName : record.name;
    final suggestedName = '${_slugify(exportName)}_graded.$extension';
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return;

    try {
      _showMessage('正在导出套用 LUT 后的图片...');
      final bytes = await Future<Uint8List>(
        () => _imageProcessor.applyCube(
          sourceBytes: sourceBytes,
          cube: cube,
          maxEdge: null,
          format: format,
        ),
      );
      final imageFile = XFile.fromData(
        bytes,
        mimeType: mimeType,
        name: suggestedName,
      );
      await imageFile.saveTo(location.path);
      _showMessage('已导出 ${format == LutImageFormat.png ? 'PNG' : 'JPEG'} 图片');
    } catch (_) {
      _showMessage('图片导出失败，请换一张参考照片或检查保存位置');
    }
  }

  Future<void> _pickReferenceImage() async {
    const imageTypeGroup = XTypeGroup(
      label: 'Reference images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      uniformTypeIdentifiers: [
        'public.jpeg',
        'public.png',
        'org.webmproject.webp',
      ],
    );
    final file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _referenceImageBytes = bytes);
    await _refreshCubePreview();
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

    final bytes = await file.readAsBytes();
    final fileHash = _hashBytes(bytes);
    final text = utf8.decode(bytes, allowMalformed: true);
    final CubeLut cube;
    try {
      cube = CubeLut.parse(text);
    } on FormatException catch (error) {
      _showMessage('无法导入 ${file.name}: ${error.message}');
      return;
    }

    final now = DateTime.now();
    final contentHash = _hashText(cube.normalizedContent);
    final duplicate = _findDuplicate(
      fileHash: fileHash,
      contentHash: contentHash,
    );
    if (duplicate != null) {
      if (!mounted) return;
      final shouldImport = await _confirmDuplicateImport(duplicate);
      if (!shouldImport) {
        _showMessage('已跳过重复 LUT：${file.name}');
        return;
      }
    }

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
      notes: '从 .cube 文件导入。载入参考照片后会用 3D LUT 生成真实 After 预览。',
      look: LookAdjustment.neutral,
      cloudProvider: 'Local Folder',
      relativePath: file.path,
      fileHash: fileHash,
      contentHash: contentHash,
      lutSize: cube.size,
      sourceFileSize: bytes.length,
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    setState(() {
      _records = [record, ..._records];
      _selectedId = record.id;
      _panel = WorkspacePanel.metadata;
    });
    _cubeCache[record.id] = cube;
    await _persistLibraryState();
    await _refreshCubePreview();
    _showMessage('已导入 ${file.name}');
  }

  String _hashBytes(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';

  String _hashText(String text) => _hashBytes(utf8.encode(text));

  _DuplicateMatch? _findDuplicate({
    required String fileHash,
    required String contentHash,
  }) {
    for (final record in _records) {
      if (record.fileHash.isNotEmpty && record.fileHash == fileHash) {
        return _DuplicateMatch(
          kind: DuplicateKind.file,
          existingRecord: record,
        );
      }
    }
    for (final record in _records) {
      if (record.contentHash.isNotEmpty && record.contentHash == contentHash) {
        return _DuplicateMatch(
          kind: DuplicateKind.content,
          existingRecord: record,
        );
      }
    }
    return null;
  }

  Future<bool> _confirmDuplicateImport(_DuplicateMatch duplicate) async {
    final kindLabel = duplicate.kind == DuplicateKind.file
        ? '文件完全相同'
        : 'LUT 内容相同';
    final existing = duplicate.existingRecord;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('检测到重复 LUT'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kindLabel),
                  const SizedBox(height: 12),
                  Text('已存在：${existing.name}'),
                  Text('文件：${existing.fileName}'),
                  if (existing.lutSize != null) Text('尺寸：${existing.lutSize}³'),
                  const SizedBox(height: 12),
                  const Text('你可以跳过导入，也可以仍然导入为一个副本。'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('跳过导入'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('仍然导入副本'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<CubeLut?> _loadCubeForRecord(LutRecord record) async {
    final cached = _cubeCache[record.id];
    if (cached != null) return cached;

    if (record.author == '用户自定义') {
      final cube = CubeLut.parse(_generateCubeText(record.name, record.look));
      _cubeCache[record.id] = cube;
      return cube;
    }

    final path = _resolveRecordPath(record);
    if (path.isEmpty) return _fallbackCubeForRecord(record);
    final file = File(path);
    if (!await file.exists()) return _fallbackCubeForRecord(record);

    try {
      final cube = CubeLut.parse(await file.readAsString());
      _cubeCache[record.id] = cube;
      return cube;
    } catch (_) {
      return _fallbackCubeForRecord(record);
    }
  }

  CubeLut _fallbackCubeForRecord(LutRecord record) {
    final cube = CubeLut.parse(_generateCubeText(record.name, record.look));
    _cubeCache[record.id] = cube;
    return cube;
  }

  String _resolveRecordPath(LutRecord record) {
    final path = record.relativePath.trim();
    if (path.isEmpty || File(path).isAbsolute) return path;
    // Sidecar paths may be relative so cloud folders can move between machines.
    final folderPath = _syncFolderPath;
    if (folderPath == null || folderPath.isEmpty) return path;
    final separator = Platform.pathSeparator;
    final trimmedFolder = folderPath.endsWith(separator)
        ? folderPath.substring(0, folderPath.length - 1)
        : folderPath;
    return '$trimmedFolder$separator$path';
  }

  Future<void> _refreshCubePreview() async {
    final requestId = ++_previewRequestId;
    final sourceBytes = _referenceImageBytes;
    if (_records.isEmpty) {
      if (mounted) {
        setState(() {
          _gradedReferenceImageBytes = null;
          _gradedRecordId = null;
          _activeCube = null;
          _activeCubeRecordId = null;
          _isProcessingPreview = false;
          _isLoadingCube = false;
        });
      }
      return;
    }

    final record = _selectedRecord;
    final requestedPanel = _panel;
    setState(() => _isLoadingCube = true);
    final baseCube = await _loadCubeForRecord(record);
    if (!mounted ||
        requestId != _previewRequestId ||
        _selectedId != record.id ||
        _panel != requestedPanel) {
      return;
    }
    final cube = requestedPanel == WorkspacePanel.maker
        ? CubeLut.parse(
            _generateCubeText(
              _makerName,
              _makerLook,
              baseCube: baseCube,
              baseTitle: record.name,
            ),
          )
        : baseCube;
    setState(() {
      _activeCube = cube;
      _activeCubeRecordId = record.id;
      _isLoadingCube = false;
    });

    if (cube == null) {
      if (mounted) {
        setState(() {
          _gradedReferenceImageBytes = null;
          _gradedRecordId = null;
          _isProcessingPreview = false;
        });
      }
      return;
    }

    if (sourceBytes == null ||
        (requestedPanel != WorkspacePanel.preview &&
            requestedPanel != WorkspacePanel.maker)) {
      setState(() {
        _gradedReferenceImageBytes = null;
        _gradedRecordId = null;
        _isProcessingPreview = false;
      });
      return;
    }

    setState(() => _isProcessingPreview = true);
    try {
      final processed = await Future<Uint8List>(
        () => _imageProcessor.applyCube(sourceBytes: sourceBytes, cube: cube),
      );
      if (!mounted ||
          requestId != _previewRequestId ||
          _selectedId != record.id ||
          _panel != requestedPanel) {
        return;
      }
      setState(() {
        _gradedReferenceImageBytes = processed;
        _gradedRecordId = record.id;
        _isProcessingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gradedReferenceImageBytes = null;
        _gradedRecordId = null;
        _isProcessingPreview = false;
      });
      _showMessage('参考照片无法应用当前 LUT');
    }
  }

  Future<void> _replaceRecord(
    String oldRecordId,
    LutRecord updatedRecord,
  ) async {
    setState(() {
      final nextRecords = <LutRecord>[];
      var replaced = false;
      for (final record in _records) {
        if (record.id == oldRecordId) {
          nextRecords.add(updatedRecord);
          replaced = true;
        } else if (record.id != updatedRecord.id) {
          nextRecords.add(record);
        }
      }
      if (!replaced) nextRecords.insert(0, updatedRecord);
      _records = nextRecords;
      _selectedId = updatedRecord.id;
      _cubeCache
        ..remove(oldRecordId)
        ..remove(updatedRecord.id);
      final activeTagKeys = _records
          .expand((record) => record.tags)
          .map((tag) => tag.key)
          .toSet();
      _selectedTagKeys.removeWhere((key) => !activeTagKeys.contains(key));
    });
    await _persistLibraryState();
    await _refreshCubePreview();
  }

  Future<void> _saveSelectedMetadataJson(String rawJson) async {
    final current = _selectedRecord;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException('Metadata root must be an object.');
      }
      var updated = LutRecord.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      final createdAt = updated.createdAt.millisecondsSinceEpoch == 0
          ? current.createdAt
          : updated.createdAt;
      updated = updated.copyWith(
        id: updated.id.isEmpty ? current.id : updated.id,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
      await _replaceRecord(current.id, updated);
      _showMessage('元数据 JSON 已保存');
    } catch (_) {
      _showMessage('JSON 保存失败，请检查格式和字段类型');
    }
  }

  Future<void> _editSelectedMetadata() async {
    final record = _selectedRecord;
    final camera = record.cameraCompatibility.isEmpty
        ? const CameraCompatibility(
            brand: '通用',
            models: ['未指定'],
            profile: '未指定',
            category: '未指定',
          )
        : record.cameraCompatibility.first;
    final nameController = TextEditingController(text: record.name);
    final fileNameController = TextEditingController(text: record.fileName);
    final authorController = TextEditingController(text: record.author);
    final colorStyleController = TextEditingController(text: record.colorStyle);
    final notesController = TextEditingController(text: record.notes);
    final cloudProviderController = TextEditingController(
      text: record.cloudProvider,
    );
    final relativePathController = TextEditingController(
      text: record.relativePath,
    );
    final cameraBrandController = TextEditingController(text: camera.brand);
    final cameraModelsController = TextEditingController(
      text: camera.models.join(', '),
    );
    final cameraProfileController = TextEditingController(text: camera.profile);
    final cameraCategoryController = TextEditingController(
      text: camera.category,
    );
    final tagDrafts = record.tags
        .map((tag) => _EditableTagDraft(type: tag.type, value: tag.value))
        .toList();
    if (tagDrafts.isEmpty) {
      tagDrafts.add(_EditableTagDraft(type: LutTagType.style, value: '未标记'));
    }

    String read(TextEditingController controller, String fallback) {
      final value = controller.text.trim();
      return value.isEmpty ? fallback : value;
    }

    final updated = await showDialog<LutRecord>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final size = MediaQuery.sizeOf(context);
            return AlertDialog(
              title: const Text('编辑元数据与 Tag'),
              content: SizedBox(
                width: math.min(680, size.width - 48),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基础信息',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DialogTextField(
                        controller: nameController,
                        label: 'LUT 名称',
                        icon: Icons.drive_file_rename_outline,
                      ),
                      const SizedBox(height: 10),
                      _DialogTextField(
                        controller: fileNameController,
                        label: '文件名',
                        icon: Icons.insert_drive_file_outlined,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogTextField(
                              controller: authorController,
                              label: '作者',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogTextField(
                              controller: colorStyleController,
                              label: '颜色风格',
                              icon: Icons.palette_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DialogTextField(
                        controller: notesController,
                        label: '备注',
                        icon: Icons.notes_outlined,
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '相机适配',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogTextField(
                              controller: cameraBrandController,
                              label: '厂商',
                              icon: Icons.business_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogTextField(
                              controller: cameraModelsController,
                              label: '机型，逗号分隔',
                              icon: Icons.photo_camera_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogTextField(
                              controller: cameraProfileController,
                              label: 'Profile',
                              icon: Icons.tune_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogTextField(
                              controller: cameraCategoryController,
                              label: '相机类别',
                              icon: Icons.category_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            'Tags',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tagDrafts.add(
                                  _EditableTagDraft(
                                    type: LutTagType.style,
                                    value: '',
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < tagDrafts.length;
                        index++
                      ) ...[
                        _TagEditorRow(
                          draft: tagDrafts[index],
                          onTypeChanged: (type) {
                            if (type == null) return;
                            setDialogState(() => tagDrafts[index].type = type);
                          },
                          onDelete: tagDrafts.length == 1
                              ? null
                              : () {
                                  setDialogState(() {
                                    final removed = tagDrafts.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        '同步位置',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogTextField(
                              controller: cloudProviderController,
                              label: '云服务 / 位置',
                              icon: Icons.cloud_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogTextField(
                              controller: relativePathController,
                              label: '路径',
                              icon: Icons.folder_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final models = cameraModelsController.text
                        .split(RegExp(r'[,，]'))
                        .map((model) => model.trim())
                        .where((model) => model.isNotEmpty)
                        .toList();
                    final tags = tagDrafts
                        .map(
                          (draft) => LutTag(
                            type: draft.type,
                            value: draft.valueController.text.trim(),
                          ),
                        )
                        .where((tag) => tag.value.isNotEmpty)
                        .toList();
                    final updatedRecord = record.copyWith(
                      name: read(nameController, record.name),
                      fileName: read(fileNameController, record.fileName),
                      author: read(authorController, '未知作者'),
                      colorStyle: read(colorStyleController, '未描述'),
                      notes: notesController.text.trim(),
                      cameraCompatibility: [
                        CameraCompatibility(
                          brand: read(cameraBrandController, '通用'),
                          models: models.isEmpty ? ['未指定'] : models,
                          profile: read(cameraProfileController, '未指定'),
                          category: read(cameraCategoryController, '未指定'),
                        ),
                      ],
                      tags: tags,
                      cloudProvider: read(
                        cloudProviderController,
                        'Local Folder',
                      ),
                      relativePath: relativePathController.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.of(context).pop(updatedRecord);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in [
      nameController,
      fileNameController,
      authorController,
      colorStyleController,
      notesController,
      cloudProviderController,
      relativePathController,
      cameraBrandController,
      cameraModelsController,
      cameraProfileController,
      cameraCategoryController,
    ]) {
      controller.dispose();
    }
    for (final draft in tagDrafts) {
      draft.dispose();
    }

    if (updated == null) return;
    await _replaceRecord(record.id, updated);
    _showMessage('元数据和 Tag 已保存');
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
    setState(() {
      _syncFolderPath = path;
      _syncFolderLabel =
          '$path\nsidecar: ${LutLibraryRepository.sidecarFileName}';
    });
    await _readSyncSidecarIfAvailable();
    await _persistLibraryState();
    _showMessage('同步文件夹已选择，并已生成/读取 .lutmanager.json');
  }

  Future<void> _exportMetadataBundle() async {
    const encoder = JsonEncoder.withIndent('  ');
    const fileName = 'lut-manager-metadata.json';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return;

    final payload = {
      'app': 'LUT Manager',
      'schemaVersion': 3,
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
      final rawRecords = decoded is List
          ? decoded
          : decoded is Map && decoded['luts'] is List
          ? decoded['luts'] as List
          : const <Object?>[];
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
      await _persistLibraryState();
      await _refreshCubePreview();
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
    if (look.contrast.abs() > 0.01)
      parts.add('对比 ${(look.contrast * 100).round()}');
    if (look.saturation.abs() > 0.01)
      parts.add('饱和 ${(look.saturation * 100).round()}');
    if (look.temperature.abs() > 0.01)
      parts.add('色温 ${(look.temperature * 100).round()}');
    if (look.highlightRollOff.abs() > 0.01) {
      parts.add('高光保护 ${(look.highlightRollOff * 100).round()}');
    }
    return parts.isEmpty ? '自然 HSL 调整' : parts.join('、');
  }

  Future<String> _generateMakerCubeText() async {
    final baseRecord = _makerBaseRecord;
    final baseCube = baseRecord == null
        ? null
        : await _loadCubeForRecord(baseRecord);
    return _generateCubeText(
      _makerName,
      _makerLook,
      baseCube: baseCube,
      baseTitle: baseRecord?.name,
    );
  }

  Future<CubeLut> _loadMakerCube() async {
    return CubeLut.parse(await _generateMakerCubeText());
  }

  String _generateCubeText(
    String title,
    LookAdjustment look, {
    CubeLut? baseCube,
    String? baseTitle,
  }) {
    const size = 17;
    final lines = <String>[
      'TITLE "${title.replaceAll('"', "'")}"',
      '# Generated by LUT Manager Flutter prototype',
      if (baseCube != null && baseTitle != null)
        '# Base LUT: ${baseTitle.replaceAll('"', "'")}',
      'LUT_3D_SIZE $size',
      'DOMAIN_MIN 0.0 0.0 0.0',
      'DOMAIN_MAX 1.0 1.0 1.0',
    ];

    for (var b = 0; b < size; b += 1) {
      for (var g = 0; g < size; g += 1) {
        for (var r = 0; r < size; r += 1) {
          final red = r / (size - 1);
          final green = g / (size - 1);
          final blue = b / (size - 1);
          final baseSample = baseCube?.sample(red, green, blue);
          final color = Color.fromARGB(
            255,
            baseSample?[0] ?? (255 * red).round(),
            baseSample?[1] ?? (255 * green).round(),
            baseSample?[2] ?? (255 * blue).round(),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              icon: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
          right: compact
              ? BorderSide.none
              : BorderSide(color: palette.sidebarBorder),
          bottom: compact
              ? BorderSide(color: palette.sidebarBorder)
              : BorderSide.none,
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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
    final selectedCount = tags
        .where((tag) => selectedTagKeys.contains(tag.key))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('tag-group-${type.name}-$selectedCount'),
          initiallyExpanded: selectedCount > 0,
          leading: Icon(_tagIcon(type), size: 18),
          title: Text(
            type.label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            selectedCount == 0
                ? '${tags.length} 个可选 Tag'
                : '已选 $selectedCount / ${tags.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
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
            ),
          ],
        ),
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
    required this.makerBaseName,
    required this.referenceImageBytes,
    required this.gradedReferenceImageBytes,
    required this.activeCube,
    required this.isProcessingPreview,
    required this.isLoadingCube,
    required this.onPickReferenceImage,
    required this.onImportCube,
    required this.onExportImage,
    required this.onPanelChanged,
    required this.onSplitChanged,
  });

  final LutRecord record;
  final WorkspacePanel panel;
  final double split;
  final LookAdjustment makerLook;
  final String? makerBaseName;
  final Uint8List? referenceImageBytes;
  final Uint8List? gradedReferenceImageBytes;
  final CubeLut? activeCube;
  final bool isProcessingPreview;
  final bool isLoadingCube;
  final VoidCallback onPickReferenceImage;
  final VoidCallback onImportCube;
  final ValueChanged<LutImageFormat> onExportImage;
  final ValueChanged<WorkspacePanel> onPanelChanged;
  final ValueChanged<double> onSplitChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLook = panel == WorkspacePanel.maker ? makerLook : record.look;
    final makerPanelLabel = makerBaseName == null ? '生成 LUT' : '在 LUT 基础上修改';
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
        PopupMenuButton<LutImageFormat>(
          enabled: referenceImageBytes != null,
          tooltip: '导出套用 LUT 后的图片',
          onSelected: onExportImage,
          itemBuilder: (context) => const [
            PopupMenuItem(value: LutImageFormat.png, child: Text('导出 PNG')),
            PopupMenuItem(value: LutImageFormat.jpeg, child: Text('导出 JPEG')),
          ],
          icon: const Icon(Icons.ios_share),
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
              children: [titleBlock, const SizedBox(height: 12), headerActions],
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
                          segments: [
                            const ButtonSegment(
                              value: WorkspacePanel.preview,
                              icon: Icon(Icons.compare),
                              label: Text('预览'),
                            ),
                            const ButtonSegment(
                              value: WorkspacePanel.lutView,
                              icon: Icon(Icons.view_in_ar),
                              label: Text('LUT 查看'),
                            ),
                            const ButtonSegment(
                              value: WorkspacePanel.metadata,
                              icon: Icon(Icons.data_object),
                              label: Text('元数据'),
                            ),
                            ButtonSegment(
                              value: WorkspacePanel.maker,
                              icon: const Icon(Icons.tune),
                              label: Text(makerPanelLabel),
                            ),
                          ],
                          selected: {panel},
                          onSelectionChanged: (selection) =>
                              onPanelChanged(selection.first),
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
                      child: panel == WorkspacePanel.lutView
                          ? _LutImpactPanel(
                              cube: activeCube,
                              isLoading: isLoadingCube,
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _PreviewCanvas(
                                      referenceImageBytes: referenceImageBytes,
                                      gradedReferenceImageBytes:
                                          gradedReferenceImageBytes,
                                      isProcessingPreview: isProcessingPreview,
                                      painter: _ReferencePreviewPainter(
                                        look: activeLook,
                                        split: split,
                                        isDark:
                                            theme.brightness == Brightness.dark,
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
    required this.makerBaseName,
    required this.onMakerLookChanged,
    required this.onMakerNameChanged,
    required this.onMakerCameraChanged,
    required this.onAddGenerated,
    required this.onCopyCube,
    required this.onSaveCube,
    required this.onCopyMetadata,
    required this.onSaveMetadataJson,
    required this.onEditMetadata,
    this.compact = false,
  });

  final LutRecord record;
  final WorkspacePanel panel;
  final LookAdjustment makerLook;
  final String makerName;
  final String makerCamera;
  final String? makerBaseName;
  final ValueChanged<LookAdjustment> onMakerLookChanged;
  final ValueChanged<String> onMakerNameChanged;
  final ValueChanged<String> onMakerCameraChanged;
  final Future<void> Function() onAddGenerated;
  final VoidCallback onCopyCube;
  final VoidCallback onSaveCube;
  final VoidCallback onCopyMetadata;
  final Future<void> Function(String) onSaveMetadataJson;
  final VoidCallback onEditMetadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<CodexPalette>()!;
    final children = [
      if (panel == WorkspacePanel.preview)
        _RecordDetails(record: record, onEditMetadata: onEditMetadata),
      if (panel == WorkspacePanel.metadata)
        _MetadataPanel(
          record: record,
          onCopyMetadata: onCopyMetadata,
          onSaveMetadataJson: onSaveMetadataJson,
          onEditMetadata: onEditMetadata,
        ),
      if (panel == WorkspacePanel.maker)
        _MakerPanel(
          look: makerLook,
          makerName: makerName,
          makerCamera: makerCamera,
          baseName: makerBaseName,
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
          left: compact
              ? BorderSide.none
              : BorderSide(color: palette.sidebarBorder),
          top: compact
              ? BorderSide(color: palette.sidebarBorder)
              : BorderSide.none,
        ),
      ),
      child: compact
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: children),
            )
          : ListView(padding: const EdgeInsets.all(20), children: children),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.record, required this.onEditMetadata});

  final LutRecord record;
  final VoidCallback onEditMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onEditMetadata,
            icon: const Icon(Icons.edit_note),
            label: const Text('编辑元数据 / Tag'),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Metric(label: '功能', value: record.functionLabel),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(label: '作者', value: record.author),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoBlock(
          label: '适配相机',
          value: record.cameraCompatibility
              .map((item) => item.label)
              .join('\n'),
        ),
        const SizedBox(height: 10),
        _InfoBlock(label: '颜色风格', value: record.colorStyle),
        const SizedBox(height: 14),
        Text(
          'Tags',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
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
        if (record.fileHash.isNotEmpty || record.contentHash.isNotEmpty) ...[
          const SizedBox(height: 10),
          _InfoBlock(
            label: '重复检测指纹',
            value: [
              if (record.fileHash.isNotEmpty)
                '文件：${_shortHash(record.fileHash)}',
              if (record.contentHash.isNotEmpty)
                '内容：${_shortHash(record.contentHash)}',
              if (record.lutSize != null) '尺寸：${record.lutSize}³',
              if (record.sourceFileSize != null)
                '文件大小：${record.sourceFileSize} bytes',
            ].join('\n'),
          ),
        ],
      ],
    );
  }
}

String _shortHash(String hash) {
  final value = hash.startsWith('sha256:') ? hash.substring(7) : hash;
  if (value.length <= 16) return hash;
  return 'sha256:${value.substring(0, 12)}...${value.substring(value.length - 8)}';
}

class _MetadataPanel extends StatefulWidget {
  const _MetadataPanel({
    required this.record,
    required this.onCopyMetadata,
    required this.onSaveMetadataJson,
    required this.onEditMetadata,
  });

  final LutRecord record;
  final VoidCallback onCopyMetadata;
  final Future<void> Function(String) onSaveMetadataJson;
  final VoidCallback onEditMetadata;

  @override
  State<_MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends State<_MetadataPanel> {
  late final TextEditingController _controller;

  String get _formattedJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(widget.record.toJson());
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formattedJson);
  }

  @override
  void didUpdateWidget(covariant _MetadataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        oldWidget.record.updatedAt != widget.record.updatedAt) {
      _controller.text = _formattedJson;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sidecar JSON',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: widget.onEditMetadata,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('表单'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onCopyMetadata,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _controller,
              minLines: 18,
              maxLines: 28,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '编辑 sidecar JSON',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => widget.onSaveMetadataJson(_controller.text),
                icon: const Icon(Icons.save),
                label: const Text('保存 JSON'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _controller.text = _formattedJson),
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _EditableTagDraft {
  _EditableTagDraft({required this.type, required String value})
    : valueController = TextEditingController(text: value);

  LutTagType type;
  final TextEditingController valueController;

  void dispose() => valueController.dispose();
}

class _TagEditorRow extends StatelessWidget {
  const _TagEditorRow({
    required this.draft,
    required this.onTypeChanged,
    required this.onDelete,
  });

  final _EditableTagDraft draft;
  final ValueChanged<LutTagType?> onTypeChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<LutTagType>(
            initialValue: draft.type,
            items: [
              for (final type in LutTagType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: onTypeChanged,
            decoration: const InputDecoration(
              labelText: '类型',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: TextField(
            controller: draft.valueController,
            decoration: const InputDecoration(
              labelText: 'Tag 值',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '删除 Tag',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
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
    required this.baseName,
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
  final String? baseName;
  final ValueChanged<LookAdjustment> onLookChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCameraChanged;
  final Future<void> Function() onAddGenerated;
  final VoidCallback onCopyCube;
  final VoidCallback onSaveCube;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBaseName = baseName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeBaseName == null ? '自定义 LUT' : '在 LUT 基础上修改',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (activeBaseName != null) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.layers_outlined, size: 16),
            label: Text('基础 LUT：$activeBaseName'),
          ),
        ],
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
          onChanged: (value) =>
              onLookChanged(look.copyWith(temperature: value)),
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
          onChanged: (value) =>
              onLookChanged(look.copyWith(highlightRollOff: value)),
        ),
        _AdjustmentSlider(
          label: '红饱和',
          value: look.redSaturation,
          onChanged: (value) =>
              onLookChanged(look.copyWith(redSaturation: value)),
        ),
        _AdjustmentSlider(
          label: '绿饱和',
          value: look.greenSaturation,
          onChanged: (value) =>
              onLookChanged(look.copyWith(greenSaturation: value)),
        ),
        _AdjustmentSlider(
          label: '蓝饱和',
          value: look.blueSaturation,
          onChanged: (value) =>
              onLookChanged(look.copyWith(blueSaturation: value)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onAddGenerated(),
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

class _LutImpactPanel extends StatelessWidget {
  const _LutImpactPanel({required this.cube, required this.isLoading});

  final CubeLut? cube;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCube = cube;
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    if (activeCube == null) {
      return Center(
        child: Text('当前 LUT 无法生成可视化', style: theme.textTheme.bodyMedium),
      );
    }

    final stats = _LutImpactStats.fromCube(activeCube);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: CustomPaint(
              painter: _LutImpactPainter(
                cube: activeCube,
                isDark: theme.brightness == Brightness.dark,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DeltaMetric(label: '平均 ΔR', value: stats.redDelta),
            _DeltaMetric(label: '平均 ΔG', value: stats.greenDelta),
            _DeltaMetric(label: '平均 ΔB', value: stats.blueDelta),
            _DeltaMetric(label: '最大偏移', value: stats.maxShift),
          ],
        ),
      ],
    );
  }
}

class _DeltaMetric extends StatelessWidget {
  const _DeltaMetric({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = value.clamp(-1.0, 1.0).toDouble();
    final color = normalized >= 0 ? Colors.greenAccent : Colors.redAccent;
    return SizedBox(
      width: 132,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
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
              LinearProgressIndicator(
                value: normalized.abs(),
                minHeight: 5,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
              ),
              const SizedBox(height: 6),
              Text(
                '${normalized >= 0 ? '+' : ''}${(normalized * 100).round()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LutImpactStats {
  const _LutImpactStats({
    required this.redDelta,
    required this.greenDelta,
    required this.blueDelta,
    required this.maxShift,
  });

  final double redDelta;
  final double greenDelta;
  final double blueDelta;
  final double maxShift;

  factory _LutImpactStats.fromCube(CubeLut cube) {
    const steps = 5;
    var redTotal = 0.0;
    var greenTotal = 0.0;
    var blueTotal = 0.0;
    var maxShift = 0.0;
    var count = 0;
    for (var r = 0; r < steps; r++) {
      for (var g = 0; g < steps; g++) {
        for (var b = 0; b < steps; b++) {
          final inputR = r / (steps - 1);
          final inputG = g / (steps - 1);
          final inputB = b / (steps - 1);
          final output = cube.sample(inputR, inputG, inputB);
          final dr = output[0] / 255 - inputR;
          final dg = output[1] / 255 - inputG;
          final db = output[2] / 255 - inputB;
          redTotal += dr;
          greenTotal += dg;
          blueTotal += db;
          maxShift = math.max(maxShift, math.sqrt(dr * dr + dg * dg + db * db));
          count += 1;
        }
      }
    }
    return _LutImpactStats(
      redDelta: redTotal / count,
      greenDelta: greenTotal / count,
      blueDelta: blueTotal / count,
      maxShift: maxShift,
    );
  }
}

class _LutImpactPainter extends CustomPainter {
  const _LutImpactPainter({required this.cube, required this.isDark});

  final CubeLut cube;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    final labelStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.68),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    Offset project(double red, double green, double blue) {
      final scale = math.min(size.width, size.height) * 0.58;
      final center = Offset(size.width * 0.5, size.height * 0.62);
      final x = (red - blue) * scale * 0.62;
      final y = ((red + blue) * 0.34 - green * 0.82) * scale;
      return center + Offset(x, y);
    }

    final corners = <({double r, double g, double b})>[
      (r: 0, g: 0, b: 0),
      (r: 1, g: 0, b: 0),
      (r: 0, g: 1, b: 0),
      (r: 1, g: 1, b: 0),
      (r: 0, g: 0, b: 1),
      (r: 1, g: 0, b: 1),
      (r: 0, g: 1, b: 1),
      (r: 1, g: 1, b: 1),
    ];
    bool differsByOne(int a, int b) {
      final ca = corners[a];
      final cb = corners[b];
      return ((ca.r - cb.r).abs() +
              (ca.g - cb.g).abs() +
              (ca.b - cb.b).abs()) ==
          1;
    }

    for (var a = 0; a < corners.length; a++) {
      for (var b = a + 1; b < corners.length; b++) {
        if (!differsByOne(a, b)) continue;
        final start = corners[a];
        final end = corners[b];
        canvas.drawLine(
          project(start.r, start.g, start.b),
          project(end.r, end.g, end.b),
          axisPaint,
        );
      }
    }

    void label(String text, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    label('R+', project(1, 0, 0) + const Offset(10, -6));
    label('G+', project(0, 1, 0) + const Offset(-8, -22));
    label('B+', project(0, 0, 1) + const Offset(-28, -6));

    const steps = 5;
    for (var r = 0; r < steps; r++) {
      for (var g = 0; g < steps; g++) {
        for (var b = 0; b < steps; b++) {
          final inputR = r / (steps - 1);
          final inputG = g / (steps - 1);
          final inputB = b / (steps - 1);
          final output = cube.sample(inputR, inputG, inputB);
          final outputR = output[0] / 255;
          final outputG = output[1] / 255;
          final outputB = output[2] / 255;
          final start = project(inputR, inputG, inputB);
          final end = project(outputR, outputG, outputB);
          final color = Color.fromARGB(255, output[0], output[1], output[2]);
          final shift = (end - start).distance;
          final linePaint = Paint()
            ..color = color.withValues(alpha: shift < 1 ? 0.22 : 0.62)
            ..strokeWidth = shift < 1 ? 1 : 1.6
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(start, end, linePaint);
          canvas.drawCircle(
            end,
            2.5,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            start,
            1.6,
            Paint()
              ..color = (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.2,
              ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LutImpactPainter oldDelegate) {
    return oldDelegate.cube != cube || oldDelegate.isDark != isDark;
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.referenceImageBytes,
    required this.gradedReferenceImageBytes,
    required this.isProcessingPreview,
    required this.painter,
    required this.look,
    required this.split,
  });

  final Uint8List? referenceImageBytes;
  final Uint8List? gradedReferenceImageBytes;
  final bool isProcessingPreview;
  final CustomPainter painter;
  final LookAdjustment look;
  final double split;

  @override
  Widget build(BuildContext context) {
    final bytes = referenceImageBytes;
    if (bytes == null) {
      return CustomPaint(painter: painter, child: const SizedBox.expand());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final splitX = width * split;
        Widget image({required bool graded}) {
          final activeBytes = graded
              ? gradedReferenceImageBytes ?? bytes
              : bytes;
          final child = Image.memory(
            activeBytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
          if (!graded || gradedReferenceImageBytes != null) return child;
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
              child: Container(
                width: 2,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
            Positioned(
              left: splitX - 7,
              bottom: 24,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFAEBBFF),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 14, height: 14),
              ),
            ),
            const Positioned(left: 14, top: 14, child: _PreviewLabel('Before')),
            const Positioned(right: 14, top: 14, child: _PreviewLabel('After')),
            if (isProcessingPreview)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
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
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * split, size.height);

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) =>
      oldClipper.split != split;
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => onChanged(0),
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
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

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
    final bg = Paint()
      ..color = isDark ? const Color(0xFF07080A) : const Color(0xFFD9D9D5);
    canvas.drawRect(Offset.zero & size, bg);

    final frame = _largestRect(size, const Size(16, 10)).deflate(12);
    final radius = BorderRadius.circular(8).toRRect(frame);
    canvas.drawRRect(
      radius,
      Paint()..color = isDark ? const Color(0xFF111315) : Colors.white,
    );

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
    canvas.drawLine(
      Offset(splitX, frame.top),
      Offset(splitX, frame.bottom),
      linePaint,
    );
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

  void _drawReferenceScene(
    Canvas canvas,
    Rect rect,
    LookAdjustment activeLook,
  ) {
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
        Rect.fromLTWH(
          card.outerRect.left + swatchWidth * i,
          swatchTop,
          swatchWidth,
          swatchHeight,
        ),
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
        center: Offset(
          bodyRect.center.dx - 4,
          bodyRect.top + bodyRect.height * 0.42,
        ),
        width: bodyRect.width * 0.55,
        height: bodyRect.height * 0.48,
      ),
      Paint()..color = c(const Color(0xFFF0C79D)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          bodyRect.center.dx,
          bodyRect.top + bodyRect.height * 0.18,
        ),
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
      Rect.fromLTWH(
        offset.dx - 8,
        offset.dy - 5,
        painter.width + 16,
        painter.height + 10,
      ),
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
  final channelSaturation =
      look.redSaturation * redWeight +
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
  return hsl
      .withHue(hue)
      .withSaturation(saturation)
      .withLightness(lightness)
      .toColor();
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
