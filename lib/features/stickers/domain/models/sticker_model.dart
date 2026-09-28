class StickerModel {
  const StickerModel({
    required this.id,
    required this.creatorId,
    required this.name,
    required this.imagePath,
    this.packId = 'pack_my_stickers',
    this.packName = 'My Stickers',
    this.emoji = '✨',
    required this.createdAt,
    this.isBuiltIn = false,
  });

  final String id;
  final String creatorId;
  final String name;
  final String imagePath; // Can be asset path or local file path
  final String packId;
  final String packName;
  final String emoji;
  final DateTime createdAt;
  final bool isBuiltIn;

  bool get isAsset => imagePath.startsWith('assets/');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'name': name,
      'imagePath': imagePath,
      'packId': packId,
      'packName': packName,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
      'isBuiltIn': isBuiltIn,
    };
  }

  factory StickerModel.fromMap(Map<String, dynamic> map) {
    return StickerModel(
      id: map['id'] as String? ?? '',
      creatorId: map['creatorId'] as String? ?? '',
      name: map['name'] as String? ?? 'Sticker',
      imagePath: map['imagePath'] as String? ?? '',
      packId: map['packId'] as String? ?? 'pack_my_stickers',
      packName: map['packName'] as String? ?? 'My Stickers',
      emoji: map['emoji'] as String? ?? '✨',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
    );
  }

  StickerModel copyWith({
    String? id,
    String? creatorId,
    String? name,
    String? imagePath,
    String? packId,
    String? packName,
    String? emoji,
    DateTime? createdAt,
    bool? isBuiltIn,
  }) {
    return StickerModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}
