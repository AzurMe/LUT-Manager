import 'look_adjustment.dart';
import 'lut_tag.dart';

class CameraCompatibility {
  const CameraCompatibility({
    required this.brand,
    required this.models,
    required this.profile,
    required this.category,
  });

  final String brand;
  final List<String> models;
  final String profile;
  final String category;

  String get label {
    final joinedModels = models.join(', ');
    return '$brand $joinedModels / $profile';
  }

  Map<String, Object> toJson() => {
    'brand': brand,
    'models': models,
    'profile': profile,
    'category': category,
  };

  factory CameraCompatibility.fromJson(Map<String, Object?> json) {
    return CameraCompatibility(
      brand: json['brand']?.toString() ?? '',
      models: _objectList(
        json['models'],
      ).map((item) => item.toString()).toList(),
      profile: json['profile']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
    );
  }
}

class LutRecord {
  const LutRecord({
    required this.id,
    required this.name,
    required this.fileName,
    required this.cameraCompatibility,
    required this.author,
    required this.colorStyle,
    required this.tags,
    required this.notes,
    required this.look,
    required this.createdAt,
    required this.updatedAt,
    this.cloudProvider = 'Local Folder',
    this.relativePath = '',
    this.fileHash = '',
    this.contentHash = '',
    this.lutSize,
    this.sourceFileSize,
    this.importedAt,
  });

  final String id;
  final String name;
  final String fileName;
  final List<CameraCompatibility> cameraCompatibility;
  final String author;
  final String colorStyle;
  final List<LutTag> tags;
  final String notes;
  final LookAdjustment look;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String cloudProvider;
  final String relativePath;
  final String fileHash;
  final String contentHash;
  final int? lutSize;
  final int? sourceFileSize;
  final DateTime? importedAt;

  String get primaryCamera => cameraCompatibility.isEmpty
      ? '通用 / 未指定'
      : cameraCompatibility.first.label;

  String get functionLabel => tagValue(LutTagType.function) ?? '未分类';

  String? tagValue(LutTagType type) {
    for (final tag in tags) {
      if (tag.type == type) return tag.value;
    }
    return null;
  }

  bool containsQuery(String query) {
    if (query.trim().isEmpty) return true;
    final normalized = query.trim().toLowerCase();
    final haystack = [
      name,
      fileName,
      author,
      colorStyle,
      notes,
      primaryCamera,
      for (final tag in tags) tag.value,
      for (final camera in cameraCompatibility) camera.label,
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  bool matchesTags(Set<String> selectedTagKeys) {
    if (selectedTagKeys.isEmpty) return true;
    final ownKeys = {
      for (final tag in tags) tag.key,
      for (final camera in cameraCompatibility) ...[
        LutTag(type: LutTagType.cameraBrand, value: camera.brand).key,
        LutTag(type: LutTagType.cameraCategory, value: camera.category).key,
        LutTag(type: LutTagType.captureProfile, value: camera.profile).key,
        for (final model in camera.models)
          LutTag(type: LutTagType.cameraModel, value: model).key,
      ],
    };
    return selectedTagKeys.every(ownKeys.contains);
  }

  LutRecord copyWith({
    String? id,
    String? name,
    String? fileName,
    List<CameraCompatibility>? cameraCompatibility,
    String? author,
    String? colorStyle,
    List<LutTag>? tags,
    String? notes,
    LookAdjustment? look,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? cloudProvider,
    String? relativePath,
    String? fileHash,
    String? contentHash,
    int? lutSize,
    int? sourceFileSize,
    DateTime? importedAt,
  }) {
    return LutRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      cameraCompatibility: cameraCompatibility ?? this.cameraCompatibility,
      author: author ?? this.author,
      colorStyle: colorStyle ?? this.colorStyle,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      look: look ?? this.look,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cloudProvider: cloudProvider ?? this.cloudProvider,
      relativePath: relativePath ?? this.relativePath,
      fileHash: fileHash ?? this.fileHash,
      contentHash: contentHash ?? this.contentHash,
      lutSize: lutSize ?? this.lutSize,
      sourceFileSize: sourceFileSize ?? this.sourceFileSize,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
    'cameraCompatibility': cameraCompatibility
        .map((camera) => camera.toJson())
        .toList(),
    'author': author,
    'colorStyle': colorStyle,
    'tags': tags.map((tag) => tag.toJson()).toList(),
    'notes': notes,
    'look': look.toJson(),
    'cloudProvider': cloudProvider,
    'relativePath': relativePath,
    'fileHash': fileHash,
    'contentHash': contentHash,
    if (lutSize != null) 'lutSize': lutSize!,
    if (sourceFileSize != null) 'sourceFileSize': sourceFileSize!,
    if (importedAt != null) 'importedAt': importedAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LutRecord.fromJson(Map<String, Object?> json) {
    final legacyPreviewTuning = _stringObjectMap(json['previewTuning']);
    return LutRecord(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      cameraCompatibility: _objectList(json['cameraCompatibility'])
          .map(_stringObjectMap)
          .whereType<Map<String, Object?>>()
          .map(CameraCompatibility.fromJson)
          .toList(),
      author: json['author']?.toString() ?? '',
      colorStyle: json['colorStyle']?.toString() ?? '',
      tags: _objectList(json['tags'])
          .map(_stringObjectMap)
          .whereType<Map<String, Object?>>()
          .map(LutTag.fromJson)
          .toList(),
      notes: json['notes']?.toString() ?? '',
      look: LookAdjustment.fromJson(
        _stringObjectMap(json['look']) ??
            legacyPreviewTuning ??
            const <String, Object?>{},
      ),
      cloudProvider: json['cloudProvider']?.toString() ?? 'Local Folder',
      relativePath: json['relativePath']?.toString() ?? '',
      fileHash: json['fileHash']?.toString() ?? '',
      contentHash: json['contentHash']?.toString() ?? '',
      lutSize: (json['lutSize'] as num?)?.toInt(),
      sourceFileSize: (json['sourceFileSize'] as num?)?.toInt(),
      importedAt: DateTime.tryParse(json['importedAt']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

List<Object?> _objectList(Object? value) {
  return value is List ? value : const <Object?>[];
}

Map<String, Object?>? _stringObjectMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}
