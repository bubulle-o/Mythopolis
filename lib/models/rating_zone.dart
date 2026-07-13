class RatingZone {
  String id;
  String parentPage;
  String ratingId;
  double width;
  double iconSize;
  double topLeftCornerX;
  double topLeftCornerY;
  int currentValue;
  int maxValue;
  double zOrder;

  RatingZone({
    required this.id,
    required this.parentPage,
    required this.ratingId,
    required this.width,
    required this.iconSize,
    required this.topLeftCornerX,
    required this.topLeftCornerY,
    required this.currentValue,
    required this.maxValue,
    required this.zOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "parentPage": parentPage,
      "ratingId": ratingId,
      "width": width,
      "iconSize": iconSize,
      "topLeftCornerX": topLeftCornerX,
      "topLeftCornerY": topLeftCornerY,
      "currentValue": currentValue,
      "maxValue": maxValue,
      "zOrder": zOrder,
    };
  }

  static RatingZone fromMap(Map<String, dynamic> data) {
    return RatingZone(
      id: data["id"],
      parentPage: data["parentPage"],
      ratingId: data["ratingId"],
      width: data["width"],
      iconSize: data["iconSize"],
      topLeftCornerX: data["topLeftCornerX"],
      topLeftCornerY: data["topLeftCornerY"],
      currentValue: data["currentValue"],
      maxValue: data["maxValue"],
      zOrder: data["zOrder"],
    );
  }
}