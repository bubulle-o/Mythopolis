import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;


//////////////////////////////////////////////////////
//                      MODÈLE                      //
//////////////////////////////////////////////////////

/// Une forme de zone photo, prête à afficher.
class ShapeInfo {
  /// Chemin de l'asset, ex. "lib/graphism/photo_zone/circle.png".
  /// C'est lui qui est stocké en base (PhotoZone.shapePath).
  final String assetPath;

  /// PNG recadré sur la partie visible de la forme (sans marges).
  final Uint8List bytes;

  /// Largeur / hauteur de la forme recadrée (1 = carré).
  final double aspectRatio;

  const ShapeInfo({
    required this.assetPath,
    required this.bytes,
    required this.aspectRatio,
  });

  /// Nom affiché : le nom du fichier sans extension.
  String get name => ShapeCatalog.nameOf(assetPath);
}


//////////////////////////////////////////////////////
//                    CATALOGUE                     //
//////////////////////////////////////////////////////

/// Accès aux formes du dossier lib/graphism/photo_zone/ (déclaré dans
/// pubspec.yaml). Chaque forme est recadrée UNE fois sur sa partie
/// visible, puis gardée en mémoire.
class ShapeCatalog {
  static const String _folder = 'lib/graphism/photo_zone/';

  // Cache : une forme n'est chargée et recadrée qu'une seule fois.
  // On garde le Future pour que deux demandes simultanées n'en fassent
  // pas deux chargements.
  static final Map<String, Future<ShapeInfo>> _cache = {};

  /// Chemins de toutes les formes PNG, triés par nom.
  static Future<List<String>> listShapePaths() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> paths = manifest
        .listAssets()
        .where((path) => path.startsWith(_folder) && path.toLowerCase().endsWith('.png'))
        .toList();
    paths.sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    return paths;
  }

  /// "lib/graphism/photo_zone/circle.png" → "circle".
  static String nameOf(String assetPath) {
    final String fileName = assetPath.split('/').last;
    final int dot = fileName.lastIndexOf('.');
    return dot == -1 ? fileName : fileName.substring(0, dot);
  }

  /// Charge une forme (depuis le cache si déjà chargée).
  static Future<ShapeInfo> load(String assetPath) {
    return _cache.putIfAbsent(assetPath, () => _load(assetPath));
  }

  static Future<ShapeInfo> _load(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();

    // Décodage + recadrage dans un isolate : ne fige pas l'interface
    final (Uint8List png, int width, int height) =
        await Isolate.run(() => _trimTransparentMargins(bytes));

    return ShapeInfo(
      assetPath: assetPath,
      bytes: png,
      aspectRatio: width / height,
    );
  }
}


//////////////////////////////////////////////////////
//          RECADRAGE DES MARGES (ISOLATE)          //
//////////////////////////////////////////////////////

/// Retire les marges transparentes autour de la forme.
/// Retourne le PNG recadré et ses dimensions.
/// Fonction de premier niveau : elle tourne dans un isolate.
(Uint8List, int, int) _trimTransparentMargins(Uint8List bytes) {
  final img.Image? image = img.decodePng(bytes);
  if (image == null) throw Exception('Forme illisible');

  // Plus petit rectangle contenant tous les pixels visibles.
  // (alpha > 10 : on ignore les pixels quasi transparents des bords)
  int left = image.width, top = image.height, right = -1, bottom = -1;
  for (final pixel in image) {
    if (pixel.a > 10) {
      if (pixel.x < left) left = pixel.x;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.y > bottom) bottom = pixel.y;
    }
  }

  // Image entièrement transparente : on la garde telle quelle
  if (right < 0) return (bytes, image.width, image.height);

  final img.Image trimmed = img.copyCrop(
    image,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
  return (img.encodePng(trimmed), trimmed.width, trimmed.height);
}
