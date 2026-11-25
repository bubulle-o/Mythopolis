import 'dart:isolate';
import 'dart:typed_data';

import 'package:mythopolis/models/crop_area.dart';
import 'package:mythopolis/models/page_model.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'package:sqflite/sqflite.dart';
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

  /// Recadre (si [crop] est fourni) puis redimensionne l'image source à
  /// [targetWidth] × [targetHeight], et l'enregistre en PNG dans
  /// `AppDocuments/backgrounds/pageId_horodatage.png`. Retourne le chemin.
  ///
  /// Nom horodaté : à chaque changement de fond le chemin est nouveau,
  /// sinon Flutter réafficherait l'ancienne image gardée en cache.
  Future<String> _importBackground(
    String sourcePath,
    String pageId,
    int targetWidth,
    int targetHeight, {
    CropArea? crop,
  }) async {
    final Uint8List bytes = await File(sourcePath).readAsBytes();

    // Décodage / recadrage / redimensionnement / encodage : plusieurs
    // secondes sur une grosse photo → dans un isolate, pour ne pas figer
    // l'interface. On ne lui passe que des données simples.
    final Uint8List? png = await Isolate.run(
      () => _processBackground(bytes, crop, targetWidth, targetHeight),
    );
    if (png == null) {
      throw Exception("Impossible de lire l'image sélectionnée.");
    }

    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory bgDir = Directory(p.join(docsDir.path, 'backgrounds'));
    await bgDir.create(recursive: true);

    final String fileName =
        '${pageId}_${DateTime.now().millisecondsSinceEpoch}.png';
    final String targetPath = p.join(bgDir.path, fileName);
    await File(targetPath).writeAsBytes(png);

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

  //////////////////////////////////////////////////////
  //                  IMAGE DE FOND                   //
  //////////////////////////////////////////////////////

  /// Remplace le fond d'une page par [sourcePath], recadrée selon [crop]
  /// (pixels de l'image originale) puis compressée à la taille du canvas.
  /// L'ancien fichier est supprimé une fois la base à jour.
  Future<void> setBackground(
    String pageId,
    String sourcePath,
    CropArea crop,
    int targetWidth,
    int targetHeight,
  ) async {
    final db = await DatabaseHelper().database;
    final PageModel page = await loadPage(pageId);

    final String newPath = await _importBackground(
      sourcePath, pageId, targetWidth, targetHeight,
      crop: crop,
    );

    try {
      await db.update(
        'pages',
        {'backgroundPath': newPath},
        where: 'id = ?',
        whereArgs: [pageId],
      );
    } catch (e) {
      await deleteBackgroundFile(newPath); // pas de fichier orphelin
      rethrow;
    }

    await deleteBackgroundFile(page.backgroundPath);
  }

  /// Retire le fond d'une page (fond blanc) et supprime son fichier.
  /// Pas via changePage : celui-ci traite null comme « ne pas changer ».
  Future<void> removeBackground(String pageId) async {
    final db = await DatabaseHelper().database;
    final PageModel page = await loadPage(pageId);

    await db.update(
      'pages',
      {'backgroundPath': null},
      where: 'id = ?',
      whereArgs: [pageId],
    );
    await deleteBackgroundFile(page.backgroundPath);
  }

  /// Supprime une page, son image de fond sur le disque et ses zones (cascade).
  /// Refuse de supprimer la dernière page d'une template ou d'une fiche.
  Future<void> deletePage(String id) async {
    final db = await DatabaseHelper().database;
    PageModel page = await loadPage(id);

    final List<String> siblings = await _getSiblingIds(db, page);
    if (siblings.length <= 1) {
      throw Exception('Impossible de supprimer la dernière page.');
    }

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
  //              DUPLICATION / ORDRE                 //
  //////////////////////////////////////////////////////

  /// Duplique une page juste après l'originale et retourne l'ID de la copie.
  /// Le fond est copié tel quel sous le nouvel ID (déjà à la bonne taille,
  /// pas de redimensionnement). Les pages sont ensuite renumérotées 0..n-1.
  ///
  /// TODO : copier aussi les zones (texte, photo, jauge) de la page.
  Future<String> duplicatePage(String id) async {
    final db = await DatabaseHelper().database;
    final PageModel source = await loadPage(id);

    // Hors transaction : _generateId utilise la connexion principale,
    // qui est bloquée pendant une transaction sqflite.
    final String newId = await _generateId();
    final String? newBackgroundPath =
        await _copyBackground(source.backgroundPath, newId);

    try {
      await db.transaction((txn) async {
        // Ordre actuel des pages du même parent, avec la copie insérée
        // juste après la source.
        final List<String> orderedIds = await _getSiblingIds(txn, source);
        orderedIds.insert(orderedIds.indexOf(source.id) + 1, newId);

        final PageModel copy = PageModel(
          id: newId,
          parentTemplate: source.parentTemplate,
          parentSheet: source.parentSheet,
          backgroundPath: newBackgroundPath,
          zOrder: 0, // valeur provisoire, fixée par la renumérotation
        );
        await txn.insert('pages', copy.toMap());
        await _renumber(txn, orderedIds);
      });
    } catch (e) {
      // La copie n'a pas été enregistrée : on ne laisse pas de fichier orphelin
      await deleteBackgroundFile(newBackgroundPath);
      rethrow;
    }

    return newId;
  }

  /// Enregistre un nouvel ordre : la page orderedIds[i] reçoit zOrder = i.
  /// Tout est fait dans une transaction : soit tout passe, soit rien.
  Future<void> reorderPages(List<String> orderedIds) async {
    final db = await DatabaseHelper().database;
    await db.transaction((txn) => _renumber(txn, orderedIds));
  }

  /// Copie le fichier de fond sous `dossier/newId.ext` (même dossier que la source).
  /// Retourne null si la page n'a pas de fond (ou si le fichier a disparu).
  Future<String?> _copyBackground(String? sourcePath, String newId) async {
    if (sourcePath == null) return null;
    final File source = File(sourcePath);
    if (!await source.exists()) return null;

    final String targetPath = p.join(
      p.dirname(sourcePath),
      '$newId${p.extension(sourcePath)}',
    );
    await source.copy(targetPath);
    return targetPath;
  }

  /// IDs des pages ayant le même parent (template ou fiche), dans l'ordre.
  Future<List<String>> _getSiblingIds(DatabaseExecutor db, PageModel page) async {
    final bool isTemplate = page.parentTemplate != null;
    final List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT id FROM pages WHERE ${isTemplate ? 'parentTemplate' : 'parentSheet'} = ? '
      'ORDER BY zOrder ASC',
      [isTemplate ? page.parentTemplate : page.parentSheet],
    );
    return maps.map((row) => row['id'] as String).toList();
  }

  /// Donne à chaque page son index dans la liste comme zOrder.
  Future<void> _renumber(DatabaseExecutor db, List<String> orderedIds) async {
    final Batch batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        'pages',
        {'zOrder': i.toDouble()},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
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

//////////////////////////////////////////////////////
//            TRAITEMENT D'IMAGE (ISOLATE)          //
//////////////////////////////////////////////////////

/// Décode, recadre, redimensionne et encode en PNG.
/// Fonction de premier niveau (hors classe) : elle tourne dans un isolate
/// et ne doit dépendre que de ses paramètres. Retourne null si l'image
/// est illisible.
Uint8List? _processBackground(
  Uint8List bytes,
  CropArea? crop,
  int targetWidth,
  int targetHeight,
) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Applique la rotation EXIF (photos de téléphone) : sans ça, les
  // coordonnées du recadrage, calculées sur l'image telle qu'affichée,
  // ne correspondraient pas aux pixels bruts.
  img.Image image = img.bakeOrientation(decoded);

  if (crop != null) {
    image = img.copyCrop(
      image,
      x: crop.x,
      y: crop.y,
      width: crop.width,
      height: crop.height,
    );
  }

  final img.Image resized = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );
  return img.encodePng(resized);
}
