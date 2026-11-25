import 'package:mythopolis/models/rating_zone.dart';
import 'package:mythopolis/services/database_helper.dart';

/// Service responsable des opérations CRUD sur les jauges posées sur une
/// page (table `ratingZones`). Même fonctionnement que les autres zones :
/// coordonnées en fractions de la page (0 → 1).
class RatingZoneService {

  static final RatingZoneService _instance = RatingZoneService._internal();
  factory RatingZoneService() => _instance;
  RatingZoneService._internal();

  static const String _prefix = "ratingZone_";

  //////////////////////////////////////////////////////
  //                      CRUD                        //
  //////////////////////////////////////////////////////

  /// Crée une jauge sur une page et retourne son ID.
  /// [zone.id] et [zone.zOrder] sont ignorés : calculés ici.
  Future<String> addRatingZone(RatingZone zone) async {
    final db = await DatabaseHelper().database;
    zone.id = await _generateId();

    // Au-dessus des jauges existantes de la page
    final num? lastZOrder = (await db.rawQuery(
      'SELECT MAX(zOrder) FROM ratingZones WHERE parentPage = ?',
      [zone.parentPage],
    )).first['MAX(zOrder)'] as num?;
    zone.zOrder = lastZOrder == null ? 1 : lastZOrder.toDouble() + 1;

    await db.insert('ratingZones', zone.toMap());
    return zone.id;
  }

  /// Génère un ID unique incrémental au format "ratingZone_00000001".
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    final String? lastId = (await db.rawQuery('SELECT MAX(id) FROM ratingZones'))
        .first['MAX(id)'] as String?;
    final int nextId =
        lastId == null ? 1 : int.parse(lastId.substring(_prefix.length)) + 1;
    return _prefix + nextId.toString().padLeft(8, '0');
  }

  /// Enregistre toutes les valeurs de [zone] (position, taille, options).
  /// Plus simple qu'une liste de paramètres optionnels : l'appelant
  /// modifie une copie de la zone, puis la sauvegarde entière.
  Future<void> updateRatingZone(RatingZone zone) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'ratingZones',
      zone.toMap(),
      where: 'id = ?',
      whereArgs: [zone.id],
    );
  }

  /// Supprime une jauge.
  Future<void> deleteRatingZone(String id) async {
    final db = await DatabaseHelper().database;
    await db.delete('ratingZones', where: 'id = ?', whereArgs: [id]);
  }

  //////////////////////////////////////////////////////
  //                    LECTURE                       //
  //////////////////////////////////////////////////////

  /// Retourne les jauges d'une page, dans l'ordre d'empilement.
  Future<List<RatingZone>> getRatingZonesFromPage(String pageId) async {
    final db = await DatabaseHelper().database;
    final maps = await db.rawQuery(
      'SELECT * FROM ratingZones WHERE parentPage = ? ORDER BY zOrder ASC',
      [pageId],
    );
    return maps.map((data) => RatingZone.fromMap(data)).toList();
  }
}
