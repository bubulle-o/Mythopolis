/// Disposition des icônes d'une jauge dans son cadre.
enum RatingLayout {
  line,   // une seule ligne
  rows,   // plusieurs lignes (rowCount)
  circle, // en cercle, départ en haut, sens horaire
}

/// Une jauge posée sur une page.
///
/// Comme les autres zones, position et taille du CADRE sont en fractions
/// de la page (0 → 1). [iconSize] est la LARGEUR d'une icône, en fraction
/// de la largeur de la page (la hauteur suit les proportions de l'image).
class RatingZone {
  String id;
  String parentPage;
  String ratingId;
  double width;        // largeur du cadre
  double height;       // hauteur du cadre
  double iconSize;     // largeur d'une icône
  double topLeftCornerX;
  double topLeftCornerY;
  int currentValue;    // valeur initiale = nombre d'icônes pleines
  int maxValue;        // nombre d'icônes (1 à 20)
  RatingLayout layout;
  int rowCount;        // nombre de lignes si layout == rows
  bool showEmpty;      // icônes vides visibles en lecture de fiche
  double zOrder;

  RatingZone({
    required this.id,
    required this.parentPage,
    required this.ratingId,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.topLeftCornerX,
    required this.topLeftCornerY,
    required this.currentValue,
    required this.maxValue,
    required this.layout,
    required this.rowCount,
    required this.showEmpty,
    required this.zOrder,
  });

  /// Copie de la jauge où seules les valeurs données changent.
  /// Ex. zone.copyWith(maxValue: 8) : même jauge, 8 icônes.
  RatingZone copyWith({
    double? width,
    double? height,
    double? iconSize,
    double? topLeftCornerX,
    double? topLeftCornerY,
    int? currentValue,
    int? maxValue,
    RatingLayout? layout,
    int? rowCount,
    bool? showEmpty,
  }) {
    return RatingZone(
      id: id,
      parentPage: parentPage,
      ratingId: ratingId,
      width: width ?? this.width,
      height: height ?? this.height,
      iconSize: iconSize ?? this.iconSize,
      topLeftCornerX: topLeftCornerX ?? this.topLeftCornerX,
      topLeftCornerY: topLeftCornerY ?? this.topLeftCornerY,
      currentValue: currentValue ?? this.currentValue,
      maxValue: maxValue ?? this.maxValue,
      layout: layout ?? this.layout,
      rowCount: rowCount ?? this.rowCount,
      showEmpty: showEmpty ?? this.showEmpty,
      zOrder: zOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "parentPage": parentPage,
      "ratingId": ratingId,
      "width": width,
      "height": height,
      "iconSize": iconSize,
      "topLeftCornerX": topLeftCornerX,
      "topLeftCornerY": topLeftCornerY,
      "currentValue": currentValue,
      "maxValue": maxValue,
      "layout": layout.name,          // enum -> TEXT ("line"…)
      "rowCount": rowCount,
      "showEmpty": showEmpty ? 1 : 0, // bool -> INTEGER
      "zOrder": zOrder,
    };
  }

  static RatingZone fromMap(Map<String, dynamic> data) {
    return RatingZone(
      id: data["id"],
      parentPage: data["parentPage"],
      ratingId: data["ratingId"],
      width: data["width"],
      height: data["height"],
      iconSize: data["iconSize"],
      topLeftCornerX: data["topLeftCornerX"],
      topLeftCornerY: data["topLeftCornerY"],
      currentValue: data["currentValue"],
      maxValue: data["maxValue"],
      // TEXT -> enum (valeur inconnue : une ligne)
      layout: RatingLayout.values.asNameMap()[data["layout"]] ?? RatingLayout.line,
      rowCount: data["rowCount"],
      showEmpty: data["showEmpty"] == 1, // INTEGER -> bool
      zOrder: data["zOrder"],
    );
  }
}
