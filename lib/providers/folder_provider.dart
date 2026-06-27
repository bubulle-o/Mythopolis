import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../services/folder_service.dart';

class FolderProvider extends ChangeNotifier {
  
  final FolderService _service = FolderService();
  Map<String?, List<Folder>> _foldersByParent = {};
  List<Folder> _searchResults = [];

  List<Folder> getFolders(String? parentId) {
    return _foldersByParent[parentId] ?? [];
  }

  List<Folder> getSearchFolders() {
    return _searchResults ;
  }

  Future<void> loadFolders(String? parentId) async {
    _foldersByParent[parentId] = await _service.getDescendants(parentId);
    notifyListeners();
  }

  Future<void> createFolder(String name, String? parentFolder, String? iconPath) async {
    try {
      await _service.createFolder(name, parentFolder, iconPath);
      await loadFolders(parentFolder);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changeFolder(String id, String? name, String? newParentFolder) async {
    Folder old = await _service.loadFolder(id);
    String? oldParentFolder = old.parentFolder;
    await _service.changeFolder(id, name, newParentFolder);
    await loadFolders(newParentFolder);
    await loadFolders(oldParentFolder);
    notifyListeners();
  }

  Future<void> deleteFolder(String id, String? parentFolder) async {
    await _service.deleteFolder(id);
    await loadFolders(parentFolder);
    notifyListeners();
  }

  Future<List<Folder>> getAllFolders() async {
    return await _service.getAllFolders();
  }

  Future<void> searchFolders(String query, Folder? folder) async {
    _searchResults = await _service.searchFolder(query, folder);
    notifyListeners();
    return;

  }
}