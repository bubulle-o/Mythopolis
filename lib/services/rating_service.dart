import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mythopolis/models/rating.dart';
import 'package:mythopolis/services/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Service des modèles de jauges (table `ratings`).
///
/// Deux sortes de jauges dans la même table (voir Rating) :
/// - PRÉDÉFINIES : recopiées depuis les fichiers de lib/graphism/rating/
///   par [syncBuiltInRatings] ;
/// - PERSONNALISÉES : créées par [addCustomRating], images copiées dans
///   `Documents/ratings/`.
class RatingService {

  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  static const String _folder = 'lib/graphism/rating/';
  static const String _customPrefix = 'rating_';

  /// Couleur par défaut des jauges prédéfinies (aperçu, premier choix).
  static const String defaultColor = 'jaune';

  // La synchronisation ne se fait qu'une fois par lancement de l'appli
  Future<void>? _syncDone;


  //////////////////////////////////////////////////////
  //              JAUGES PRÉDÉFINIES                  //
  //////////////////////////////////////////////////////

  /// Recopie les jauges prédéfinies dans la table (une seule fois par
  /// lancement ; les appels suivants attendent le même résultat).
  Future<void> syncBuiltInRatings() => _syncDone ??= _sync();

  /// Lit les fichiers et insère/met à jour une ligne par couleur :
  ///   rond_jaune_plein.png + rond_vide.png → type "rond", couleur "jaune".
  /// L'id est fixe ("builtin_rond_jaune") : relancer ne crée pas de doublon.
  /// Une jauge dont le fichier disparaît n'est PAS supprimée de la table,
  /// sinon les zones qui l'utilisent seraient supprimées en cascade.
  Future<void> _sync() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final Set<String> assets =
        manifest.listAssets().where((a) => a.startsWith(_folder)).toSet();

    final db = await DatabaseHelper().database;
    final Batch batch = db.batch();

    for (final String fullPath in assets) {
      final String fileName = fullPath.substring(_folder.length);
      if (!fileName.endsWith('_plein.png')) continue;

      // "rond_jaune_plein.png" → "rond_jaune" → type "rond", couleur "jaune"
      // (le DERNIER "_" sépare : un type peut contenir des "_")
      final String base = fileName.substring(0, fileName.length - '_plein.png'.length);
      final int separator = base.lastIndexOf('_');
      if (separator <= 0) continue; // pas de couleur dans le nom : ignoré
      final String type = base.substring(0, separator);
      final String color = base.substring(separator + 1);

      // L'image vide est commune à toutes les couleurs du type
      final String emptyPath = '$_folder${type}_vide.png';
      if (!assets.contains(emptyPath)) continue; // pas de "vide" : ignoré

      final Rating rating = Rating(
        id: 'builtin_${type}_$color',
        name: type,
        color: color,
        emptyPath: emptyPath,
        fullPath: fullPath,
        isBuiltIn: true,
      );
      batch.insert('ratings', rating.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }


  //////////////////////////////////////////////////////
  //             JAUGES PERSONNALISÉES                //
  //////////////////////////////////////////////////////

  /// Crée une jauge personnalisée (une seule couleur) à partir de deux
  /// images choisies par l'utilisateur, copiées dans le dossier de l'appli.
  /// Retourne son ID. Refuse un nom déjà utilisé par un autre type.
  Future<String> addCustomRating(
    String name,
    String fullSourcePath,
    String emptySourcePath,
  ) async {
    final db = await DatabaseHelper().database;
    name = name.trim();
    if (name.isEmpty) throw Exception('Le nom est obligatoire.');

    final existing = await db.rawQuery(
        'SELECT id FROM ratings WHERE name = ? LIMIT 1', [name]);
    if (existing.isNotEmpty) {
      throw Exception('Une jauge "$name" existe déjà.');
    }

    final String id = await _generateId();

    // Copie des deux images : la jauge ne dépend plus des fichiers d'origine
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(docsDir.path, 'ratings'));
    await dir.create(recursive: true);
    final String fullPath =
        p.join(dir.path, '${id}_plein${p.extension(fullSourcePath)}');
    final String emptyPath =
        p.join(dir.path, '${id}_vide${p.extension(emptySourcePath)}');
    await File(fullSourcePath).copy(fullPath);
    await File(emptySourcePath).copy(emptyPath);

    final Rating rating = Rating(
      id: id,
      name: name,
      color: null,
      emptyPath: emptyPath,
      fullPath: fullPath,
      isBuiltIn: false,
    );
    await db.insert('ratings', rating.toMap());
    return id;
  }

  /// Génère un ID incrémental "rating_00001" (les jauges prédéfinies,
  /// "builtin_…", ne comptent pas).
  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    final String? lastId = (await db.rawQuery(
      "SELECT MAX(id) FROM ratings WHERE id LIKE '$_customPrefix%'",
    )).first['MAX(id)'] as String?;
    final int nextId = lastId == null
        ? 1
        : int.parse(lastId.substring(_customPrefix.length)) + 1;
    return _customPrefix + nextId.toString().padLeft(5, '0');
  }


  //////////////////////////////////////////////////////
  //                    LECTURE                       //
  //////////////////////////////////////////////////////

  /// Toutes les jauges, triées par type puis couleur.
  Future<List<Rating>> getAllRatings() async {
    await syncBuiltInRatings();
    final db = await DatabaseHelper().database;
    final maps = await db.rawQuery('SELECT * FROM ratings ORDER BY name, color');
    return maps.map((data) => Rating.fromMap(data)).toList();
  }

  /// Charge une jauge par son ID. Lève une exception si introuvable.
  Future<Rating> loadRating(String id) async {
    await syncBuiltInRatings();
    final db = await DatabaseHelper().database;
    final maps = await db.rawQuery('SELECT * FROM ratings WHERE id = ?', [id]);
    if (maps.isEmpty) throw Exception('Rating not found');
    return Rating.fromMap(maps.first);
  }
}
