class Category {
  final String id;
  final String name;
  final String? userId;
  final bool isDefault;
  final String? icon;

  Category({
    required this.id,
    required this.name,
    this.userId,
    this.isDefault = false,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'isDefault': isDefault,
      if (icon != null) 'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      userId: map['userId']?.toString(),
      isDefault: (map['isDefault'] as bool?) ?? (map['userId'] == null),
      icon: map['icon'] as String?,
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? userId,
    bool? isDefault,
    String? icon,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      isDefault: isDefault ?? this.isDefault,
      icon: icon ?? this.icon,
    );
  }
}
