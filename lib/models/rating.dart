/// Un modèle de jauge : une image "pleine" et une image "vide".
///
/// Une ligne = UNE couleur d'UN type :
/// - jauges prédéfinies : déduites des fichiers de lib/graphism/rating/
///   (`<type>_vide.png` + `<type>_<couleur>_plein.png`), id fixe
///   `builtin_<type>_<couleur>`, images lues dans les assets ;
/// - jauges personnalisées : créées par l'utilisateur, une seule couleur
///   ([color] null), images copiées dans le dossier de l'appli.
class Rating {
  String id;
  /// Nom du type (ex. "rond"). Toutes les couleurs d'un type ont le même.
  String name;
  /// Couleur (ex. "jaune"), ou null pour une jauge personnalisée.
  String? color;
  String emptyPath;
  String fullPath;
  /// true : chemins d'assets (AssetImage) ; false : fichiers (FileImage).
  bool isBuiltIn;

  Rating({
    required this.id,
    required this.name,
    this.color,
    required this.emptyPath,
    required this.fullPath,
    required this.isBuiltIn,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "color": color,
      "emptyPath": emptyPath,
      "fullPath": fullPath,
      "isBuiltIn": isBuiltIn ? 1 : 0, // bool -> INTEGER
    };
  }

  static Rating fromMap(Map<String, dynamic> data) {
    return Rating(
      id: data["id"],
      name: data["name"],
      color: data["color"],
      emptyPath: data["emptyPath"],
      fullPath: data["fullPath"],
      isBuiltIn: data["isBuiltIn"] == 1, // INTEGER -> bool
    );
  }
}
