import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'dart:io';

/// Service responsable des opérations CRUD sur les pages.
/// Une page appartient soit à un template, soit à une fiche (jamais aux deux).
class PageService {

  static final PageService _instance = PageService._internal();
  factory PageService() => _instance;
  PageService._internal();

  static const String _prefix = "page_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée une page et retourne son ID.
  Future<String> createPage(
    String? parentTemplate,
    String? parentSheet,
    String? backgroundPath,
    double zOrder,
  ) async {
    final db = await DatabaseHelper().database;
    String id = await _generateId();

    PageModel page = PageModel(
      id: id,
      parentTemplate: parentTemplate,
      parentSheet: parentSheet,
      backgroundPath: backgroundPath,
      zOrder: zOrder,
    );

    await db.insert('pages', page.toMap());
    return id;
  }

  /// Génère un ID unique incrémental au format "page_00001".
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    String? lastId = (await db.rawQuery('SELECT MAX(id) FROM pages'))
        .first['MAX(id)'] as String?;
    int nextId =
        lastId == null ? 1 : int.parse(lastId.substring(_prefix.length)) + 1;
    return _prefix + nextId.toString().padLeft(5, '0');
  }

  /// Charge une page par son ID. Lève une exception si elle est introuvable.
  Future<PageModel> loadPage(String id) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps =
        await db.rawQuery('SELECT * FROM pages WHERE id = ?', [id]);
    if (maps.isEmpty) throw Exception('Page not found');
    return PageModel.fromMap(maps.first);
  }

  /// Met à jour le fond ou la position d'une page.
  /// Les paramètres null conservent la valeur actuelle.
  Future<void> changePage(String id, String? backgroundPath, double? zOrder) async {
    final db = await DatabaseHelper().database;
    PageModel page = await loadPage(id);
    backgroundPath ??= page.backgroundPath;
    zOrder ??= page.zOrder;

    await db.update(
      'pages',
      {'backgroundPath': backgroundPath, 'zOrder': zOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime une page, son image de fond sur le disque et ses zones (cascade).
  Future<void> deletePage(String id) async {
    final db = await DatabaseHelper().database;
    PageModel page = await loadPage(id);

    await deleteBackgroundFile(page.backgroundPath);
    await db.delete('pages', where: 'id = ?', whereArgs: [id]);
  }

  /// Supprime physiquement un fichier de fond s'il existe.
  Future<void> deleteBackgroundFile(String? path) async {
    if (path == null) return;
    File file = File(path);
    if (await file.exists()) await file.delete();
  }

  //////////////////////////////////////////////////////
  //                    LECTURE                       //
  //////////////////////////////////////////////////////

  /// Retourne les pages d'un template, dans l'ordre d'affichage.
  Future<List<PageModel>> getPagesFromTemplate(String templateId) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT * FROM pages WHERE parentTemplate = ? ORDER BY zOrder ASC',
      [templateId],
    );
    return maps.map((data) => PageModel.fromMap(data)).toList();
  }
}