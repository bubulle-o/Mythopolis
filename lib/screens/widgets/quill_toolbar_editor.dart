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

/// Barre d'outils Quill seule, avec polices custom et bouton de lien
/// interne (notes/dossiers).
///
/// Ne contient PAS la zone d'édition — elle se branche sur n'importe
/// quel QuillController. Réutilisable pour les notes, les fiches et
/// les zones de texte des templates.
///
/// [formatOnly] à true : uniquement la mise en forme du texte (police,
/// taille, couleur, gras, alignement…). Pas de lien, d'image, de liste,
/// de titre ni d'annuler/refaire. Utilisé par les zones de texte des
/// templates, où l'on règle le style sans toucher au contenu.
class QuillToolbar extends StatefulWidget {
  final QuillController controller;
  final bool formatOnly;

  const QuillToolbar({
    super.key,
    required this.controller,
    this.formatOnly = false,
  });

  @override
  State<QuillToolbar> createState() => _QuillToolbarState();
}

class _QuillToolbarState extends State<QuillToolbar> {
  QuillController get controller => widget.controller;

  // Dernier état connu du controller : sert à restaurer le style
  // "en attente" (gras, police, couleur... choisis sans texte
  // sélectionné) quand l'éditeur reprend le focus.
  Style _lastToggledStyle = const Style();
  TextSelection? _lastSelection;
  void Function(TextSelection)? _previousOnSelectionChanged;

  //////////////////////////////////////////////////////
  //          CONSERVATION DU STYLE EN ATTENTE        //
  //////////////////////////////////////////////////////

  @override
  void initState() {
    super.initState();
    _attach(controller);
  }

  @override
  void didUpdateWidget(covariant QuillToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach(controller);
    super.dispose();
  }

  void _attach(QuillController c) {
    _lastToggledStyle = c.toggledStyle;
    _lastSelection = c.selection;
    _previousOnSelectionChanged = c.onSelectionChanged;
    c.onSelectionChanged = _onSelectionChanged;
    c.addListener(_rememberState);
  }

  void _detach(QuillController c) {
    c.removeListener(_rememberState);
    if (c.onSelectionChanged == _onSelectionChanged) {
      c.onSelectionChanged = _previousOnSelectionChanged;
    }
  }

  /// Mémorise le style en attente et la sélection après chaque changement.
  void _rememberState() {
    _lastToggledStyle = controller.toggledStyle;
    _lastSelection = controller.selection;
  }

  /// Quill remet le style en attente à zéro à chaque mise à jour de la
  /// sélection, y compris quand l'éditeur reprend le focus avec le curseur
  /// au même endroit (après un menu déroulant, un sélecteur de couleur...).
  /// Dans ce cas précis — curseur inchangé — on restaure le style choisi.
  void _onSelectionChanged(TextSelection selection) {
    if (selection.isCollapsed &&
        selection == _lastSelection &&
        _lastToggledStyle.isNotEmpty &&
        controller.toggledStyle.isEmpty) {
      controller.toggledStyle = _lastToggledStyle;
    }
    _previousOnSelectionChanged?.call(selection);
  }

