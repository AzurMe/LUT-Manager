enum LutTagType {
  cameraCategory,
  cameraBrand,
  cameraModel,
  captureProfile,
  function,
  style,
  shadowTone,
  highlightTone,
  colorBias,
  skinTone,
  lightingScene,
  workflow,
  intensity,
  author,
}

extension LutTagTypeLabel on LutTagType {
  String get label {
    switch (this) {
      case LutTagType.cameraCategory:
        return '相机类别';
      case LutTagType.cameraBrand:
        return '相机品牌';
      case LutTagType.cameraModel:
        return '相机型号';
      case LutTagType.captureProfile:
        return '拍摄配置';
      case LutTagType.function:
        return '功能';
      case LutTagType.style:
        return '风格';
      case LutTagType.shadowTone:
        return '阴调';
      case LutTagType.highlightTone:
        return '亮调';
      case LutTagType.colorBias:
        return '色彩倾向';
      case LutTagType.skinTone:
        return '肤色';
      case LutTagType.lightingScene:
        return '使用场景';
      case LutTagType.workflow:
        return '工作流';
      case LutTagType.intensity:
        return '强度';
      case LutTagType.author:
        return '作者';
    }
  }
}

class LutTag {
  const LutTag({required this.type, required this.value});

  final LutTagType type;
  final String value;

  String get key => '${type.name}:$value';

  Map<String, String> toJson() => {'type': type.name, 'value': value};

  factory LutTag.fromJson(Map<String, Object?> json) {
    final rawType = json['type']?.toString() ?? LutTagType.style.name;
    return LutTag(
      type: LutTagType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => LutTagType.style,
      ),
      value: json['value']?.toString() ?? '',
    );
  }
}
