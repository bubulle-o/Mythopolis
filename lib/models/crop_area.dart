/// Zone à conserver dans une image, en pixels de l'image ORIGINALE.
///
/// Produite par l'outil de recadrage (BackgroundCropDialog) et consommée
/// par PageService. Un record Dart 3 : pas de dépendance à Flutter, le
/// service peut l'utiliser sans importer dart:ui.
typedef CropArea = ({int x, int y, int width, int height});
