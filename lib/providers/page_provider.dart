import 'package:flutter/material.dart';
import 'package:mythopolis/models/crop_area.dart';
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

  /// Crée une page vierge dans une template juste après la page [afterId]
  /// (ou à la fin si null), puis renumérote l'ordre. Retourne son ID.
  Future<String> addPageTemplateAfter(
    String parentTemplate,
    String? afterId,
    int canvasWidth,
    int canvasHeight,
  ) async {
    // zOrder provisoire (en fin de liste) : la renumérotation le corrige
    String id = await _service.addPage(parentTemplate, null, null,
        canvasWidth, canvasHeight, _pages.length.toDouble());

    final List<String> orderedIds = _pages.map((page) => page.id).toList();
    final int afterIndex = afterId == null ? -1 : orderedIds.indexOf(afterId);
    orderedIds.insert(
      afterIndex == -1 ? orderedIds.length : afterIndex + 1,
      id,
    );
    await _service.reorderPages(orderedIds);

    await _reload();
    return id;
  }

  /// Remplace le fond d'une page par l'image [sourcePath] recadrée selon
  /// [crop], compressée à [canvasWidth] × [canvasHeight].
  Future<void> setBackground(
    String pageId,
    String sourcePath,
    CropArea crop,
    int canvasWidth,
    int canvasHeight,
  ) async {
    await _service.setBackground(
        pageId, sourcePath, crop, canvasWidth, canvasHeight);
    await _reload();
  }

  /// Retire le fond d'une page (fond blanc).
  Future<void> removeBackground(String pageId) async {
    await _service.removeBackground(pageId);
    await _reload();
  }

  /// Supprime une page (et ses zones en cascade).
  /// Lève une exception s'il s'agit de la dernière page.
  Future<void> deletePage(String id) async {
    await _service.deletePage(id);
    await _reload();
  }

  /// Duplique une page juste après l'originale et retourne l'ID de la copie.
  Future<String> duplicatePage(String id) async {
    String newId = await _service.duplicatePage(id);
    await _reload();
    return newId;
  }

  /// Déplace la page de [oldIndex] vers [newIndex] et enregistre l'ordre.
  ///
  /// [newIndex] est la position FINALE de la page dans la liste.
  /// Attention : le onReorder de ReorderableListView donne un newIndex
  /// décalé de 1 quand on descend — il faut le corriger avant d'appeler.
  ///
  /// Mise à jour optimiste : la liste en mémoire change tout de suite
  /// (pas de saut visuel), la base est mise à jour ensuite. En cas
  /// d'erreur, on recharge depuis la base pour revenir à l'état réel.
  Future<void> reorderPage(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final PageModel moved = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, moved);
    notifyListeners();

    try {
      await _service.reorderPages(_pages.map((page) => page.id).toList());
    } catch (e) {
      await _reload();
      rethrow;
    }
  }
}