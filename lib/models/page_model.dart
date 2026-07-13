class PageModel {
  String id;
  String? parentTemplate;
  String? parentSheet;
  String? backgroundPath;
  double zOrder;

  PageModel({
    required this.id,
    this.parentTemplate,
    this.parentSheet,
    this.backgroundPath,
    required this.zOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "parentTemplate": parentTemplate,
      "parentSheet": parentSheet,
      "backgroundPath": backgroundPath,
      "zOrder": zOrder,
    };
  }

  static PageModel fromMap(Map<String, dynamic> data) {
    return PageModel(
      id: data["id"],
      parentTemplate: data["parentTemplate"],
      parentSheet: data["parentSheet"],
      backgroundPath: data["backgroundPath"],
      zOrder: data["zOrder"],
    );
  }
}