import "max_state.dart";

/// image | video
enum MaxMediaType { image, video }

MaxMediaType maxMediaTypeFromDb(String value) => value == "video" ? MaxMediaType.video : MaxMediaType.image;

String maxMediaTypeToDb(MaxMediaType type) => type == MaxMediaType.video ? "video" : "image";

class MaxStateMedia {
  final String id;
  final MaxStateKey stateKey;
  final MaxMediaType mediaType;
  final String name;
  final String storagePath;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const MaxStateMedia({
    required this.id,
    required this.stateKey,
    required this.mediaType,
    required this.name,
    required this.storagePath,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });

  factory MaxStateMedia.fromMap(Map<String, dynamic> map) {
    return MaxStateMedia(
      id: map["id"] as String,
      stateKey: maxStateKeyFromDb(map["state_key"] as String),
      mediaType: maxMediaTypeFromDb(map["media_type"] as String),
      name: map["name"] as String,
      storagePath: map["storage_path"] as String,
      isActive: map["is_active"] as bool? ?? true,
      sortOrder: (map["sort_order"] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map["created_at"] as String),
    );
  }
}
