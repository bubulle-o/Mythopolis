import 'package:flutter/material.dart';
import 'package:mythopolis/services/template_service.dart';
import '../models/template.dart';

//////////////////////////////////////////////////////
//                    PROVIDER                      //
//////////////////////////////////////////////////////

/// Gère l'état des templates et notifie l'UI à chaque changement.
/// Les templates ne sont pas rangés dans des dossiers : une seule liste globale.
class TemplateProvider extends ChangeNotifier {

  final TemplateService _service = TemplateService();

  // Cache local de tous les templates
  List<Template> _templates = [];

  // Résultats de la dernière recherche
  List<Template> _searchResults = [];


  //////////////////////////////////////////////////////
  //                   ACCESSEURS                     //
  //////////////////////////////////////////////////////

  /// Retourne les templates en cache ([] si pas encore chargés).
  List<Template> getTemplates() => _templates;

  /// Retourne les résultats de la dernière recherche.
  List<Template> getSearchTemplates() => _searchResults;


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  /// Charge tous les templates depuis la base.
  Future<void> loadTemplates() async {
    _templates = await _service.getAllTemplates();
    notifyListeners();
  }

  /// Crée un template et retourne son ID (pour ouvrir l'éditeur ensuite).
  Future<String> createTemplate(
    String name,
    int canvasWidth,
    int canvasHeight,
    String? backgroundPath,
  ) async {
    String id = await _service.createTemplate(
        name, canvasWidth, canvasHeight, backgroundPath);
    await loadTemplates();
    return id;
  }

  /// Renomme un template.
  Future<void> renameTemplate(String id, String name) async {
    await _service.renameTemplate(id, name);
    await loadTemplates();
  }

  /// Supprime un template (et ses pages en cascade).
  Future<void> deleteTemplate(String id) async {
    await _service.deleteTemplate(id);
    await loadTemplates();
  }


  //////////////////////////////////////////////////////
  //                   RECHERCHE                      //
  //////////////////////////////////////////////////////

  Future<void> searchTemplates(String query) async {
    _searchResults = await _service.searchTemplate(query);
    notifyListeners();
  }
}