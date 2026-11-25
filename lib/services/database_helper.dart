import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


//////////////////////////////////////////////////////
//                    SINGLETON                     //
//////////////////////////////////////////////////////

/// Point d'accès unique à la base de données SQLite.
/// Le pattern Singleton garantit qu'une seule instance
/// de la base est ouverte pendant toute la durée de vie de l'app.
class DatabaseHelper {

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  /// Retourne la base de données, en l'initialisant si nécessaire.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }


  //////////////////////////////////////////////////////
  //                 INITIALISATION                   //
  //////////////////////////////////////////////////////

  /// Version actuelle du schéma. À augmenter de 1 à chaque changement
  /// de structure, en ajoutant l'étape correspondante dans _migrate.
  static const int _schemaVersion = 2;

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'database.db');
    return await openDatabase(
      path,
      version: _schemaVersion,
      // Base neuve : schéma de la version 1, puis toutes les migrations.
      // Ainsi une base neuve et une base mise à jour sont identiques.
      onCreate: (db, version) async {
        await _createSchema(db, 1);
        await _migrate(db, 1, version);
      },
      // Base existante plus ancienne : seulement les migrations manquantes
      onUpgrade: _migrate,
      onOpen: (db) async {
        // Active les clés étrangères à chaque ouverture (désactivées par défaut sur SQLite)
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }


  //////////////////////////////////////////////////////
  //                   MIGRATIONS                     //
  //////////////////////////////////////////////////////

  /// Fait passer la base de [from] à [to], une version après l'autre.
  /// ALTER TABLE ajoute des colonnes sans perdre les données existantes.
  Future<void> _migrate(Database db, int from, int to) async {
    // ── v1 → v2 : jauges ──────────────────────────────
    if (from < 2) {
      // ratings : une ligne = une couleur d'un type de jauge
      //   name      = nom du type (ex. "rond")
      //   color     = couleur (ex. "jaune"), null pour une jauge perso
      //   isBuiltIn = 1 si images dans les assets, 0 si fichiers copiés
      await db.execute('ALTER TABLE ratings ADD COLUMN color TEXT');
      await db.execute(
          'ALTER TABLE ratings ADD COLUMN isBuiltIn INTEGER NOT NULL DEFAULT 0');

      // ratingZones : cadre et disposition des icônes
      //   height       = hauteur du cadre (fraction de la page)
      //   layout       = "line", "rows" ou "circle"
      //   rowCount     = nombre de lignes (disposition "rows")
      //   showEmpty    = 1 si les icônes vides sont visibles en lecture
      await db.execute(
          'ALTER TABLE ratingZones ADD COLUMN height REAL NOT NULL DEFAULT 0.05');
      await db.execute(
          "ALTER TABLE ratingZones ADD COLUMN layout TEXT NOT NULL DEFAULT 'line'");
      await db.execute(
          'ALTER TABLE ratingZones ADD COLUMN rowCount INTEGER NOT NULL DEFAULT 2');
      await db.execute(
          'ALTER TABLE ratingZones ADD COLUMN showEmpty INTEGER NOT NULL DEFAULT 1');
    }
  }


  //////////////////////////////////////////////////////
  //                     SCHÉMA                       //
  //////////////////////////////////////////////////////

  Future<void> _createSchema(Database db, int version) async {
    // Table des dossiers — supporte la hiérarchie via parentFolder
    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentFolder TEXT,
        iconPath TEXT,
        FOREIGN KEY (parentFolder) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');

    // Table des notes — toujours rattachée à un dossier
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentFolder TEXT NOT NULL,
        iconPath TEXT,
        content TEXT,
        bookmarks TEXT,
        bannerPath TEXT,
        bannerAlignment TEXT NOT NULL,
        FOREIGN KEY (parentFolder) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE templates(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        canvasHeight INTEGER NOT NULL,
        canvasWidth INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ratings(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emptyPath TEXT NOT NULL,
        fullPath TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sheets(
        id TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE pages(
        id TEXT PRIMARY KEY,
        parentTemplate TEXT,
        parentSheet TEXT,
        backgroundPath TEXT,
        zOrder REAL NOT NULL,
        FOREIGN KEY (parentTemplate) REFERENCES templates(id) ON DELETE CASCADE,
        FOREIGN KEY (parentSheet) REFERENCES sheets(id) ON DELETE CASCADE,
        CHECK (
          (parentTemplate IS NOT NULL AND parentSheet IS NULL)
          OR
          (parentTemplate IS NULL AND parentSheet IS NOT NULL)
        )
      )
    ''');

    await db.execute('''
      CREATE TABLE textZones(
        id TEXT PRIMARY KEY,
        parentPage TEXT NOT NULL,
        content TEXT,
        height REAL NOT NULL,
        width REAL NOT NULL,
        topLeftCornerX REAL NOT NULL,
        topLeftCornerY REAL NOT NULL,
        isLocked INTEGER NOT NULL,
        zOrder REAL NOT NULL,
        FOREIGN KEY (parentPage) REFERENCES pages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE photoZones(
        id TEXT PRIMARY KEY,
        parentPage TEXT NOT NULL,
        shapePath TEXT,
        photoPath TEXT,
        height REAL NOT NULL,
        width REAL NOT NULL,
        topLeftCornerX REAL NOT NULL,
        topLeftCornerY REAL NOT NULL,
        belowBackground INTEGER NOT NULL DEFAULT 0,
        zOrder REAL NOT NULL,
        FOREIGN KEY (parentPage) REFERENCES pages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ratingZones(
        id TEXT PRIMARY KEY,
        parentPage TEXT NOT NULL,
        ratingId TEXT NOT NULL,
        width REAL NOT NULL,
        iconSize REAL NOT NULL,
        topLeftCornerX REAL NOT NULL,
        topLeftCornerY REAL NOT NULL,
        currentValue INTEGER NOT NULL,
        maxValue INTEGER NOT NULL,
        zOrder REAL NOT NULL,
        FOREIGN KEY (parentPage) REFERENCES pages(id) ON DELETE CASCADE,
        FOREIGN KEY (ratingId) REFERENCES ratings(id) ON DELETE CASCADE
      )
    ''');
  }
}