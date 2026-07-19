import 'package:flutter/material.dart';
import 'package:mythopolis/models/text_zone.dart';
import 'package:mythopolis/services/text_zone_service.dart';

//////////////////////////////////////////////////////
//                    PROVIDER                      //
//////////////////////////////////////////////////////

/// Gère l'état des zones de texte et notifie l'UI à chaque changement.
/// Une zone appartient à une page ; le provider mémorise la page
/// actuellement chargée pour pouvoir recharger après modification.
class TextZoneProvider extends ChangeNotifier {

  final TextZoneService _service = TextZoneService();

  // Cache local des zones de la page courante
  List<TextZone> _textZones = [];

  // Contexte courant : la page à laquelle appartiennent les zones en cache
  String? _pageId;


  //////////////////////////////////////////////////////
  //                   ACCESSEURS                     //
  //////////////////////////////////////////////////////

  /// Retourne les zones en cache ([] si pas encore chargées).
  List<TextZone> getTextZones() => _textZones;


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  /// Charge les zones de texte d'une page et mémorise le contexte.
  Future<void> loadTextZonesFromPage(String pageId) async {
    _pageId = pageId;
    _textZones = await _service.getTextZonesFromPage(pageId);
    notifyListeners();
  }

  /// Recharge les zones de la page courante.
  Future<void> _reload() async {
    if (_pageId == null) return;
    await loadTextZonesFromPage(_pageId!);
  }

  /// Crée une zone de texte dans une page et retourne son ID.
  Future<String> addTextZone({
    required String parentPage,
    required double width,
    required double height,
    required double topLeftCornerX,
    required double topLeftCornerY,
    required bool isLocked,
  }) async {
    String id = await _service.addTextZone(
      parentPage: parentPage,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
      isLocked: isLocked,
    );

    await _reload();
    return id;
  }

  /// Met à jour la position, la taille, le contenu ou l'ordre d'une zone.
  /// Les paramètres null conservent la valeur actuelle.
  Future<void> updateTextZone({
    required String id,
    double? zOrder,
    double? width,
    double? height,
    double? topLeftCornerX,
    double? topLeftCornerY,
    String? content,
  }) async {
    await _service.updateTextZone(
      id: id,
      zOrder: zOrder,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
      content: content,
    );

    await _reload();
  }

  /// Supprime une zone de texte.
  Future<void> deleteTextZone(String id) async {
    await _service.deleteTextZone(id);
    await _reload();
  }
}