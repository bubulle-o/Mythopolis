import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:mythopolis/models/rating.dart';
import 'package:mythopolis/services/rating_service.dart';

/// Les deux images d'une jauge, prêtes à afficher.
class RatingImages {
  final Rating rating;
  final Uint8List full;
  final Uint8List empty;

  /// Largeur / hauteur d'une icône (prise sur l'image pleine).
  final double aspectRatio;

  const RatingImages({
    required this.rating,
    required this.full,
    required this.empty,
    required this.aspectRatio,
  });


  //////////////////////////////////////////////////////
  //                  CHARGEMENT                      //
  //////////////////////////////////////////////////////

  // Cache : chaque jauge n'est lue qu'une fois (Future gardé pour que deux
  // demandes simultanées ne fassent pas deux lectures).
  static final Map<String, Future<RatingImages>> _cache = {};

  /// Images de la jauge [ratingId] (depuis le cache si déjà chargées).
  static Future<RatingImages> load(String ratingId) {
    return _cache.putIfAbsent(ratingId, () => _load(ratingId));
  }

  static Future<RatingImages> _load(String ratingId) async {
    final Rating rating = await RatingService().loadRating(ratingId);
    final Uint8List full = await _readBytes(rating.fullPath, rating.isBuiltIn);
    final Uint8List empty = await _readBytes(rating.emptyPath, rating.isBuiltIn);

    // Dimensions de l'image pleine, sans la décoder entièrement
    final buffer = await ui.ImmutableBuffer.fromUint8List(full);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final double ratio = descriptor.width / descriptor.height;
    descriptor.dispose();
    buffer.dispose();

    return RatingImages(rating: rating, full: full, empty: empty, aspectRatio: ratio);
  }

  /// Jauge prédéfinie : lue dans les assets ; personnalisée : fichier.
  static Future<Uint8List> _readBytes(String path, bool isAsset) async {
    if (isAsset) {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    }
    return File(path).readAsBytes();
  }
}
