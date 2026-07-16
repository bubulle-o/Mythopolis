import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:provider/provider.dart';
import 'package:mythopolis/models/folder.dart';
import 'package:mythopolis/models/note.dart';
import 'package:mythopolis/providers/folder_provider.dart';
import 'package:mythopolis/providers/note_provider.dart';


//////////////////////////////////////////////////////
//              WIDGET RÉUTILISABLE                 //
//////////////////////////////////////////////////////

/// Barre d'outils Quill + zone d'édition, avec polices custom et
/// bouton de lien interne (notes/dossiers).
///
/// Ne gère rien d'autre que le texte — pas de sauvegarde, pas de
/// bannière. C'est à l'écran parent de placer ce widget où il veut
/// et d'afficher ses propres éléments (bannière, etc.) autour.
class QuillToolbarEditor extends StatelessWidget {
  final QuillController controller;

  const QuillToolbarEditor({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre d'outils de mise en forme — prend toute la largeur
        QuillSimpleToolbar(
          controller: controller,
          config: QuillSimpleToolbarConfig(
            embedButtons: FlutterQuillEmbeds.toolbarButtons(),
            // Bouton custom pour insérer un lien interne (note/dossier)
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: const Icon(Icons.link_rounded),
                tooltip: 'Lien interne',
                onPressed: () => _showLinkPicker(context),
              ),
            ],
            buttonOptions: QuillSimpleToolbarButtonOptions(
              fontFamily: QuillToolbarFontFamilyButtonOptions(
                items: const {
                  'Cardo': 'Cardo',
                  'EB Garamond': 'EBGaramond',
                  'Cinzel': 'Cinzel',
                  'MedievalSharp': 'MedievalSharp',
                  'UnifrakturMaguntia': 'UnifrakturMaguntia',
                  'Pirata One': 'PirataOne',
                  'Orbitron': 'Orbitron',
                  'Audiowide': 'Audiowide',
                  'Lexend': 'Lexend',
                },
              ),
            ),
          ),
        ),

        // Zone d'édition avec marges latérales
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 64, // marge gauche/droite
              vertical: 24,   // marge haut/bas
            ),
            child: QuillEditor.basic(
              controller: controller,
              config: QuillEditorConfig(
                embedBuilders: FlutterQuillEmbeds.editorBuilders(),
              ),
            ),
          ),
        ),
      ],
    );
  }


  //////////////////////////////////////////////////////
  //                     LIENS                        //
  //////////////////////////////////////////////////////

  /// Ouvre un dialog pour choisir la cible d'un lien interne
  /// (dossier ou note) et son texte affiché, puis l'insère.
  void _showLinkPicker(BuildContext context) async {
    List<Folder> allFolders = await context.read<FolderProvider>().getAllFolders();
    List<Note> allNotes = await context.read<NoteProvider>().getAllNotes();
    List<Map<String, dynamic>> tree = _buildWholeTree(allFolders, allNotes, null, 0);
    final TextEditingController nameController = TextEditingController();
    String selectedId = '';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Lien vers...'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Nom affiché'),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ...tree.map((item) {
                        int depth = item['depth'];

                        if (item['type'] == 'folder') {
                          Folder f = item['item'];
                          return ListTile(
                            contentPadding: EdgeInsets.only(left: 16.0 + depth * 20),
                            leading: const Icon(Icons.folder),
                            title: Text(f.name),
                            selected: selectedId == f.id,
                            onTap: () => setState(() => selectedId = f.id),
                          );
                        } else {
                          Note n = item['item'];
                          return ListTile(
                            contentPadding: EdgeInsets.only(left: 16.0 + depth * 20),
                            leading: const Icon(Icons.note),
                            title: Text(n.name),
                            selected: selectedId == n.id,
                            onTap: () => setState(() => selectedId = n.id),
                          );
                        }
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                try {
                  _insertLink(nameController.text, selectedId);
                  Navigator.pop(dialogContext);
                } catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Insérer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit l'arborescence complète (dossiers + notes), sans exclusion.
  List<Map<String, dynamic>> _buildWholeTree(
      List<Folder> allFolders, List<Note> allNotes, String? parentId, int depth) {
    List<Map<String, dynamic>> result = [];

    for (Note note in allNotes) {
      if (note.parentFolder == parentId) {
        result.add({'item': note, 'depth': depth, 'type': 'note'});
      }
    }

    for (Folder folder in allFolders) {
      if (folder.parentFolder == parentId) {
        result.add({'item': folder, 'depth': depth, 'type': 'folder'});
        result.addAll(_buildWholeTree(allFolders, allNotes, folder.id, depth + 1));
      }
    }
    return result;
  }

  /// Insère un lien interne dans le document Quill, à la position du curseur.
  void _insertLink(String nom, String id) {
    controller.replaceText(
      controller.selection.baseOffset,
      controller.selection.extentOffset - controller.selection.baseOffset,
      nom,
      TextSelection.collapsed(offset: controller.selection.baseOffset + nom.length),
    );
    controller.formatText(
      controller.selection.baseOffset - nom.length,
      nom.length,
      LinkAttribute('https://$id'),
    );
  }
}