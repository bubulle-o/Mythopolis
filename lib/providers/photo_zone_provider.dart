import 'package:flutter/material.dart';
import 'package:mythopolis/models/photo_zone.dart';
import 'package:mythopolis/services/photo_zone_service.dart';

//////////////////////////////////////////////////////
//                    PROVIDER                      //
//////////////////////////////////////////////////////

/// Gère l'état des zones photo et notifie l'UI à chaque changement.
/// Même fonctionnement que TextZoneProvider : le provider mémorise la
/// page actuellement chargée pour pouvoir recharger après modification.
class PhotoZoneProvider extends ChangeNotifier {

  final PhotoZoneService _service = PhotoZoneService();

  // Cache local des zones photo de la page courante
  List<PhotoZone> _photoZones = [];

  // Contexte courant : la page à laquelle appartiennent les zones en cache
  String? _pageId;


  //////////////////////////////////////////////////////
  //                   ACCESSEURS                     //
  //////////////////////////////////////////////////////

  /// Retourne les zones photo en cache ([] si pas encore chargées).
  List<PhotoZone> getPhotoZones() => _photoZones;


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  /// Charge les zones photo d'une page et mémorise le contexte.
  Future<void> loadPhotoZonesFromPage(String pageId) async {
    _pageId = pageId;
    _photoZones = await _service.getPhotoZonesFromPage(pageId);
    notifyListeners();
  }

  /// Recharge les zones de la page courante.
  Future<void> _reload() async {
    if (_pageId == null) return;
    await loadPhotoZonesFromPage(_pageId!);
  }

  /// Crée une zone photo dans une page et retourne son ID.
  Future<String> addPhotoZone({
    required String parentPage,
    required String shapePath,
    required double width,
    required double height,
    required double topLeftCornerX,
    required double topLeftCornerY,
  }) async {
    String id = await _service.addPhotoZone(
      parentPage: parentPage,
      shapePath: shapePath,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
    );
    await _reload();
    return id;
  }

  /// Met à jour la position ou la taille d'une zone.
  Future<void> updatePhotoZone({
    required String id,
    double? width,
    double? height,
    double? topLeftCornerX,
    double? topLeftCornerY,
  }) async {
    await _service.updatePhotoZone(
      id: id,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
    );
    await _reload();
  }

  /// Supprime une zone photo.
  Future<void> deletePhotoZone(String id) async {
    await _service.deletePhotoZone(id);
    await _reload();
  }
}
