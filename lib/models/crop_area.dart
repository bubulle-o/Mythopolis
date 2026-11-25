/// Zone à conserver dans une image, choisie dans l'outil de recadrage
/// (BackgroundCropDialog) et appliquée par PageService.
///
/// Tout est exprimé dans l'image ORIGINALE (avant rotation) :
/// - [centerX], [centerY] : point de l'image au centre du cadre (pixels) ;
/// - [width], [height]    : taille du cadre, en pixels de l'image ;
/// - [rotation]           : angle en degrés, sens des aiguilles d'une
///   montre (comme à l'écran), entre -180 et 180.
///
/// Sans rotation, c'est simplement le rectangle centré sur (centerX,
/// centerY). Avec rotation, le cadre est "penché" dans l'image originale ;
/// le service fait pivoter l'image puis découpe un rectangle droit.
///
/// Un record Dart 3 : pas de dépendance à Flutter, le service peut
/// l'utiliser sans importer dart:ui.
typedef CropArea = ({
  double centerX,
  double centerY,
  double width,
  double height,
  double rotation,
});
