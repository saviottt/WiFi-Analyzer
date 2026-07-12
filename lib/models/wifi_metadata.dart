class WifiCustomMetadata {
  final String floorName;
  final String location;

  WifiCustomMetadata({
    required this.floorName,
    required this.location,
  });

  /// Creates a [WifiCustomMetadata] from a JSON map.
  factory WifiCustomMetadata.fromJson(Map<String, dynamic> json) {
    return WifiCustomMetadata(
      floorName: json['floorName'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }

  /// Converts this metadata into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'floorName': floorName,
      'location': location,
    };
  }

  /// Returns a copy of this metadata with the given fields replaced.
  WifiCustomMetadata copyWith({
    String? floorName,
    String? location,
  }) {
    return WifiCustomMetadata(
      floorName: floorName ?? this.floorName,
      location: location ?? this.location,
    );
  }
}
