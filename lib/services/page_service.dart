import 'dart:typed_data';

import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'dart:io';

class PageService {

  static final PageService _instance = PageService._internal();
  factory PageService() => _instance;
  PageService._internal();

  static const String _prefix = "page_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée une page et retourne son ID.
  /// Si [sourceBackgroundPath] est fourni, l'image est redimensionnée à
  /// [targetWidth] × [targetHeight] et copiée dans le stockage de l'app.
  Future<String> addPage(
    String? parentTemplate,
    String? parentSheet,
    String? sourceBackgroundPath,
    int targetWidth,
    int targetHeight,
    double zOrder,
  ) async {
    final db = await DatabaseHelper().database;
    String id = await _generateId();

    // Copie + compression du fond, si présent
    String? storedBackgroundPath;
    if (sourceBackgroundPath != null) {
      storedBackgroundPath = await _importBackground(
        sourceBackgroundPath, id, targetWidth, targetHeight,
      );
    }

    PageModel page = PageModel(
      id: id,
      parentTemplate: parentTemplate,
      parentSheet: parentSheet,
      backgroundPath: storedBackgroundPath,
      zOrder: zOrder,
    );

    await db.insert('pages', page.toMap());
    return id;
  }

  /// Redimensionne l'image source et l'enregistre en PNG dans
  /// <AppDocuments>/backgrounds/<pageId>.png. Retourne le chemin stocké.
  Future<String> _importBackground(
    String sourcePath,
    String pageId,
    int targetWidth,
    int targetHeight,
  ) async {
    // 1. Lire et décoder l'image source
    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception("Impossible de lire l'image sélectionnée.");
    }

    // 2. Redimensionner à la taille cible
    final img.Image resized = img.copyResize(
      decoded,
      width: targetWidth,
      height: targetHeight,
    );

    // 3. Construire le dossier de destination
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory bgDir = Directory(p.join(docsDir.path, 'backgrounds'));
    await bgDir.create(recursive: true);

    // 4. Écrire en PNG
    final String targetPath = p.join(bgDir.path, '$pageId.png');
    final File targetFile = File(targetPath);
    await targetFile.writeAsBytes(img.encodePng(resized));

    return targetPath;
  }

  // ... le reste inchangé (_generateId, loadPage, changePage,
  //     deletePage, deleteBackgroundFile, getPagesFromTemplate)


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