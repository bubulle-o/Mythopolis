import 'dart:math' as math;
import 'dart:ui';

import 'package:mythopolis/models/rating_zone.dart';

/// Calculs de placement des icônes d'une jauge dans son cadre.
///
/// Fonctions pures (aucun état) : on leur donne la disposition, le nombre
/// d'icônes et des tailles, elles rendent des positions ou des limites.
/// Toutes les tailles sont dans la même unité (pixels du canvas).
///
/// Règle d'or : les icônes ne se superposent JAMAIS. Les fonctions
/// [minFrameSize] et [maxIconWidth] donnent les limites à respecter.
class RatingGeometry {
  RatingGeometry._();


  //////////////////////////////////////////////////////
  //                    LIGNES                        //
  //////////////////////////////////////////////////////

  /// Forme d'une disposition en lignes : (icônes par ligne, nb de lignes).
  /// Les n-1 premières lignes sont pleines, la dernière prend le reste.
  /// Ex. 10 icônes sur 3 lignes → 4 par ligne → 4, 4, 2.
  /// (Si les lignes pleines suffisent, il peut y en avoir moins que
  /// demandé : 4 icônes sur 3 lignes → 2, 2.)
  static (int perRow, int rows) rowsShape(int count, int rowCount) {
    final int wantedRows = rowCount.clamp(1, count);
    final int perRow = (count / wantedRows).ceil();
    final int rows = (count / perRow).ceil();
    return (perRow, rows);
  }

  /// Lignes effectives d'une disposition : 1 pour "line", rowCount pour
  /// "rows" (le cercle n'utilise pas de lignes).
  static int _rowCountFor(RatingLayout layout, int rowCount) =>
      layout == RatingLayout.rows ? rowCount : 1;


  //////////////////////////////////////////////////////
  //                   POSITIONS                      //
  //////////////////////////////////////////////////////

  /// Centre de chaque icône dans le cadre (origine = coin haut-gauche du
  /// cadre), dans l'ordre : la 1re est la première remplie.
  static List<Offset> iconCenters({
    required RatingLayout layout,
    required int count,
    required int rowCount,
    required Size frame,
    required Size icon,
  }) {
    if (layout == RatingLayout.circle) {
      return _circleCenters(count, frame, icon);
    }
    return _rowsCenters(count, _rowCountFor(layout, rowCount), frame, icon);
  }

  /// Lignes : icônes réparties d'un bord à l'autre ; la dernière ligne,
  /// moins remplie, garde le même espacement et est centrée.
  static List<Offset> _rowsCenters(int count, int rowCount, Size frame, Size icon) {
    final (int perRow, int rows) = rowsShape(count, rowCount);

    // Distance entre deux centres voisins
    final double stepX = perRow > 1 ? (frame.width - icon.width) / (perRow - 1) : 0;
    final double stepY = rows > 1 ? (frame.height - icon.height) / (rows - 1) : 0;

    final List<Offset> centers = [];
    for (int row = 0; row < rows; row++) {
      final int inThisRow = math.min(perRow, count - row * perRow);
      // Largeur occupée par cette ligne → marge pour la centrer
      final double rowWidth = (inThisRow - 1) * stepX + icon.width;
      final double startX = (frame.width - rowWidth) / 2 + icon.width / 2;
      final double y = rows > 1 ? icon.height / 2 + row * stepY : frame.height / 2;
      for (int i = 0; i < inThisRow; i++) {
        centers.add(Offset(startX + i * stepX, y));
      }
    }
    return centers;
  }

  /// Cercle parfait centré dans le cadre (diamètre = plus petit côté),
  /// 1re icône en haut puis sens des aiguilles d'une montre.
  static List<Offset> _circleCenters(int count, Size frame, Size icon) {
    final Offset center = Offset(frame.width / 2, frame.height / 2);
    if (count == 1) return [center];

    // Rayon du cercle des centres : les icônes touchent le bord du cercle
    final double diameter = math.min(frame.width, frame.height);
    final double radius =
        math.max(0, diameter / 2 - math.max(icon.width, icon.height) / 2);

    return [
      for (int i = 0; i < count; i++)
        // -π/2 = en haut ; angle croissant = sens horaire (y vers le bas)
        center + Offset.fromDirection(-math.pi / 2 + 2 * math.pi * i / count, radius),
    ];
  }


  //////////////////////////////////////////////////////
  //                    LIMITES                       //
  //////////////////////////////////////////////////////

  /// Plus petit cadre où les icônes ne se superposent pas.
  static Size minFrameSize({
    required RatingLayout layout,
    required int count,
    required int rowCount,
    required Size icon,
  }) {
    if (layout == RatingLayout.circle) {
      if (count == 1) return icon;
      // Deux centres voisins sont séparés d'une corde 2R·sin(π/n). On veut
      // qu'elle dépasse la diagonale de l'icône : ainsi, quelle que soit
      // leur position sur le cercle, deux icônes ne peuvent pas se toucher.
      final double diagonal = math.sqrt(icon.width * icon.width + icon.height * icon.height);
      final double radius = diagonal / (2 * math.sin(math.pi / count));
      final double diameter = 2 * radius + math.max(icon.width, icon.height);
      return Size(diameter, diameter);
    }
    final (int perRow, int rows) = rowsShape(count, _rowCountFor(layout, rowCount));
    return Size(perRow * icon.width, rows * icon.height);
  }

  /// Plus grande largeur d'icône qui tient dans [frame] sans superposition.
  /// Toutes les limites sont proportionnelles à la taille de l'icône : on
  /// calcule le cadre minimal pour une icône de largeur 1, puis on regarde
  /// combien de fois il rentre dans le cadre.
  static double maxIconWidth({
    required RatingLayout layout,
    required int count,
    required int rowCount,
    required Size frame,
    required double iconAspectRatio,
  }) {
    final Size unit = minFrameSize(
      layout: layout,
      count: count,
      rowCount: rowCount,
      icon: Size(1, 1 / iconAspectRatio),
    );
    return math.min(frame.width / unit.width, frame.height / unit.height);
  }
}
