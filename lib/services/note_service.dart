import 'package:lore_keeper/models/Folder.dart';
import 'package:lore_keeper/models/note.dart';
import 'package:lore_keeper/services/database_helper.dart';


class NoteService {
  
  // Instance unique (Singleton)
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();


  Future<void> createNote(String folderName, String parentFolder, String? iconPath) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> nameOk = await db.rawQuery('select name from folders where parentFolder = ?', [parentFolder]);

    if(!nameOk.any((map) => map['name'] == folderName)){
    String id = await _generateId();
    Note note = Note(id, folderName, parentFolder, iconPath, null, null);
    Map<String, dynamic> folderMap = note.toMap();
    await db.insert('folders', folderMap);
    }
    else{
      throw Exception('Il existe déjà un dossier du même nom à cet emplacement');
    }
  }

  Future<String> _generateId() async {
    final db = await DatabaseHelper().database;
    String? lastId = (await db.rawQuery('select MAX(id) from notes')).first['MAX(id)'] as String? ;
    int nextId = lastId == null ? 1 : int.parse(lastId.substring(7)) + 1; // Incrémente le compteur pour le nouvel ID
    return "note_"+ nextId.toString().padLeft( 5, '0');
  }


  Future<Note> loadNote(String id) async{
    final db = await DatabaseHelper().database;
    Note note = await db.rawQuery('SELECT * FROM notes WHERE id = ?', [id]).then((List<Map<String, dynamic>> maps) {
      if (maps.isNotEmpty) {
        return Note.fromMap(maps.first);
      } else {
        throw Exception('Note not found');
      }
    });

    return note;
  }

  Future<void> changeNote(String id, String? newName, String? newParent) async {
    final db = await DatabaseHelper().database;
    Note note = await loadNote(id);
    newName ??= note.name;
    newParent ??= note.parentFolder;

    List<Map<String, Object?>> nameOk = await db.rawQuery('select name from notes where parentFolder = ?', [newParent]);
    

    if(!nameOk.any((map) => map['name'] == newName)){
      await db.update('folders', 
      {'name': newName, 'parentFolder' : newParent},
      where : 'id = ?',
      whereArgs: [id]);
    }
    else{
      throw Exception('Il existe déjà une note du même nom à cet emplacement');
    }

    
  }

  Future<void> deleteNote(String id) async{
    final db = await DatabaseHelper().database ;
    await db.delete( 'notes',
    where : 'id = ?',
    whereArgs: [id]);
  }

  Future<List<Note>> getNoteFromFolder(Folder folder) async {
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery('SELECT * FROM notes WHERE parentFolder = ?', [folder.id]);
    List<Note> notes = [];
    for (Map<String, Object?> data in maps) {
      notes.add(Note.fromMap(data));
    }
    return notes;
  }

  Future<List<Note>> searchFolder(String query, Folder folder) async{
    final db = await DatabaseHelper().database;
    List<Map<String, Object?>> maps = await db.rawQuery('SELECT * FROM notes WHERE name LIKE ? AND parentFolder = ?',['%$query%' , folder.parentFolder]);
    
    List<Note> notes = [];
    for (Map<String, Object?> data in maps) {
      notes.add(Note.fromMap(data));
    }
    return notes;
  }
}