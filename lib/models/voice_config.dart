class VoiceConfig {
  final String id;
  final String name;
  final String description;
  final String gender;
  final bool isSystem;
  final bool isIncluded;
  final String assetFolder;

  const VoiceConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.gender,
    this.isSystem = true,
    this.isIncluded = true,
    required this.assetFolder,
  });

  VoiceConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? gender,
    bool? isSystem,
    bool? isIncluded,
    String? assetFolder,
  }) {
    return VoiceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      gender: gender ?? this.gender,
      isSystem: isSystem ?? this.isSystem,
      isIncluded: isIncluded ?? this.isIncluded,
      assetFolder: assetFolder ?? this.assetFolder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'gender': gender,
        'isSystem': isSystem,
        'isIncluded': isIncluded,
        'assetFolder': assetFolder,
      };

  factory VoiceConfig.fromJson(Map<String, dynamic> json) => VoiceConfig(
        id: json['id'] as String? ?? 'kia',
        name: json['name'] as String? ?? 'Kia',
        description: json['description'] as String? ?? 'Warm & Grounded',
        gender: json['gender'] as String? ?? 'Male',
        isSystem: json['isSystem'] as bool? ?? true,
        isIncluded: json['isIncluded'] as bool? ?? true,
        assetFolder: json['assetFolder'] as String? ??
            'assets/audio/voices/${json['id'] ?? 'kia'}',
      );

  static const List<VoiceConfig> defaultVoices = [
    VoiceConfig(
      id: 'kia',
      name: 'Kia',
      description: 'Warm & Grounded',
      gender: 'Male',
      isSystem: true,
      isIncluded: true,
      assetFolder: 'assets/audio/voices/kia',
    ),
    VoiceConfig(
      id: 'grace',
      name: 'Grace',
      description: 'Soft & Centered',
      gender: 'Female',
      isSystem: true,
      isIncluded: true,
      assetFolder: 'assets/audio/voices/grace',
    ),
  ];
}
