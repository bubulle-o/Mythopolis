class TextZone {
  String id;
  String parentPage;
  String? content;
  double height;
  double width;
  double topLeftCornerX;
  double topLeftCornerY;
  bool isLocked;
  double zOrder;

  TextZone({
    required this.id,
    required this.parentPage,
    this.content,
    required this.height,
    required this.width,
    required this.topLeftCornerX,
    required this.topLeftCornerY,
    required this.isLocked,
    required this.zOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "parentPage": parentPage,
      "content": content,
      "height": height,
      "width": width,
      "topLeftCornerX": topLeftCornerX,
      "topLeftCornerY": topLeftCornerY,
      "isLocked": isLocked ? 1 : 0, // bool -> INTEGER
      "zOrder": zOrder,
    };
  }

  static TextZone fromMap(Map<String, dynamic> data) {
    return TextZone(
      id: data["id"],
      parentPage: data["parentPage"],
      content: data["content"],
      height: data["height"],
      width: data["width"],
      topLeftCornerX: data["topLeftCornerX"],
      topLeftCornerY: data["topLeftCornerY"],
      isLocked: data["isLocked"] == 1, // INTEGER -> bool
      zOrder: data["zOrder"],
    );
  }
}