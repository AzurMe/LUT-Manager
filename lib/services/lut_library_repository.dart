import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/sample_luts.dart';
import '../models/lut_record.dart';

class LutLibraryState {
  const LutLibraryState({required this.records, this.syncFolderPath});

  final List<LutRecord> records;
  final String? syncFolderPath;
}

class LutLibraryRepository {
  static const _libraryFileName = 'lut-manager-library.json';
  static const sidecarFileName = '.lutmanager.json';

  // The local app-support file is the app's source of truth between launches.
  // If a sync folder is selected, the same records are mirrored into the sidecar.
  Future<LutLibraryState> loadLibraryState() async {
    try {
      final file = await _libraryFile();
      if (!await file.exists()) {
        return LutLibraryState(records: List<LutRecord>.from(sampleLuts));
      }
      final rawJson = await file.readAsString();
      final decoded = jsonDecode(rawJson);
      final records = _decodeRecordsFromDecoded(decoded);
      final syncFolderPath = decoded is Map
          ? decoded['syncFolderPath']?.toString()
          : null;
      return LutLibraryState(
        records: records.isEmpty ? List<LutRecord>.from(sampleLuts) : records,
        syncFolderPath: syncFolderPath?.isEmpty ?? true ? null : syncFolderPath,
      );
    } catch (_) {
      return LutLibraryState(records: List<LutRecord>.from(sampleLuts));
    }
  }

  Future<void> saveLibraryState(LutLibraryState state) async {
    final file = await _libraryFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      _encodeRecords(state.records, syncFolderPath: state.syncFolderPath),
    );
  }

  Future<List<LutRecord>> loadSidecar(String folderPath) async {
    final file = File(_sidecarPath(folderPath));
    if (!await file.exists()) return const [];
    return _decodeRecords(await file.readAsString());
  }

  Future<void> saveSidecar(String folderPath, List<LutRecord> records) async {
    // Sidecars describe LUTs without touching the original .cube files.
    final file = File(_sidecarPath(folderPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(_encodeRecords(records));
  }

  Future<File> _libraryFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_libraryFileName');
  }

  String _sidecarPath(String folderPath) {
    final separator = Platform.pathSeparator;
    final trimmed = folderPath.endsWith(separator)
        ? folderPath.substring(0, folderPath.length - 1)
        : folderPath;
    return '$trimmed$separator$sidecarFileName';
  }

  String _encodeRecords(List<LutRecord> records, {String? syncFolderPath}) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'app': 'LUT Manager',
      'schemaVersion': 3,
      'updatedAt': DateTime.now().toIso8601String(),
      if (syncFolderPath != null && syncFolderPath.isNotEmpty)
        'syncFolderPath': syncFolderPath,
      'luts': records.map((record) => record.toJson()).toList(),
    });
  }

  List<LutRecord> _decodeRecords(String rawJson) {
    return _decodeRecordsFromDecoded(jsonDecode(rawJson));
  }

  List<LutRecord> _decodeRecordsFromDecoded(Object? decoded) {
    final rawRecords = decoded is List
        ? decoded
        : decoded is Map && decoded['luts'] is List
        ? decoded['luts'] as List
        : const <Object?>[];
    return rawRecords
        .whereType<Map<Object?, Object?>>()
        .map(
          (record) => LutRecord.fromJson(
            record.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((record) => record.id.isNotEmpty)
        .toList();
  }
}
