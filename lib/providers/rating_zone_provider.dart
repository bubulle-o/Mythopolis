import 'package:flutter/material.dart';
import 'package:mythopolis/models/rating_zone.dart';
import 'package:mythopolis/services/rating_zone_service.dart';

//////////////////////////////////////////////////////
//                    PROVIDER                      //
//////////////////////////////////////////////////////

/// Gère l'état des jauges posées sur la page courante et notifie l'UI.
/// Même fonctionnement que TextZoneProvider et PhotoZoneProvider.
class RatingZoneProvider extends ChangeNotifier {

  final RatingZoneService _service = RatingZoneService();

  // Cache local des jauges de la page courante
  List<RatingZone> _ratingZones = [];

  // Contexte courant : la page à laquelle appartiennent les jauges en cache
  String? _pageId;


  //////////////////////////////////////////////////////
  //                   ACCESSEURS                     //
  //////////////////////////////////////////////////////

  /// Retourne les jauges en cache ([] si pas encore chargées).
  List<RatingZone> getRatingZones() => _ratingZones;


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  /// Charge les jauges d'une page et mémorise le contexte.
  Future<void> loadRatingZonesFromPage(String pageId) async {
    _pageId = pageId;
    _ratingZones = await _service.getRatingZonesFromPage(pageId);
    notifyListeners();
  }

  /// Recharge les jauges de la page courante.
  Future<void> _reload() async {
    if (_pageId == null) return;
    await loadRatingZonesFromPage(_pageId!);
  }

  /// Crée une jauge et retourne son ID.
  Future<String> addRatingZone(RatingZone zone) async {
    final String id = await _service.addRatingZone(zone);
    await _reload();
    return id;
  }

  /// Enregistre toutes les valeurs d'une jauge (position, taille, options).
  Future<void> updateRatingZone(RatingZone zone) async {
    await _service.updateRatingZone(zone);
    await _reload();
  }

  /// Supprime une jauge.
  Future<void> deleteRatingZone(String id) async {
    await _service.deleteRatingZone(id);
    await _reload();
  }
}
