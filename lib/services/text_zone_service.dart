import 'package:mythopolis/models/text_zone.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'package:mythopolis/utils/placeholder.dart';

/// Service responsable des opérations CRUD sur les zones de texte.
/// Une zone appartient à une page (de template ou de fiche) et porte
/// ses coordonnées en pourcentage de la page.
class TextZoneService {

  static final TextZoneService _instance = TextZoneService._internal();
  factory TextZoneService() => _instance;
  TextZoneService._internal();

  static const String _prefix = "textZone_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée une zone de texte dans une page et retourne son ID.
  /// Le zOrder est calculé pour placer la zone au-dessus des existantes
  /// de la même page. Une zone non verrouillée reçoit le placeholder ;
  /// un texte fixe ([isLocked] à true) naît vide.
  Future<String> addTextZone({
    required String parentPage,
    required double width,
    required double height,
    required double topLeftCornerX,
    required double topLeftCornerY,
    required bool isLocked,
  }) async {
    final db = await DatabaseHelper().database;
    String id = await _generateId();

    // zOrder le plus élevé de la page, ou null si c'est la première zone
    num? lastZOrder = (await db.rawQuery(
      'SELECT MAX(zOrder) FROM textZones WHERE parentPage = ?',
      [parentPage],
    )).first['MAX(zOrder)'] as num?;

    double zOrder = lastZOrder == null ? 1 : lastZOrder.toDouble() + 1;

    // Le contenu est stocké en Delta JSON, jamais en texte brut
    String? content = isLocked ? null : placeholderDelta();

    TextZone zone = TextZone(
      id: id,
      parentPage: parentPage,
      content: content,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
      isLocked: isLocked,
      zOrder: zOrder,
    );

    await db.insert('textZones', zone.toMap());
    return id;
  }

  /// Génère un ID unique incrémental au format "textZone_00000001".
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    String? lastId = (await db.rawQuery('SELECT MAX(id) FROM textZones'))
        .first['MAX(id)'] as String?;
    int nextId =
        lastId == null ? 1 : int.parse(lastId.substring(_prefix.length)) + 1;
    return _prefix + nextId.toString().padLeft(8, '0');
  }

  /// Charge une zone de texte par son ID. Lève une exception si elle est introuvable.
  Future<TextZone> loadTextZone(String id) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps =
        await db.rawQuery('SELECT * FROM textZones WHERE id = ?', [id]);
    if (maps.isEmpty) throw Exception('TextZone not found');
    return TextZone.fromMap(maps.first);
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
    final db = await DatabaseHelper().database;
    TextZone textZone = await loadTextZone(id);

    zOrder ??= textZone.zOrder;
    width ??= textZone.width;
    height ??= textZone.height;
    topLeftCornerX ??= textZone.topLeftCornerX;
    topLeftCornerY ??= textZone.topLeftCornerY;
    content ??= textZone.content;

    await db.update(
      'textZones',
      {
        'width': width,
        'height': height,
        'topLeftCornerX': topLeftCornerX,
        'topLeftCornerY': topLeftCornerY,
        'content': content,
        'zOrder': zOrder,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime une zone de texte.
  Future<void> deleteTextZone(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('textZones', where: 'id = ?', whereArgs: [id]);
  }

  //////////////////////////////////////////////////////
  //                    LECTURE                       //
  //////////////////////////////////////////////////////

  /// Retourne les zones de texte d'une page, dans l'ordre d'empilement.
  Future<List<TextZone>> getTextZonesFromPage(String pageId) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT * FROM textZones WHERE parentPage = ? ORDER BY zOrder ASC',
      [pageId],
    );
    return maps.map((data) => TextZone.fromMap(data)).toList();
  }
}