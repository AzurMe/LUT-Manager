class LookAdjustment {
  const LookAdjustment({
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.luminance = 0,
    this.temperature = 0,
    this.tint = 0,
    this.hueShift = 0,
    this.shadowLift = 0,
    this.highlightRollOff = 0,
    this.redSaturation = 0,
    this.greenSaturation = 0,
    this.blueSaturation = 0,
  });

  final double exposure;
  final double contrast;
  final double saturation;
  final double luminance;
  final double temperature;
  final double tint;
  final double hueShift;
  final double shadowLift;
  final double highlightRollOff;
  final double redSaturation;
  final double greenSaturation;
  final double blueSaturation;

  static const neutral = LookAdjustment();

  LookAdjustment copyWith({
    double? exposure,
    double? contrast,
    double? saturation,
    double? luminance,
    double? temperature,
    double? tint,
    double? hueShift,
    double? shadowLift,
    double? highlightRollOff,
    double? redSaturation,
    double? greenSaturation,
    double? blueSaturation,
  }) {
    return LookAdjustment(
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      luminance: luminance ?? this.luminance,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      hueShift: hueShift ?? this.hueShift,
      shadowLift: shadowLift ?? this.shadowLift,
      highlightRollOff: highlightRollOff ?? this.highlightRollOff,
      redSaturation: redSaturation ?? this.redSaturation,
      greenSaturation: greenSaturation ?? this.greenSaturation,
      blueSaturation: blueSaturation ?? this.blueSaturation,
    );
  }

  Map<String, double> toJson() => {
    'exposure': exposure,
    'contrast': contrast,
    'saturation': saturation,
    'luminance': luminance,
    'temperature': temperature,
    'tint': tint,
    'hueShift': hueShift,
    'shadowLift': shadowLift,
    'highlightRollOff': highlightRollOff,
    'redSaturation': redSaturation,
    'greenSaturation': greenSaturation,
    'blueSaturation': blueSaturation,
  };

  factory LookAdjustment.fromJson(Map<String, Object?> json) {
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return LookAdjustment(
      exposure: read('exposure'),
      contrast: read('contrast'),
      saturation: read('saturation'),
      luminance: read('luminance'),
      temperature: read('temperature'),
      tint: read('tint'),
      hueShift: read('hueShift'),
      shadowLift: read('shadowLift'),
      highlightRollOff: read('highlightRollOff'),
      redSaturation: read('redSaturation'),
      greenSaturation: read('greenSaturation'),
      blueSaturation: read('blueSaturation'),
    );
  }
}
