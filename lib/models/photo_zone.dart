class PhotoZone {
  String id;
  String parentPage;
  String? shapePath;
  String? photoPath;
  double height;
  double width;
  double topLeftCornerX;
  double topLeftCornerY;
  bool belowBackground;
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
    this.belowBackground = false,
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
      "belowBackground": belowBackground ? 1 : 0,   // bool -> INTEGER
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
      belowBackground: data["belowBackground"] == 1,   // INTEGER -> bool
      zOrder: data["zOrder"],
    );
  }
}