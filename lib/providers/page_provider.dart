import 'package:flutter/material.dart';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/services/page_service.dart';

//////////////////////////////////////////////////////
//                    PROVIDER                      //
//////////////////////////////////////////////////////

/// Gère l'état des pages et notifie l'UI à chaque changement.
/// Une page appartient à une template ou à une fiche ; le provider
/// mémorise le propriétaire actuellement chargé pour pouvoir recharger.
class PageProvider extends ChangeNotifier {

  final PageService _service = PageService();

  // Cache local des pages du propriétaire courant
  List<PageModel> _pages = [];

  // Contexte courant : à qui appartiennent les pages en cache
  String? _currentOwnerId;
  bool _currentIsTemplate = true;


  //////////////////////////////////////////////////////
  //                   ACCESSEURS                     //
  //////////////////////////////////////////////////////

  /// Retourne les pages en cache ([] si pas encore chargées).
  List<PageModel> getPages() => _pages;


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  /// Charge les pages d'une template et mémorise le contexte.
  Future<void> loadPagesFromTemplate(String templateId) async {
    _currentOwnerId = templateId;
    _currentIsTemplate = true;
    _pages = await _service.getPagesFromTemplate(templateId);
    notifyListeners();
  }

  /// Recharge les pages du propriétaire courant.
  Future<void> _reload() async {
    if (_currentOwnerId == null) return;
    if (_currentIsTemplate) {
      await loadPagesFromTemplate(_currentOwnerId!);
    }
    // (versant fiche à ajouter plus tard)
  }

  /// Crée une page vierge dans une template et retourne son ID.
  Future<String> addPageTemplate(
    String parentTemplate,
    int canvasWidth,
    int canvasHeight,
    double zOrder,
  ) async {
    String id = await _service.addPage(
        parentTemplate, null, null, canvasWidth, canvasHeight, zOrder);

    await _reload();

    return id;
  }

  /// Supprime une page (et ses zones en cascade).
  Future<void> deletePage(String id) async {
    await _service.deletePage(id);
    await _reload();
  }
}