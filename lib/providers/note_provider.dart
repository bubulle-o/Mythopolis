import 'package:flutter/material.dart';
import 'package:lore_keeper/services/note_service.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class NoteProvider extends ChangeNotifier {
  
  final NoteService _service = NoteService();
  Map<String, List<Note>> _NotesByParent = {};
  List<Note> _searchResults = [];

  List<Note> getNotes(String parentId) {
    return _NotesByParent[parentId] ?? [];
  }

  List<Note> getSearchNotes() {
    return _searchResults ;
  }

  Future<void> loadNotes(String parentId) async {
    _NotesByParent[parentId] = await _service.getNotesFromFolder(parentId);
    notifyListeners();
  }

  Future<void> createNote(String name, String parentFolder, String? iconPath) async {
    try {
      await _service.createNote(name, parentFolder , iconPath);
      await loadNotes(parentFolder);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changeNote(String id, String? name, String newParentFolder) async {
    Note old = await _service.loadNote(id);
    String? oldParentFolder = old.parentFolder;
    await _service.changeNote(id, name, newParentFolder);
    await loadNotes(newParentFolder);
    await loadNotes(oldParentFolder);
    notifyListeners();
  }

  Future<void> deleteNote(String id, String parentFolder) async {
    await _service.deleteNote(id);
    await loadNotes(parentFolder);
    notifyListeners();
  }


  Future<void> searchNotes(String query, String parentFolder) async {
    _searchResults = await _service.searchNote(query, parentFolder);
    notifyListeners();
    return;

  }
}