  //////////////////////////////////////////////////////
  //                     BUILD                        //
  //////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    // TextFieldTapRegion : un clic sur la barre d'outils est considéré
    // comme "dans" l'éditeur, qui garde donc le focus et le curseur.
    return TextFieldTapRegion(child: _buildToolbar(context));
  }

  Widget _buildToolbar(BuildContext context) {
    return widget.formatOnly
        ? _buildFormatOnlyToolbar()
        : _buildFullToolbar(context);
  }

  /// Polices proposées dans les deux versions de la barre.
  static const Map<String, String> _fontFamilies = {
    'Cardo': 'Cardo',
    'EB Garamond': 'EBGaramond',
    'Cinzel': 'Cinzel',
    'MedievalSharp': 'MedievalSharp',
    'UnifrakturMaguntia': 'UnifrakturMaguntia',
    'Pirata One': 'PirataOne',
    'Orbitron': 'Orbitron',
    'Audiowide': 'Audiowide',
    'Lexend': 'Lexend',
  };

  /// Barre complète : notes et fiches (liens, images, listes…).
  Widget _buildFullToolbar(BuildContext context) {
    return QuillSimpleToolbar(
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
        buttonOptions: const QuillSimpleToolbarButtonOptions(
          fontFamily: QuillToolbarFontFamilyButtonOptions(items: _fontFamilies),
        ),
      ),
    );
  }

  /// Barre "format seul" : zones de texte des templates.
  Widget _buildFormatOnlyToolbar() {
    return QuillSimpleToolbar(
      controller: controller,
      config: const QuillSimpleToolbarConfig(
        // ── Ce qu'on garde : le style du texte ──
        showFontFamily: true,
        showFontSize: true,
        showBoldButton: true,
        showItalicButton: true,
        showUnderLineButton: true,
        showStrikeThrough: true,
        showColorButton: true,
        showBackgroundColorButton: true,
        showClearFormat: true,
        showAlignmentButtons: true,
        showJustifyAlignment: false,

        // ── Ce qu'on retire : contenu, structure, liens ──
        showLink: false,
        showInlineCode: false,
        showCodeBlock: false,
        showQuote: false,
        showHeaderStyle: false,
        showListNumbers: false,
        showListBullets: false,
        showListCheck: false,
        showIndent: false,
        showSubscript: false,
        showSuperscript: false,
        showSearchButton: false,
        showUndo: false,
        showRedo: false,

        buttonOptions: QuillSimpleToolbarButtonOptions(
          fontFamily: QuillToolbarFontFamilyButtonOptions(items: _fontFamilies),
          // Tailles en pixels du canvas (une page A4 fait 1240 px de large) :
          // il faut des valeurs bien plus grandes que dans une note.
          fontSize: QuillToolbarFontSizeButtonOptions(
            items: {
              '16': '16', '20': '20', '24': '24', '32': '32', '40': '40',
              '48': '48', '64': '64', '80': '80', '96': '96', '128': '128',
              'Défaut': '0',
            },
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  //                     LIENS                        //
  //////////////////////////////////////////////////////

  /// Ouvre un dialog pour choisir la cible d'un lien interne
  /// (dossier ou note) et son texte affiché, puis l'insère.
  void _showLinkPicker(BuildContext context) async {
    List<Folder> allFolders = await context
        .read<FolderProvider>()
        .getAllFolders();
    List<Note> allNotes = await context.read<NoteProvider>().getAllNotes();
    List<Map<String, dynamic>> tree = _buildWholeTree(
      allFolders,
      allNotes,
      null,
      0,
    );
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
                            contentPadding: EdgeInsets.only(
                              left: 16.0 + depth * 20,
                            ),
                            leading: const Icon(Icons.folder),
                            title: Text(f.name),
                            selected: selectedId == f.id,
                            onTap: () => setState(() => selectedId = f.id),
                          );
                        } else {
                          Note n = item['item'];
                          return ListTile(
                            contentPadding: EdgeInsets.only(
                              left: 16.0 + depth * 20,
                            ),
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
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
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
    List<Folder> allFolders,
    List<Note> allNotes,
    String? parentId,
    int depth,
  ) {
    List<Map<String, dynamic>> result = [];

    for (Note note in allNotes) {
      if (note.parentFolder == parentId) {
        result.add({'item': note, 'depth': depth, 'type': 'note'});
      }
    }

    for (Folder folder in allFolders) {
      if (folder.parentFolder == parentId) {
        result.add({'item': folder, 'depth': depth, 'type': 'folder'});
        result.addAll(
          _buildWholeTree(allFolders, allNotes, folder.id, depth + 1),
        );
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
      TextSelection.collapsed(
        offset: controller.selection.baseOffset + nom.length,
      ),
    );
    controller.formatText(
      controller.selection.baseOffset - nom.length,
      nom.length,
      LinkAttribute('https://$id'),
    );
  }
}
