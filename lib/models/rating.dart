class Rating {
  String id;
  String name;
  String emptyPath;
  String fullPath;

  Rating({
    required this.id,
    required this.name,
    required this.emptyPath,
    required this.fullPath,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "emptyPath": emptyPath,
      "fullPath": fullPath,
    };
  }

  static Rating fromMap(Map<String, dynamic> data) {
    return Rating(
      id: data["id"],
      name: data["name"],
      emptyPath: data["emptyPath"],
      fullPath: data["fullPath"],
    );
  }
}