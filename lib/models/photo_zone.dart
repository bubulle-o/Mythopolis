class PhotoZone {
  String id;
  String parentPage;
  String? shapePath;
  String? photoPath;
  double height;
  double width;
  double topLeftCornerX;
  double topLeftCornerY;
  double zOrder;

  PhotoZone({
    required this.id,
    required this.parentPage,
    this.shapePath,
    this.photoPath,
    required this.height,
    required this.width,
    required this.topLeftCornerX,
    required this.topLeftCornerY,
    required this.zOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "parentPage": parentPage,
      "shapePath": shapePath,
      "photoPath": photoPath,
      "height": height,
      "width": width,
      "topLeftCornerX": topLeftCornerX,
      "topLeftCornerY": topLeftCornerY,
      "zOrder": zOrder,
    };
  }

  static PhotoZone fromMap(Map<String, dynamic> data) {
    return PhotoZone(
      id: data["id"],
      parentPage: data["parentPage"],
      shapePath: data["shapePath"],
      photoPath: data["photoPath"],
      height: data["height"],
      width: data["width"],
      topLeftCornerX: data["topLeftCornerX"],
      topLeftCornerY: data["topLeftCornerY"],
      zOrder: data["zOrder"],
    );
  }
}