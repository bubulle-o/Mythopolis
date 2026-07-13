import 'package:mythopolis/models/template.dart';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'package:mythopolis/services/page_service.dart';

/// Service responsable des opérations CRUD sur les templates.
/// Les templates ne sont pas rangés dans des dossiers : ils forment
/// un espace à part, où les noms doivent donc être uniques globalement.
class TemplateService {

  static final TemplateService _instance = TemplateService._internal();
  factory TemplateService() => _instance;
  TemplateService._internal();

  static const String _prefix = "template_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée un template et sa première page. Retourne l'ID du template.
  /// Lève une exception si un template du même nom existe déjà.
  Future<String> createTemplate(
    String name,
    int canvasHeight,
    int canvasWidth,
    String? backgroundPath,
  ) async {
    final db = await DatabaseHelper().database;

    if (await _nameExists(name)) {
      throw Exception('Il existe déjà un template du même nom');
    }

    String id = await _generateId();
    Template template = Template(
      id: id,
      name: name,
      canvasHeight: canvasHeight,
      canvasWidth: canvasWidth,
    );
    await db.insert('templates', template.toMap());

    await PageService().createPage(id, null, backgroundPath, 1);

    return id;
  }

  /// Vérifie en base si un nom de template est déjà pris.
  Future<bool> _nameExists(String name) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT id FROM templates WHERE name = ?',
      [name],
    );
    return maps.isNotEmpty;
  }

  /// Génère un ID unique incrémental au format "template_00001".
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    String? lastId = (await db.rawQuery('SELECT MAX(id) FROM templates'))
        .first['MAX(id)'] as String?;
    int nextId =
        lastId == null ? 1 : int.parse(lastId.substring(_prefix.length)) + 1;
    return _prefix + nextId.toString().padLeft(5, '0');
  }

  /// Charge un template par son ID. Lève une exception s'il est introuvable.
  Future<Template> loadTemplate(String id) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps =
        await db.rawQuery('SELECT * FROM templates WHERE id = ?', [id]);
    if (maps.isEmpty) throw Exception('Template not found');
    return Template.fromMap(maps.first);
  }

  /// Renomme un template. Lève une exception si le nom est déjà pris
  /// (sauf s'il s'agit du nom actuel du template).
  Future<void> renameTemplate(String id, String newName) async {
    final db = await DatabaseHelper().database;
    Template template = await loadTemplate(id);

    if (newName != template.name && await _nameExists(newName)) {
      throw Exception('Il existe déjà un template du même nom');
    }

    await db.update(
      'templates',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime un template, ses pages (cascade) et leurs images de fond.
  Future<void> deleteTemplate(String id) async {
    final db = await DatabaseHelper().database;

    // Les fichiers doivent être effacés AVANT que le cascade n'efface les lignes,
    // sinon on perd la trace des chemins.
    PageService pageService = PageService();
    List<PageModel> pages = await pageService.getPagesFromTemplate(id);
    for (PageModel page in pages) {
      await pageService.deleteBackgroundFile(page.backgroundPath);
    }

    await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  //////////////////////////////////////////////////////
  //                   RECHERCHE                      //
  //////////////////////////////////////////////////////

  /// Recherche des templates par nom.
  Future<List<Template>> searchTemplate(String query) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT * FROM templates WHERE name LIKE ?',
      ['%$query%'],
    );
    return maps.map((data) => Template.fromMap(data)).toList();
  }

  /// Retourne tous les templates, triés par nom.
  Future<List<Template>> getAllTemplates() async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps =
        await db.rawQuery('SELECT * FROM templates ORDER BY name ASC');
    return maps.map((data) => Template.fromMap(data)).toList();
  }
}