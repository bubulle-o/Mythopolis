import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DatabaseHelper {
  
  // Instance unique (Singleton)
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // La base de données 
  Database? _database;

  // Getter pour accéder à la base de données
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }


  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parentFolder TEXT,
          iconPath TEXT,
          FOREIGN KEY (parentFolder) REFERENCES folders(id) ON DELETE CASCADE
        )
        ''');

        await db.execute('''
          CREATE TABLE notes(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parentFolder TEXT NOT NULL,
          iconPath TEXT,
          content TEXT, 
          bookmarks TEXT,
          FOREIGN KEY (parentFolder) REFERENCES folders(id) ON DELETE CASCADE
        )
        ''');


      },
      onOpen : (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    );
  }
}