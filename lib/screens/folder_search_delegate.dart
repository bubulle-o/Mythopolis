import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import '../providers/note_provider.dart';
import '../utils/enum.dart';
import 'folder_screen.dart';
import 'note_read_screen.dart';


//////////////////////////////////////////////////////
//                 WIDGET PRINCIPAL                 //
//////////////////////////////////////////////////////

/// Délégué de recherche pour le contenu d'un dossier.
/// Branché sur showSearch(), il gère la barre de recherche
/// native de Flutter (suggestions + résultats).
///
/// [scope] limite la recherche au type d'élément de l'onglet actif :
/// onglet "Dossiers" → dossiers, "Notes" → notes, etc.
class FolderSearchDelegate extends SearchDelegate {

  // Dossier de contexte — null = recherche depuis la racine
  Folder? folder;

  // Types d'éléments recherchés
  final SearchScope scope;

  FolderSearchDelegate(this.folder, {this.scope = SearchScope.all});

  @override
  String get searchFieldLabel {
    switch (scope) {
      case SearchScope.all: return 'Rechercher';
      case SearchScope.folders: return 'Rechercher un dossier';
      case SearchScope.notes: return 'Rechercher une note';
      case SearchScope.sheets: return 'Rechercher une fiche';
    }
  }

  bool get _searchFolders =>
      scope == SearchScope.all || scope == SearchScope.folders;

  // Une note est toujours rattachée à un dossier : pas de recherche à la racine
  bool get _searchNotes =>
      folder != null && (scope == SearchScope.all || scope == SearchScope.notes);


  //////////////////////////////////////////////////////
  //                    ACTIONS                       //
  //////////////////////////////////////////////////////

  @override
  List<Widget> buildActions(BuildContext context) {
    // Bouton pour vider la saisie
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () => query = '',
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    // Bouton retour
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }


  //////////////////////////////////////////////////////
  //                   AFFICHAGE                      //
  //////////////////////////////////////////////////////

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (scope == SearchScope.sheets) {
      return Center(child: Text('Recherche de fiches - à venir'));
    }
    if (query.isEmpty) return Center(child: Text('Tapez pour chercher...'));
    _launchSearch(context);
    return _buildSearchResults(context);
  }

  /// Lance la recherche uniquement sur les types concernés par [scope].
  void _launchSearch(BuildContext context) {
    if (_searchFolders) {
      context.read<FolderProvider>().searchFolders(query, folder);
    }
    if (_searchNotes) {
      context.read<NoteProvider>().searchNotes(query, folder!.id);
    }
    // TODO: fiches, quand le provider des fiches existera
  }

  /// Liste les éléments correspondant à la recherche.
  Widget _buildSearchResults(BuildContext context) {
    if (scope == SearchScope.sheets) {
      return Center(child: Text('Recherche de fiches - à venir'));
    }

    final List<Folder> folders = _searchFolders
        ? context.watch<FolderProvider>().getSearchFolders()
        : [];
    final List<Note> notes = _searchNotes
        ? context.watch<NoteProvider>().getSearchNotes()
        : [];
    final List<Object> items = [...folders, ...notes];

    if (items.isEmpty && query.isNotEmpty) {
      return Center(child: Text('Aucun résultat'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is Folder) return _buildFolderResult(context, item);
        return _buildNoteResult(context, item as Note);
      },
    );
  }

  Widget _buildFolderResult(BuildContext context, Folder result) {
    return ListTile(
      leading: Icon(Icons.folder),
      title: Text(result.name),
      onTap: () {
        close(context, null);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FolderScreen(folder: result)),
        );
      },
    );
  }

  Widget _buildNoteResult(BuildContext context, Note result) {
    return ListTile(
      leading: Icon(Icons.note),
      title: Text(result.name),
      onTap: () {
        close(context, null);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NoteReadScreen(note: result)),
        );
      },
    );
  }
}
