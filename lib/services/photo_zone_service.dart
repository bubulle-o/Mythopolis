import 'package:mythopolis/models/photo_zone.dart';
import 'package:mythopolis/services/database_helper.dart';

/// Service responsable des opérations CRUD sur les zones photo.
/// Même fonctionnement que TextZoneService : une zone appartient à une
/// page et porte ses coordonnées en fractions de la page (0 → 1).
class PhotoZoneService {

  static final PhotoZoneService _instance = PhotoZoneService._internal();
  factory PhotoZoneService() => _instance;
  PhotoZoneService._internal();

  static const String _prefix = "photoZone_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée une zone photo de forme [shapePath] et retourne son ID.
  /// Le zOrder la place au-dessus des zones photo existantes de la page.
  /// La photo elle-même (photoPath) sera choisie plus tard, dans la fiche.
  Future<String> addPhotoZone({
    required String parentPage,
    required String shapePath,
    required double width,
    required double height,
    required double topLeftCornerX,
    required double topLeftCornerY,
  }) async {
    final db = await DatabaseHelper().database;
    String id = await _generateId();

    // zOrder le plus élevé de la page, ou null si c'est la première zone
    num? lastZOrder = (await db.rawQuery(
      'SELECT MAX(zOrder) FROM photoZones WHERE parentPage = ?',
      [parentPage],
    )).first['MAX(zOrder)'] as num?;
    double zOrder = lastZOrder == null ? 1 : lastZOrder.toDouble() + 1;

    PhotoZone zone = PhotoZone(
      id: id,
      parentPage: parentPage,
      shapePath: shapePath,
      width: width,
      height: height,
      topLeftCornerX: topLeftCornerX,
      topLeftCornerY: topLeftCornerY,
      zOrder: zOrder,
    );

    await db.insert('photoZones', zone.toMap());
    return id;
  }

  /// Génère un ID unique incrémental au format "photoZone_00000001".
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    String? lastId = (await db.rawQuery('SELECT MAX(id) FROM photoZones'))
        .first['MAX(id)'] as String?;
    int nextId =
        lastId == null ? 1 : int.parse(lastId.substring(_prefix.length)) + 1;
    return _prefix + nextId.toString().padLeft(8, '0');
  }

  /// Charge une zone photo par son ID. Lève une exception si introuvable.
  Future<PhotoZone> loadPhotoZone(String id) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps =
        await db.rawQuery('SELECT * FROM photoZones WHERE id = ?', [id]);
    if (maps.isEmpty) throw Exception('PhotoZone not found');
    return PhotoZone.fromMap(maps.first);
  }

  /// Met à jour la position ou la taille d'une zone.
  /// Les paramètres null conservent la valeur actuelle.
  Future<void> updatePhotoZone({
    required String id,
    double? width,
    double? height,
    double? topLeftCornerX,
    double? topLeftCornerY,
  }) async {
    final db = await DatabaseHelper().database;
    PhotoZone zone = await loadPhotoZone(id);

    await db.update(
      'photoZones',
      {
        'width': width ?? zone.width,
        'height': height ?? zone.height,
        'topLeftCornerX': topLeftCornerX ?? zone.topLeftCornerX,
        'topLeftCornerY': topLeftCornerY ?? zone.topLeftCornerY,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime une zone photo.
  Future<void> deletePhotoZone(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('photoZones', where: 'id = ?', whereArgs: [id]);
  }

  //////////////////////////////////////////////////////
  //                    LECTURE                       //
  //////////////////////////////////////////////////////

  /// Retourne les zones photo d'une page, dans l'ordre d'empilement.
  Future<List<PhotoZone>> getPhotoZonesFromPage(String pageId) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery(
      'SELECT * FROM photoZones WHERE parentPage = ? ORDER BY zOrder ASC',
      [pageId],
    );
    return maps.map((data) => PhotoZone.fromMap(data)).toList();
  }
}
