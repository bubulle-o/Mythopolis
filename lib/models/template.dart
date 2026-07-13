class Template {
  String id;
  String name;
  int canvasHeight;
  int canvasWidth;

  Template({
    required this.id,
    required this.name,
    required this.canvasHeight,
    required this.canvasWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "canvasHeight": canvasHeight,
      "canvasWidth": canvasWidth,
    };
  }

  static Template fromMap(Map<String, dynamic> data) {
    return Template(
      id: data["id"],
      name: data["name"],
      canvasHeight: data["canvasHeight"],
      canvasWidth: data["canvasWidth"],
    );
  }
}